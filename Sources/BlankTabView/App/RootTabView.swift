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
            // 分离式搜索 Tab：iOS 27 的 prominent 角色把标签页放到末尾的独立位置
            Tab(value: AppTab.search, role: .prominent) {
                SearchPage()
            } label: {
                Label(AppTab.search.title, systemImage: AppTab.search.systemImage)
            }
        }
    }
}

#Preview {
    RootTabView()
}
