import Foundation
import SwiftUI

/// 「我的」页的状态机：选中成员 → 拉指标 → 荣誉分组；不依赖 UI。
@MainActor
final class ProfileViewModel: ObservableObject {
    private let services = AppServices.shared

    @Published private(set) var families: [Family] = []
    @Published private(set) var metrics: MemberMetrics?
    @Published private(set) var honorGroups: [HonorDayGroup] = []
    @Published private(set) var loading = true
    @Published private(set) var error: String?
    @Published private(set) var memberId: String?

    private var lastMemberId: String?

    func load(force: Bool = false) async {
        families = services.families.families
        let raw = services.store.selectedMemberId
        let resolved = (raw?.isEmpty == false) ? raw : nil

        let changed = resolved != lastMemberId
        lastMemberId = resolved
        memberId = resolved
        if changed {
            metrics = nil
            honorGroups = []
            error = nil
        }

        guard let resolved else {
            metrics = nil
            honorGroups = []
            loading = false
            return
        }

        loading = true
        do {
            let result = try await services.metrics.load(resolved, force: force)
            metrics = result
            honorGroups = services.honors.groupsOf(result.member.title)
            error = nil
        } catch {
            metrics = nil
            honorGroups = []
            self.error = error.localizedDescription
        }
        loading = false
    }

    /// 家族本周荣誉值：优先用成员荣誉汇总，否则回退家族页上的 weekHonor。
    func weekHonor(of family: Family) -> Double {
        let names = services.store.familyMembers(family.id)
            .map(\.title)
            .filter { !$0.isEmpty }
        if names.isEmpty { return Fmt.parseNumber(family.weekHonor) }
        return services.honors.familyDailyTotals(names).values.reduce(0, +)
    }

    /// 近 7 天横坐标：11/18 … 11/24
    var dayLabels: [String] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var labels: [String] = []
        for offset in stride(from: 6, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let parts = calendar.dateComponents([.month, .day], from: day)
            labels.append("\(parts.month ?? 0)/\(parts.day ?? 0)")
        }
        return labels
    }
}
