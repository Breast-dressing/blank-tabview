import SwiftUI

// MARK: - Model

@MainActor
final class MemberDetailModel: ObservableObject {
    private let services = AppServices.shared
    let memberId: String

    @Published private(set) var metrics: MemberMetrics?
    @Published private(set) var groups: [HonorDayGroup] = []
    @Published private(set) var loading = true
    @Published private(set) var error: String?
    @Published private(set) var member: Member

    init(memberId: String) {
        self.memberId = memberId
        self.member = AppServices.shared.member(memberId)
    }

    func load() async {
        loading = true
        error = nil
        _ = await services.metrics.ensureMember(memberId)
        member = services.member(memberId)
        do {
            let result = try await services.metrics.load(memberId, force: true)
            metrics = result
            member = result.member
            groups = services.honors.groupsOf(result.member.title)
        } catch {
            metrics = nil
            groups = []
            self.error = error.localizedDescription
        }
        loading = false
    }
}

// MARK: - View

struct MemberDetailView: View {
    @StateObject private var model: MemberDetailModel

    init(memberId: String) {
        _model = StateObject(wrappedValue: MemberDetailModel(memberId: memberId))
    }

    var body: some View {
        DetailScroll {
            MemberHeaderBar(
                name: model.member.title,
                pic: model.member.pic,
                subtitle: model.member.medalText
            )

            if model.loading {
                StateNotice(title: "正在读取成员数据…", progress: true)
            }

            if let metrics = model.metrics {
                entryCard(metrics)
                ProfileDetailSection(
                    metrics: metrics,
                    honorGroups: model.groups,
                    dayLabels: DayLabels.recent7
                )
                Text("数据来源：QQ 音乐勋章馆")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if !model.loading {
                if let error = model.error {
                    StateNotice(title: "成员数据加载失败", message: error, actionTitle: "重试") {
                        Task { await model.load() }
                    }
                }
                if !model.member.artistName.isEmpty || !model.member.honor.isEmpty {
                    summaryBase
                }
            }
        }
        .navigationTitle(model.member.title.isEmpty ? "成员详情" : model.member.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }

    /// 与「我的」票据卡同一套入口规则，四个数据都可点进详情。
    private func entryCard(_ metrics: MemberMetrics) -> some View {
        InfoCard {
            HStack(alignment: .top, spacing: 0) {
                entry("周榜", metrics.displayWeekRank, MemberEntries.rank(metrics, monthly: false))
                entry("月榜", metrics.displayMonthRank, MemberEntries.rank(metrics, monthly: true))
                entry("乐迷皮肤", metrics.displaySkinCount, MemberEntries.skins(metrics))
                entry("已获得奖章", metrics.medalDesc, MemberEntries.medals(metrics))
            }
        }
    }

    @ViewBuilder
    private func entry(_ label: String, _ value: String, _ destination: ProfileDestination?) -> some View {
        if let destination {
            NavigationLink(value: destination) {
                entryCell(label, value, enabled: true)
            }
            .buttonStyle(.plain)
        } else {
            entryCell(label, value, enabled: false)
        }
    }

    private func entryCell(_ label: String, _ value: String, enabled: Bool) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if enabled {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                }
            }
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private var summaryBase: some View {
        InfoCard {
            HStack(spacing: 0) {
                cell("荣誉值", Fmt.thousands(model.member.honor))
                cell("艺人", model.member.artistName.isEmpty ? "-" : model.member.artistName)
                cell("家族", "-")
                cell("乐迷值", model.member.fanBadge.isEmpty ? "-" : model.member.fanBadge)
            }
        }
    }

    private func cell(_ label: String, _ value: String) -> some View {
        VStack(spacing: 5) {
            Text(value.isEmpty ? "--" : value)
                .font(.system(size: 17, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        MemberDetailView(memberId: "12345")
    }
}
