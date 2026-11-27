import Foundation

// MARK: - Family

struct Family: Codable, Identifiable, Hashable, Sendable {
    var id: String = ""
    var name: String = ""
    var avatar: String = ""
    var sign: String = ""
    var honor: String = "0"
    var rank: String = "--"
    var pkWin: String = "--"
    var members: String = "0"
    var weekHonor: String?
    var rawUrl: String = ""

    var memberCount: Int { Int(members.filter(\.isNumber)) ?? 0 }

    enum CodingKeys: String, CodingKey {
        case id, name, avatar, sign, honor, rank, pkWin, members, weekHonor, rawUrl
    }

    init() {}

    init(
        id: String,
        name: String,
        avatar: String = "",
        sign: String = "",
        honor: String = "0",
        rank: String = "--",
        pkWin: String = "--",
        members: String = "0",
        weekHonor: String? = nil,
        rawUrl: String = ""
    ) {
        self.id = id
        self.name = name
        self.avatar = avatar
        self.sign = sign
        self.honor = honor
        self.rank = rank
        self.pkWin = pkWin
        self.members = members
        self.weekHonor = weekHonor
        self.rawUrl = rawUrl
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        avatar = try c.decodeIfPresent(String.self, forKey: .avatar) ?? ""
        sign = try c.decodeIfPresent(String.self, forKey: .sign) ?? ""
        honor = Self.nonEmpty(try c.decodeIfPresent(String.self, forKey: .honor), "0")
        rank = Self.nonEmpty(try c.decodeIfPresent(String.self, forKey: .rank), "--")
        pkWin = Self.nonEmpty(try c.decodeIfPresent(String.self, forKey: .pkWin), "--")
        members = Self.nonEmpty(try c.decodeIfPresent(String.self, forKey: .members), "0")
        weekHonor = try c.decodeIfPresent(String.self, forKey: .weekHonor)
        rawUrl = try c.decodeIfPresent(String.self, forKey: .rawUrl) ?? ""
    }

    private static func nonEmpty(_ value: String?, _ fallback: String) -> String {
        guard let value, !value.isEmpty else { return fallback }
        return value
    }
}

// MARK: - Member

struct Member: Codable, Identifiable, Hashable, Sendable {
    var itemId: String = ""
    var title: String = ""
    var pic: String = ""
    var medal: String = ""
    var fanBadge: String = ""
    var honor: String = ""
    var artistName: String = ""
    var familyId: String = ""

    var id: String { itemId }

    /// 勋章铭牌：艺人名 + V 等级
    var medalText: String {
        let badge = medal.trimmingCharacters(in: .whitespacesAndNewlines)
        if badge.isEmpty { return "" }
        let artist = artistName.trimmingCharacters(in: .whitespacesAndNewlines)
        if artist.isEmpty { return badge }
        return badge.contains(artist) ? badge : artist + badge
    }

    enum CodingKeys: String, CodingKey {
        case itemId, title, pic, medal, fanBadge, honor, artistName, familyId
        case ItemID, Title, Pic
    }

    init() {}

    init(
        itemId: String,
        title: String,
        pic: String = "",
        medal: String = "",
        fanBadge: String = "",
        honor: String = "",
        artistName: String = "",
        familyId: String = ""
    ) {
        self.itemId = itemId
        self.title = title
        self.pic = pic
        self.medal = medal
        self.fanBadge = fanBadge
        self.honor = honor
        self.artistName = artistName
        self.familyId = familyId
    }

    func with(familyId: String? = nil, pic: String? = nil) -> Member {
        Member(
            itemId: itemId,
            title: title,
            pic: pic ?? self.pic,
            medal: medal,
            fanBadge: fanBadge,
            honor: honor,
            artistName: artistName,
            familyId: familyId ?? self.familyId
        )
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        itemId = try c.decodeIfPresent(String.self, forKey: .itemId)
            ?? (try c.decodeIfPresent(String.self, forKey: .ItemID) ?? "")
        title = try c.decodeIfPresent(String.self, forKey: .title)
            ?? (try c.decodeIfPresent(String.self, forKey: .Title) ?? "")
        pic = try c.decodeIfPresent(String.self, forKey: .pic)
            ?? (try c.decodeIfPresent(String.self, forKey: .Pic) ?? "")
        medal = try c.decodeIfPresent(String.self, forKey: .medal) ?? ""
        fanBadge = try c.decodeIfPresent(String.self, forKey: .fanBadge) ?? ""
        honor = try c.decodeIfPresent(String.self, forKey: .honor) ?? ""
        artistName = try c.decodeIfPresent(String.self, forKey: .artistName) ?? ""
        familyId = try c.decodeIfPresent(String.self, forKey: .familyId) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(itemId, forKey: .itemId)
        try c.encode(title, forKey: .title)
        try c.encode(pic, forKey: .pic)
        try c.encode(medal, forKey: .medal)
        try c.encode(fanBadge, forKey: .fanBadge)
        try c.encode(honor, forKey: .honor)
        try c.encode(artistName, forKey: .artistName)
        try c.encode(familyId, forKey: .familyId)
    }
}

// MARK: - Medal hall

struct MedalTab: Hashable, Sendable {
    var name: String
    var type: Int
    var id: Int
    var firstShow: Bool = false
    var groupName: String = ""

    var isWeek: Bool { name.contains("周") }
    var isMonth: Bool { name.contains("月") }
}

struct MedalItem: Hashable, Sendable {
    var medalId: String = ""
    var name: String = ""
    var picUrl: String = ""
    var scheme: String = ""
    var level: Int = 0
    var state: Int = 0
    var numberText: String = ""
    var createTime: String = ""
    var cornerTitle: String = ""

    var unlocked: Bool { level >= 3 || state == 2 }

    /// 副标题：限定编号 > 获得日期
    var subtitle: String {
        let number = numberText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !number.isEmpty && number != "NO.----" { return number }
        for raw in [createTime, cornerTitle] {
            let text = Fmt.shortDate(raw)
            if !text.isEmpty { return text }
        }
        return ""
    }
}

struct MedalModule: Hashable, Sendable {
    var moduleId: String = ""
    var moduleName: String = ""
    var items: [MedalItem] = []
}

/// 勋章馆首页解析结果：Tab + 每个 Tab 的模块。
struct ModuleTabResult: Sendable, Identifiable {
    var tab: MedalTab
    var success: Bool = false
    var loading: Bool = false
    var error: String = ""
    var modules: [MedalModule] = []
    var fromSsr: Bool = false

    var id: Int { tab.id }
}

final class MedalHallPage {
    let encUin: String
    let desc: String
    let tabs: [MedalTab]
    var results: [ModuleTabResult]
    let currentTabId: Int

    init(encUin: String, desc: String, tabs: [MedalTab], results: [ModuleTabResult], currentTabId: Int) {
        self.encUin = encUin
        self.desc = desc
        self.tabs = tabs
        self.results = results
        self.currentTabId = currentTabId
    }

    var initialTabIndex: Int {
        let index = results.firstIndex { $0.tab.id == currentTabId }
        return index ?? 0
    }
}

struct MedalLevel: Hashable, Sendable {
    var level: Int = 0
    var state: Int = 0
    var name: String = ""
    var picUrl: String = ""
    var medalId: String = ""
    var createTime: String = ""
    var sectionText: String = ""
    var isCenter: Bool = false

    var owned: Bool { state == 2 }
    var badgeText: String {
        if isCenter { return sectionText.isEmpty ? "Lv.\(level)" : sectionText }
        return "Lv.\(level)"
    }
}

struct SkinItem: Hashable, Sendable {
    var id: String = ""
    var seq: Int = 0
    var name: String = ""
    var pic: String = ""
    var categId: String = ""
    var seqNo: String = ""
    var unlockedDate: String = ""
    var userCount: Int = 0
    var isUnlocked: Bool = false
    var stateText: String = "未解锁"
    var unlockTask: String = ""
    var bgColor: String = "#FAFAFA"

    var subtitle: String { seqNo.isEmpty ? unlockedDate : seqNo }
}

struct SkinShowList: Sendable {
    var total: Int = 0
    var skins: [SkinItem] = []
    var medalName: String = ""
    var hasMore: Bool = false
    var nextCursor: String = ""
}

struct RankMember: Hashable, Sendable {
    var position: Int = 0
    var title: String = ""
    var pic: String = ""
    var itemId: String = ""
    /// 勋章铭牌文案（WearList.Segment.Contents）。
    var wearTexts: [String] = []
    /// 成员称号（WearList.Title 去掉等级后缀）。
    var honorTexts: [String] = []
    var descTexts: [String] = []
    var praiseNum: Int = 0
    var isPraised: Bool = false
}

struct RankDetail: Sendable {
    var fixedTitle: String = ""
    var emptyText: String = ""
    var bannerUrl: String = ""
    var bannerTitle: String = ""
    var bannerBtnText: String = ""
    var items: [RankMember] = []

    var hasBanner: Bool { !bannerUrl.isEmpty }
}

/// 一个排行榜 Tab 的加载状态与结果。
struct RankTabResult: Sendable {
    var tab: MedalTab
    var success: Bool = false
    var loading: Bool = false
    var error: String = ""
    var detail: RankDetail = RankDetail()
}

/// 排行榜页首屏：Tab 列表 + 第一个 Tab 的结果（其余 Tab 点开时懒加载）。
struct RankPageData: Sendable {
    var tabs: [MedalTab] = []
    var results: [RankTabResult] = []
    var activeIndex: Int = 0
    var artistName: String = ""
    var medalId: String = ""
    var encUin: String = ""
}

struct FanMedal: Hashable, Sendable {
    var name: String = ""
    var pic: String = ""
    var levelText: String = ""
    var alias: String = ""
    var rankTitle: String = ""
    var rankDesc: String = ""
    var current: Int = 0
    var upper: Int = 0

    var hasProgress: Bool { upper > 0 }
    var percent: Double { upper <= 0 ? 0 : min(max(Double(current) / Double(upper), 0), 1) }
}

struct MedalDetail: Sendable {
    var medalId: String = ""
    var scheme: String = ""
    var levels: [MedalLevel] = []
    var fan: FanMedal?
}

// MARK: - Honor

struct HonorRecord: Codable, Identifiable, Hashable, Sendable {
    var id: String = ""
    var taskName: String = ""
    var date: String = ""
    var value: String = ""

    var valueNumber: Double {
        let cleaned = value.filter { $0.isNumber || $0 == "." || $0 == "-" }
        return Double(cleaned) ?? 0
    }
}

struct HonorMember: Codable, Identifiable, Sendable {
    var name: String = ""
    var records: [HonorRecord] = []

    var id: String { name }
}

struct HonorDayGroup: Identifiable, Sendable {
    var dateKey: String
    var records: [HonorRecord]
    var total: Double
    var timestamp: Date?

    var id: String { dateKey }

    var withinLastWeek: Bool {
        guard let timestamp else { return false }
        let now = Date()
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now)) ?? now
        let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) ?? now
        return timestamp >= start && timestamp < end
    }
}

// MARK: - Member metrics

/// 周榜 / 月榜 / 皮肤 / 乐迷值 / 近 7 天数据：一处算好，多处复用。
struct MemberMetrics: Sendable {
    var member: Member
    var familyName: String = ""
    var weekRank: Int?
    var monthRank: Int?
    var weekTabName: String = "周榜"
    var monthTabName: String = "月榜"
    var rankScheme: String = ""
    var skinMedalId: String = ""
    var skinMedalName: String = ""
    var skinMedalScheme: String = ""
    var skinCount: Int?
    var medalDesc: String = "--"
    var fan: FanMedal?
    var dailyHonor: [Double] = Array(repeating: 0, count: 7)
    var hasHonorData: Bool = false

    var hasSkinMedal: Bool { !skinMedalId.isEmpty }

    var displayWeekRank: String { weekRank.map(String.init) ?? "--" }
    var displayMonthRank: String { monthRank.map(String.init) ?? "--" }
    var displaySkinCount: String { skinCount.map(String.init) ?? "--" }

    var weekTitle: String {
        "\(member.artistName.isEmpty ? member.title : member.artistName)·\(weekTabName)"
    }

    var monthTitle: String {
        "\(member.artistName.isEmpty ? member.title : member.artistName)·\(monthTabName)"
    }
}

// MARK: - Family member entry

struct FamilyMemberEntry: Identifiable, Hashable, Sendable {
    var member: Member
    var family: Family

    var id: String { member.itemId }

    var displayName: String {
        family.name.isEmpty ? member.title : "\(family.name) · \(member.title)"
    }
}
