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
            // 分离式搜索 Tab：由系统放在尾部、选中后变形为搜索态
            Tab(value: AppTab.search, role: .search) {
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
