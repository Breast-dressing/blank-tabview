import Foundation
import SwiftUI

/// 「我的」页的状态机：选中成员 → 补全成员资料 → 拉指标 → 荣誉分组；不依赖 UI。
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
        var resolved = (raw?.isEmpty == false) ? raw : nil

        // 没手动选过成员时，若仅有一个家族成员就自动选上，避免“我的”页空白
        if resolved == nil {
            let cached = services.families.allMembersCached()
            if cached.count == 1, !cached[0].member.itemId.isEmpty {
                services.store.setSelectedMember(cached[0].member.itemId)
                resolved = cached[0].member.itemId
            }
        }

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
        // 头像 / 名字 / 铭牌先靠家族成员补齐，避免第一屏就是“未知”
        _ = await services.metrics.ensureMember(resolved)

        do {
            let result = try await services.metrics.load(resolved, force: force)
            metrics = result
            honorGroups = services.honors.groupsOf(result.member.title)
            error = nil
        } catch {
            // 接口挂了也要先显示成员资料，四个入口显示 “--”，错误单独提示
            let fallback = services.member(resolved)
            metrics = MemberMetrics(member: fallback, familyName: metrics?.familyName ?? "")
            honorGroups = services.honors.groupsOf(fallback.title)
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
    var dayLabels: [String] { DayLabels.recent7 }
}
