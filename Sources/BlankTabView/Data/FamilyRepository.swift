import Foundation

/// 家族：链接归一化、页面解析、成员拉取、成员⇄家族归属。
final class FamilyRepository: @unchecked Sendable {
    private let store: AppStore
    private let api: QqApi
    private var cache: [Family]
    private var memberCache: [String: [Member]] = [:]
    private var inflight: [String: Task<[Member], Error>] = [:]

    init(store: AppStore, api: QqApi) {
        self.store = store
        self.api = api
        self.cache = store.loadFamilies()
    }

    var families: [Family] { cache }

    // MARK: - 链接归一化

    /// 兼容用户直接拷贝的各类家族链接：带零宽字符、换行、无 scheme、短链、family_id。
    static func normalizeFamilyUrl(_ raw: String) throws -> String {
        var text = raw
        for scalar in ["\u{200B}", "\u{200C}", "\u{200D}", "\u{FEFF}"] {
            text = text.replacingOccurrences(of: scalar, with: "")
        }
        text = text
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\t", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else { throw ApiError("请先粘贴家族页链接") }

        if let range = text.range(of: "https?://", options: .regularExpression) {
            text = String(text[range.lowerBound...])
        }
        if text.hasPrefix("//") { text = "https:" + text }

        if text.contains("family_id=") {
            if !text.hasPrefix("http") { text = "https://" + text }
        } else if text.range(of: "^[A-Za-z0-9]{6,}$", options: .regularExpression) != nil {
            text = "https://c6.y.qq.com/base/fcgi-bin/u?__=" + text
        } else if !text.hasPrefix("http") {
            text = "https://" + text
        }

        guard URL(string: text) != nil, text.contains(".") else {
            throw ApiError("链接格式不正确，请粘贴完整的家族页链接")
        }
        return text
    }

    // MARK: - 家族列表

    @discardableResult
    func add(_ raw: String) async throws -> [Family] {
        let url = try Self.normalizeFamilyUrl(raw)
        if cache.contains(where: { $0.rawUrl == url }) { throw ApiError("这个家族已经添加过了") }
        let family = try await parse(from: url)
        if cache.contains(where: { $0.id == family.id }) { throw ApiError("这个家族已经添加过了") }
        cache.append(family)
        store.saveFamilies(cache)
        return cache
    }

    func removeAt(_ index: Int) -> [Family] {
        guard cache.indices.contains(index) else { return cache }
        let removed = cache.remove(at: index)
        let previousMembers = memberCache[removed.id] ?? store.familyMembers(removed.id)

        memberCache[removed.id] = nil
        inflight[removed.id] = nil
        store.clearFamilyMembers(removed.id)
        store.saveFamilies(cache)

        // 被删家族里正好是当前选中的成员：清空选中，让「我的」页回到空状态
        if let selected = store.selectedMemberId,
           selected.isEmpty == false,
           previousMembers.contains(where: { $0.itemId == selected }) {
            store.setSelectedMember("")
        }
        return cache
    }

    func update(_ family: Family, at index: Int) -> [Family] {
        guard cache.indices.contains(index) else { return cache }
        cache[index] = family
        store.saveFamilies(cache)
        return cache
    }

    func reorder(from source: Int, to destination: Int) -> [Family] {
        guard cache.indices.contains(source) else { return cache }
        let family = cache.remove(at: source)
        let target = Swift.min(Swift.max(destination, 0), cache.count)
        cache.insert(family, at: target)
        store.saveFamilies(cache)
        return cache
    }

    // MARK: - 解析家族页

    func parse(from url: String) async throws -> Family {
        let html = try await api.fetchHtml(url)
        guard let ssr = QqApi.extractSsr(html) else {
            throw ApiError("解析失败：无法从链接读取家族信息，请确认这是家族主页链接")
        }

        let ssrData = QqApi.map(ssr["data"])
        let data = ssrData.isEmpty ? QqApi.map(QqApi.map(ssr["req_0"])["data"]) : ssrData
        let query = QqApi.map(ssr["query"])

        var familyId = QqApi.str(query["family_id"])
        if familyId.isEmpty, let range = html.range(of: "family_id=([0-9]+)", options: .regularExpression) {
            familyId = String(html[range]).replacingOccurrences(of: "family_id=", with: "")
        }
        if familyId.isEmpty { familyId = QqApi.str(data["MedalID"]) }
        guard !familyId.isEmpty else {
            throw ApiError("解析失败：未找到家族 ID")
        }

        var name = QqApi.str(data["Name"])
        var avatar = QqApi.str(data["Avatar"])
        if avatar.isEmpty { avatar = QqApi.str(data["Pic"]) }

        if name.isEmpty {
            // 部分分享链接只带了 family_id，补一次 i2 家族页拿名称 / 头像
            let detailURL = "https://i2.y.qq.com/?family_id=\(familyId)"
            if let detailHtml = try? await api.fetchHtml(detailURL),
               let detailSsr = QqApi.extractSsr(detailHtml) {
                let detail = QqApi.map(QqApi.map(detailSsr["data"])["data"])
                if name.isEmpty { name = QqApi.str(detail["Name"]) }
                if avatar.isEmpty { avatar = QqApi.str(detail["Avatar"]) }
            }
        }

        var honor = "0"
        var rank = "--"
        var pkWin = "--"
        var memberCount = "0"
        for item in QqApi.list(data["DetailItemList"]) {
            let desc = QqApi.str(item["Desc"])
            let title = QqApi.str(item["Title"])
            if desc.contains("总荣誉") {
                honor = digits(title, fallback: "0")
            } else if desc.contains("周排名") {
                rank = title.isEmpty ? "--" : title
            } else if desc.contains("PK") || desc.contains("胜场") {
                pkWin = title.isEmpty ? "--" : title
            } else if desc.contains("成员") {
                memberCount = digits(title, fallback: "0")
            }
        }

        if name.isEmpty { name = "家族 \(familyId)" }
        return Family(
            id: familyId,
            name: name,
            avatar: avatar.replacingOccurrences(of: "http://", with: "https://"),
            honor: honor,
            rank: rank,
            pkWin: pkWin,
            members: memberCount,
            weekHonor: nil,
            rawUrl: url
        )
    }

    private func digits(_ text: String, fallback: String) -> String {
        let numbers = text.filter { $0.isNumber }
        return numbers.isEmpty ? fallback : numbers
    }

    // MARK: - 成员

    func loadMembers(_ family: Family, force: Bool = false) async throws -> [Member] {
        if !force, let cached = memberCache[family.id], !cached.isEmpty { return cached }
        let disk = store.familyMembers(family.id)
        if !force, !disk.isEmpty {
            memberCache[family.id] = disk
            return disk
        }
        if let task = inflight[family.id] { return try await task.value }

        let task = Task { [api] in
            try await api.fetchFamilyMembers(family.id)
        }
        inflight[family.id] = task
        do {
            let members = try await task.value
            inflight[family.id] = nil
            memberCache[family.id] = members
            store.saveFamilyMembers(family.id, members: members)
            if let artist = members.first(where: { !$0.artistName.isEmpty })?.artistName {
                store.saveFamilyArtist(artist, familyId: family.id)
            }
            for member in members {
                store.saveMemberInfo(member, familyId: family.id)
            }
            return members
        } catch {
            inflight[family.id] = nil
            throw error
        }
    }

    func allMembersCached() -> [FamilyMemberEntry] {
        var seen: Set<String> = []
        var entries: [FamilyMemberEntry] = []
        for family in cache {
            let members = memberCache[family.id] ?? store.familyMembers(family.id)
            for member in members where !member.itemId.isEmpty && !seen.contains(member.itemId) {
                seen.insert(member.itemId)
                entries.append(FamilyMemberEntry(member: member, family: family))
            }
        }
        return entries
    }

    /// 跨家族汇总全部成员（去重），失败不阻塞其他家族。
    func allMembers(force: Bool = false) async -> [FamilyMemberEntry] {
        for family in cache {
            _ = try? await loadMembers(family, force: force)
        }
        return allMembersCached()
    }

    func familyOfMember(_ itemId: String, hintFamilyId: String? = nil) -> Family? {
        if let hintFamilyId, let family = cache.first(where: { $0.id == hintFamilyId }) {
            return family
        }
        for family in cache {
            let members = memberCache[family.id] ?? store.familyMembers(family.id)
            if members.contains(where: { $0.itemId == itemId }) { return family }
        }
        if let info = store.memberInfo(itemId), !info.familyId.isEmpty,
           let family = cache.first(where: { $0.id == info.familyId }) {
            return family
        }
        return nil
    }
}
