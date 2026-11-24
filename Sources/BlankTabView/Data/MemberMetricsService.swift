import Foundation

struct RankSummary: Sendable {
    var week: Int?
    var month: Int?
    var weekName: String = "周榜"
    var monthName: String = "月榜"
}

/// 把一个成员的「周榜 / 月榜 / 乐迷皮肤 / 奖章 / 乐迷值 / 近 7 天荣誉」一次算清。
/// 成员 ID 一律先过 `MemberId.canonical`，避免列表里的编码 ID 与主页链接里的解码 ID 对不上。
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
            cache.removeValue(forKey: MemberId.canonical(itemId))
        } else {
            cache.removeAll()
        }
        medals.invalidate()
    }

    /// 已算好的指标快照（详情页里只读，不触发网络）。
    func peek(_ itemId: String) -> MemberMetrics? {
        cache[MemberId.canonical(itemId)]
    }

    /// 本地成员资料（唯一查找入口）：磁盘 key、家族成员列表都按归一化 ID 比较。
    func cachedMember(_ itemId: String) -> Member? {
        let canonical = MemberId.canonical(itemId)
        guard !canonical.isEmpty else { return nil }
        if let hit = store.memberInfo(canonical), !hit.title.isEmpty, hit.title != "未知" {
            return hit
        }
        if let hit = families.allMembersCached().first(where: { MemberId.matches($0.member.itemId, canonical) }) {
            return hit.member
        }
        return nil
    }

    /// 成员资料补全（唯一入口）：磁盘缓存 → 家族成员（带盘缓存）→ 家族成员强制重拉。
    /// 「我的」页、成员详情、成员列表都走这里。
    func ensureMember(_ itemId: String) async -> Member? {
        let canonical = MemberId.canonical(itemId)
        guard !canonical.isEmpty else { return nil }
        if let cached = cachedMember(canonical) {
            return cached
        }

        let repo = families
        for family in repo.families {
            var members = (try? await repo.loadMembers(family)) ?? []
            if !members.contains(where: { MemberId.matches($0.memberId, canonical) }) {
                members = (try? await repo.loadMembers(family, force: true)) ?? members
            }
            if let hit = members.first(where: { MemberId.matches($0.memberId, canonical) }) {
                var member = hit
                member.itemId = canonical
                store.saveMemberInfo(member, familyId: family.id)
                return member
            }
        }
        return nil
    }

    func load(_ itemId: String, force: Bool = false) async throws -> MemberMetrics {
        let canonical = MemberId.canonical(itemId)
        if !force, let cached = cache[canonical] { return cached }
        let metrics = try await AsyncTimeout.run(seconds: 45) { [self] in
            try await build(canonical)
        }
        cache[canonical] = metrics
        return metrics
    }

    private func build(_ itemId: String) async throws -> MemberMetrics {
        let member: Member
        if let cached = cachedMember(itemId) {
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

        guard let tab = page.results.first(where: { result in
            result.tab.name.contains("乐迷") && result.success && !result.modules.isEmpty
        }) else { return metrics }

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
            return MemberId.canonical(raw)
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
        items.first { MemberId.matches($0.itemId, itemId) }
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
