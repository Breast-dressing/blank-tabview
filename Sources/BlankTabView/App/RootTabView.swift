import SwiftUI

struct RootTabView: View {
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            Tab(AppTab.home.title, systemImage: AppTab.home.systemImage, value: .home) {
                HomePage()
            }
            Tab(AppTab.profile.title, systemImage: AppTab.profile.systemImage, value: .profile) {
                ProfilePage()
            }
            Tab(AppTab.search.title, systemImage: AppTab.search.systemImage, value: .search) {
                SearchPage()
            }
        }
    }
}

#Preview {
    RootTabView()
}
