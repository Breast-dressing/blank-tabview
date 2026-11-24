import Foundation

struct RankSummary: Sendable {
    var week: Int?
    var month: Int?
    var weekName: String = "周榜"
    var monthName: String = "月榜"
}

/// 把一个成员的「周榜 / 月榜 / 乐迷皮肤 / 奖章 / 乐迷值 / 近 7 天荣誉」一次算清。
/// 成员资料缺失时先去家族成员里补，不把“未知”展示给用户。
final class MemberMetricsService: @unchecked Sendable {
    private let store: AppStore
    private let families: FamilyRepository
    private let honors: HonorRepository
    private let medals: MedalRepository
    private var cache: [String: MemberMetrics] = [:]

    init(store: AppStore, families: FamilyRepository, honors: HonorRepository, medals: MedalRepository) {
        self.store = store
        self.families = families
        self.honors = honors
        self.medals = medals
    }

    func invalidate(_ itemId: String? = nil) {
        if let itemId {
            cache[itemId] = nil
        } else {
            cache.removeAll()
        }
        medals.invalidate()
    }

    /// 已算好的指标快照（详情页里只读，不触发网络）。
    func peek(_ itemId: String) -> MemberMetrics? {
        cache[itemId]
    }

    /// 本地缓存里的成员资料（勋章接口失败时仍能展示头像与名字）。
    func cachedMember(_ itemId: String) -> Member? {
        store.memberInfo(itemId)
            ?? families.allMembersCached().first(where: { $0.member.itemId == itemId })?.member
    }

    /// 成员资料补全（唯一入口）：缓存 → 内存成员 → 逐个家族拉取。
    /// 「我的」页与成员详情都走这里，不各写一份。
    func ensureMember(_ itemId: String) async -> Member? {
        guard !itemId.isEmpty else { return nil }
        if let cached = cachedMember(itemId), !cached.title.isEmpty {
            return cached
        }

        let repo = families
        for family in repo.families {
            let members = (try? await repo.loadMembers(family)) ?? []
            if let hit = members.first(where: { $0.itemId == itemId }) {
                store.saveMemberInfo(hit, familyId: family.id)
                return hit
            }
        }
        for entry in repo.allMembersCached() where entry.member.itemId == itemId {
            store.saveMemberInfo(entry.member, familyId: entry.family.id)
            return entry.member
        }
        return nil
    }

    func load(_ itemId: String, force: Bool = false) async throws -> MemberMetrics {
        if !force, let cached = cache[itemId] { return cached }
        let metrics = try await AsyncTimeout.run(seconds: 45) { [self] in
            try await build(itemId)
        }
        cache[itemId] = metrics
        return metrics
    }

    private func build(_ itemId: String) async throws -> MemberMetrics {
        let member: Member
        if let cached = store.memberInfo(itemId)
            ?? families.allMembersCached().first(where: { $0.member.itemId == itemId })?.member {
            member = cached
        } else if let ensured = await ensureMember(itemId) {
            member = ensured
        } else {
            member = Member(itemId: itemId, title: "未知")
        }

        let family = families.familyOfMember(itemId, hintFamilyId: member.familyId)
        var metrics = MemberMetrics(member: member, familyName: family?.name ?? "")

        let daily = honors.dailyTotals(member.title)
        metrics.dailyHonor = daily.values
        metrics.hasHonorData = daily.hasData

        guard !itemId.isEmpty else { return metrics }

        let hallURL = AppStore.medalUrlTemplate.replacingOccurrences(of: "{ENC_UIN}", with: itemId)
        guard let page = try? await medals.hallPage(hallURL) else { return metrics }
        metrics.medalDesc = page.desc

        var artist = member.artistName
        if artist.isEmpty, let family {
            artist = store.familyArtist(family.id)
        }
        guard !artist.isEmpty else { return metrics }

        // 找「乐迷」Tab（可能多个，取第一个有数据的）
        guard let tab = page.results.first(where: { result in
            result.tab.name.contains("乐迷") && result.success && !result.modules.isEmpty
        }) else { return metrics }

        // 模块里按艺人名匹配：先精确，再包含
        var matched: MedalItem?
        for module in tab.modules {
            if let item = module.items.first(where: { $0.name == artist }) { matched = item; break }
        }
        if matched == nil {
            for module in tab.modules {
                if let item = module.items.first(where: { $0.name.contains(artist) }) { matched = item; break }
            }
        }
        guard let medal = matched, !medal.scheme.isEmpty else { return metrics }

        let medalId = queryValue(medal.scheme, "medal_id")
        let encUin = queryValue(medal.scheme, "enc_uin")
        guard !medalId.isEmpty else { return metrics }

        metrics.skinMedalId = medalId
        metrics.skinMedalName = medal.name
        metrics.skinMedalScheme = medal.scheme
        metrics.rankScheme = medal.scheme

        async let ranks = loadRanks(scheme: medal.scheme, itemId: itemId)
        async let skinTotal = loadSkin(medalId: medalId, encUin: encUin.isEmpty ? itemId : encUin)
        async let fan = loadFan(hallURL: hallURL, medalId: medalId, encUin: encUin)

        if let summary = try? await ranks {
            metrics.weekRank = summary.week
            metrics.monthRank = summary.month
            metrics.weekTabName = summary.weekName
            metrics.monthTabName = summary.monthName
        }
        if let count = try? await skinTotal {
            metrics.skinCount = count
        }
        if let medalFan = try? await fan {
            metrics.fan = medalFan
        }
        return metrics
    }

    private func queryValue(_ url: String, _ name: String) -> String {
        if let components = URLComponents(string: url),
           let value = components.queryItems?.first(where: { $0.name == name })?.value,
           !value.isEmpty {
            return value
        }
        let pattern = "\(name)=([^&]*)"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
           match.numberOfRanges > 1 {
            let raw = (url as NSString).substring(with: match.range(at: 1))
            return raw.removingPercentEncoding ?? raw
        }
        return ""
    }

    private func loadRanks(scheme: String, itemId: String) async throws -> RankSummary {
        let page = try await medals.rankPage(scheme)
        var summary = RankSummary()

        for result in page.results where result.success {
            guard let member = matchedMember(result.detail.items, itemId: itemId) else { continue }
            if result.tab.isWeek && summary.week == nil {
                summary.week = member.position
                summary.weekName = Fmt.cleanTabName(result.tab.name)
            }
            if result.tab.isMonth && summary.month == nil {
                summary.month = member.position
                summary.monthName = Fmt.cleanTabName(result.tab.name)
            }
        }

        // 首屏没命中的榜，逐个 Tab 懒加载补全
        if summary.week == nil || summary.month == nil {
            for tab in page.tabs {
                let needWeek = summary.week == nil && tab.isWeek
                let needMonth = summary.month == nil && tab.isMonth
                guard needWeek || needMonth else { continue }
                guard let detail = try? await medals.rankTab(scheme, tab: tab),
                      let member = matchedMember(detail.items, itemId: itemId) else { continue }
                if needWeek {
                    summary.week = member.position
                    summary.weekName = Fmt.cleanTabName(tab.name)
                }
                if needMonth {
                    summary.month = member.position
                    summary.monthName = Fmt.cleanTabName(tab.name)
                }
            }
        }

        if summary.weekName.isEmpty { summary.weekName = "周榜" }
        if summary.monthName.isEmpty { summary.monthName = "月榜" }
        return summary
    }

    private func matchedMember(_ items: [RankMember], itemId: String) -> RankMember? {
        items.first { member in
            let decoded = Fmt.decodeId(member.itemId)
            return decoded == itemId || member.itemId == itemId
        }
    }

    private func loadSkin(medalId: String, encUin: String) async throws -> Int? {
        let list = try await medals.skinTotal(medalId: medalId, encUin: encUin)
        if list.total > 0 { return list.total }
        if !list.skins.isEmpty { return list.skins.count }
        return nil
    }

    private func loadFan(hallURL: String, medalId: String, encUin: String) async throws -> FanMedal? {
        try await medals.fan(url: hallURL, medalId: medalId, encUin: encUin)
    }
}
