import Foundation

/// 家族荣誉的唯一计算入口（只负责“本周荣誉”汇总；总荣誉值一律原样展示接口文本，不做任何换算）。
final class FamilyStatsService: @unchecked Sendable {
    private let store: AppStore
    private let honors: HonorRepository

    init(store: AppStore, honors: HonorRepository) {
        self.store = store
        self.honors = honors
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
