import SwiftUI

/// 我的：左上角大标题 + 右侧齿轮；成员票据卡直接贴标题下方。
/// 票据卡四项数据与家族格可点进详情页（入口规则集中在 MemberEntries）。
struct ProfilePage: View {
    @StateObject private var model = ProfileViewModel()
    @State private var showSettings = false
    @State private var path: [ProfileDestination] = []

    var body: some View {
        NavigationStack(path: $path) {
            PageScaffold(
                title: AppTab.profile.title,
                background: Color(uiColor: .systemGroupedBackground),
                scroll: true,
                trailing: {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .accessibilityLabel("设置")
                }
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    cardSlot

                    if let metrics = model.metrics, model.error == nil {
                        ProfileDetailSection(
                            metrics: metrics,
                            honorGroups: model.honorGroups,
                            dayLabels: model.dayLabels
                        )
                    } else if let error = model.error {
                        ProfileStateCard(
                            title: "数据加载失败",
                            message: error,
                            actionTitle: "重新加载",
                            action: { Task { await model.load(force: true) } }
                        )
                    }
                }
            }
            .navigationDestination(for: ProfileDestination.self) { route in
                destination(for: route)
            }
        }
        .sheet(isPresented: $showSettings, onDismiss: {
            Task { await model.load(force: true) }
        }) {
            SettingsView()
        }
        .task { await model.load() }
    }

    @ViewBuilder
    private func destination(for route: ProfileDestination) -> some View {
        switch route {
        case let .rank(memberId, scheme, title, tabName):
            RankDetailView(memberId: memberId, scheme: scheme, title: title, tabName: tabName)
        case let .medalHall(memberId):
            MedalsHallView(memberId: memberId)
        case let .medalModule(memberId, moduleId, moduleName, tabName):
            MedalModuleView(memberId: memberId, moduleId: moduleId, moduleName: moduleName, tabName: tabName)
        case let .skins(memberId, medalId, medalName, scheme):
            SkinsView(memberId: memberId, medalId: medalId, medalName: medalName, scheme: scheme)
        case let .skinSeries(member, artistName, seriesName, skins):
            SkinSeriesView(member: member, artistName: artistName, seriesName: seriesName, skins: skins)
        case let .family(family):
            FamilyDetailView(family: family)
        case let .member(memberId):
            MemberDetailView(memberId: memberId)
        case let .memberList(family):
            MemberListView(family: family)
        }
    }

    @ViewBuilder
    private var cardSlot: some View {
        if let metrics = model.metrics {
            ProfileTicketCard(
                metrics: metrics,
                families: model.families,
                weekHonor: { model.weekHonor(of: $0) },
                onTapWeek: tap(MemberEntries.rank(metrics, monthly: false)),
                onTapMonth: tap(MemberEntries.rank(metrics, monthly: true)),
                onTapSkins: tap(MemberEntries.skins(metrics)),
                onTapMedals: tap(MemberEntries.medals(metrics)),
                onTapFamily: { path.append(MemberEntries.family($0)) }
            )
        } else {
            // 加载中 / 没有成员：一律用同一张票据卡的占位样式，不再出现长条 loading。
            ProfileTicketCard(
                metrics: Self.placeholderMetrics,
                families: [],
                weekHonor: { _ in 0 }
            )
        }
    }

    /// 未添加成员时的占位数据。
    static let placeholderMetrics: MemberMetrics = {
        var member = Member()
        member.title = "未添加成员"
        member.fanBadge = "添加家族与成员后可查看数据"
        return MemberMetrics(member: member)
    }()

    private func tap(_ destination: ProfileDestination?) -> (() -> Void)? {
        guard let destination else { return nil }
        return { path.append(destination) }
    }
}

#Preview {
    ProfilePage()
}
