import Foundation

/// 家族荣誉的唯一计算入口：「我的」票据卡、家族详情、成员列表都调这里，不各写一份。
final class FamilyStatsService: @unchecked Sendable {
    private let store: AppStore
    private let honors: HonorRepository

    init(store: AppStore, honors: HonorRepository) {
        self.store = store
        self.honors = honors
    }

    /// 总荣誉值（数值）：优先家族页原值；为 0 时回退到成员荣誉之和。
    func honorValue(_ family: Family) -> Double {
        let parsed = Fmt.parseNumber(family.honor)
        if parsed > 0 { return parsed }
        return store.familyMembers(family.id).reduce(0) { $0 + Fmt.parseNumber($1.honor) }
    }

    /// 总荣誉展示文案：带「万 / 亿」的接口原文直接展示，普通数字做千分位。
    func honorText(_ family: Family) -> String {
        let raw = family.honor.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty || raw == "0" {
            let sum = honorValue(family)
            return sum > 0 ? Fmt.thousands(sum) : (raw.isEmpty ? "--" : "0")
        }
        if raw.contains("万") || raw.contains("亿") { return raw }
        return Fmt.thousands(raw)
    }

    /// 本周荣誉值：成员荣誉记录按日汇总；没有成员缓存时回退家族页字段。
    func weekHonor(_ family: Family, members: [Member]? = nil) -> Double {
        let list = members ?? store.familyMembers(family.id)
        let names = list.map(\.title).filter { !$0.isEmpty }
        guard !names.isEmpty else { return Fmt.parseNumber(family.weekHonor) }
        return honors.familyDailyTotals(names).values.reduce(0, +)
    }

    /// 近 `days` 天每日荣誉（从旧到新，最后一段是本周）。
    func weekTotals(_ family: Family, members: [Member], days: Int = 14) -> DailyTotals {
        let names = members.map(\.title).filter { !$0.isEmpty }
        guard !names.isEmpty else {
            return DailyTotals(values: Array(repeating: 0, count: days), hasData: false)
        }
        return honors.familyDailyTotals(names, days: days)
    }
}
