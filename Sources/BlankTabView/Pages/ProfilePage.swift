import SwiftUI

/// 我的：标题在导航栏左侧；成员票据卡直接贴导航栏下方，不再自加间距。
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
                scroll: true
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
        case let .skinSeries(seriesName, skins):
            SkinSeriesView(seriesName: seriesName, skins: skins)
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
                onManage: { showSettings = true },
                onTapWeek: tap(MemberEntries.rank(metrics, monthly: false)),
                onTapMonth: tap(MemberEntries.rank(metrics, monthly: true)),
                onTapSkins: tap(MemberEntries.skins(metrics)),
                onTapMedals: tap(MemberEntries.medals(metrics)),
                onTapFamily: { path.append(MemberEntries.family($0)) }
            )
        } else if model.loading {
            ProfileStateCard(title: "正在读取成员数据…", showsProgress: true)
        } else {
            ProfileStateCard(
                title: "还没有当前成员",
                message: "添加家族并选择自己的成员身份后，这里会显示周榜、月榜、乐迷皮肤与奖章。",
                actionTitle: "添加家族",
                action: { showSettings = true }
            )
        }
    }

    private func tap(_ destination: ProfileDestination?) -> (() -> Void)? {
        guard let destination else { return nil }
        return { path.append(destination) }
    }
}

#Preview {
    ProfilePage()
}
