import SwiftUI

/// 我的：标题在左上角；下方是带圆形凸起的票据卡，数据来自 QQ 音乐家族 / 勋章接口。
struct ProfilePage: View {
    @StateObject private var model = ProfileViewModel()
    @State private var showSettings = false

    var body: some View {
        PageScaffold(
            title: AppTab.profile.title,
            background: Color(uiColor: .systemGroupedBackground),
            scroll: true
        ) {
            VStack(alignment: .leading, spacing: 16) {
                cardSlot
                    // 给头像凸起预留上方空间，避免和标题挤在一起
                    .padding(.top, 10)

                if let metrics = model.metrics {
                    ProfileDetailSection(
                        metrics: metrics,
                        honorGroups: model.honorGroups,
                        dayLabels: model.dayLabels
                    )
                }
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
    private var cardSlot: some View {
        if let metrics = model.metrics {
            ProfileTicketCard(
                metrics: metrics,
                families: model.families,
                weekHonor: { model.weekHonor(of: $0) },
                onManage: { showSettings = true }
            )
        } else if model.loading {
            ProfileStateCard(title: "正在读取成员数据…", showsProgress: true)
                .padding(.top, 8)
        } else if let error = model.error {
            ProfileStateCard(
                title: "数据加载失败",
                message: error,
                actionTitle: "重新加载",
                action: { Task { await model.load(force: true) } }
            )
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
}

#Preview {
    ProfilePage()
}
