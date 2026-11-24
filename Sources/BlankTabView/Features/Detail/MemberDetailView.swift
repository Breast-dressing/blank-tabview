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
            } else if let metrics = model.metrics {
                summary(metrics)
                ProfileDetailSection(
                    metrics: metrics,
                    honorGroups: model.groups,
                    dayLabels: DayLabels.recent7
                )
                Text("数据来源：QQ 音乐勋章馆")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
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

    private func summary(_ metrics: MemberMetrics) -> some View {
        InfoCard {
            HStack(spacing: 0) {
                cell("周榜", metrics.displayWeekRank)
                cell("月榜", metrics.displayMonthRank)
                cell("皮肤", metrics.displaySkinCount)
                cell("奖章", metrics.medalDesc)
            }
        }
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
