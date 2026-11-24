import Foundation
import SwiftUI

/// 「我的」页的状态机：选中成员 → 补全成员资料 → 拉指标 → 荣誉分组；不依赖 UI。
/// 选中 ID 一律经 `MemberId.canonical` 归一化；家族荣誉统一走 `FamilyStatsService`。
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
    private var refreshedFamilyStats = false

    func load(force: Bool = false) async {
        await refreshFamilyStatsIfNeeded(force: force)
        families = services.families.families

        var resolved = services.store.selectedMemberId.flatMap { raw -> String? in
            let canonical = MemberId.canonical(raw)
            return canonical.isEmpty ? nil : canonical
        }

        // 没手动选过成员时，若仅有一个家族成员就自动选上，避免“我的”页空白
        if resolved == nil {
            let cached = services.families.allMembersCached()
            if cached.count == 1 {
                let canonical = MemberId.canonical(cached[0].member.itemId)
                if !canonical.isEmpty {
                    services.store.setSelectedMember(canonical)
                    resolved = canonical
                }
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

    /// 家族页里总荣誉缺失（旧数据 / 分享链接）时补拉一次详情，避免卡片一直是 0。
    private func refreshFamilyStatsIfNeeded(force: Bool = false) async {
        let current = services.families.families
        guard force || !refreshedFamilyStats else { return }
        refreshedFamilyStats = true
        for family in current where Fmt.parseNumber(family.honor) <= 0 {
            _ = await services.families.refreshStats(family)
        }
    }

    /// 家族总荣誉展示（唯一来源）。
    func honorText(of family: Family) -> String {
        services.stats.honorText(family)
    }

    /// 家族本周荣誉值（唯一来源）。
    func weekHonor(of family: Family) -> Double {
        services.stats.weekHonor(family)
    }

    /// 近 7 天横坐标：11/18 … 11/24
    var dayLabels: [String] { DayLabels.recent7 }
}
