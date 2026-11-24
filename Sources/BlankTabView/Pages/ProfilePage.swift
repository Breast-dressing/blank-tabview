import SwiftUI

/// 我的：标题在左上角；下方是带圆形凸起的票据卡，数据来自 QQ 音乐家族 / 勋章接口。
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
                        // 给头像凸起预留上方空间，避免和标题挤在一起
                        .padding(.top, 10)

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
            .toolbar(.hidden, for: .navigationBar)
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
                .padding(.top, 8)
        } else {
            ProfileStateCard(
                title: "还没有当前成员",
                message: "添加家族并选择自己的成员身份后，这里会显示周榜、月榜、乐迷皮肤与奖章。",
                actionTitle: "添加家族",
                action: { showSettings = true }
            )
            .padding(.top, 8)
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
