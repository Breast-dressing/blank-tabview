import SwiftUI

/// 我的：标题下方是带圆形凸起的异形圆角卡片，卡片内其余区域留空。
struct ProfilePage: View {
    var body: some View {
        PageScaffold(
            title: AppTab.profile.title,
            background: Color(uiColor: .systemGroupedBackground)
        ) {
            ProfileCard()
        }
    }
}

#Preview {
    ProfilePage()
}
