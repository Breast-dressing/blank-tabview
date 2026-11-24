import SwiftUI

struct RootTabView: View {
    @State private var selection: AppTab = AppTab.launchTab

    var body: some View {
        TabView(selection: $selection) {
            Tab(AppTab.home.title, systemImage: AppTab.home.systemImage, value: .home) {
                HomePage()
            }
            Tab(AppTab.profile.title, systemImage: AppTab.profile.systemImage, value: .profile) {
                ProfilePage()
            }
            // 搜索：系统分离式搜索 Tab（role: .search，由系统提供默认图标与尾部固定位）
            Tab(value: AppTab.search, role: .search) {
                SearchPage()
            }
        }
    }
}

#Preview {
    RootTabView()
}
