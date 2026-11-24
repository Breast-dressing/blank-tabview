import SwiftUI

/// 三个页面 + 自绘底部悬浮 Tab 栏：首页 / 我的 在胶囊内，搜索单独一个圆按钮（分离式）。
struct RootTabView: View {
    @State private var selection: AppTab = AppTab.launchTab

    var body: some View {
        TabView(selection: $selection) {
            Tab(value: AppTab.home) {
                HomePage()
            }
            Tab(value: AppTab.profile) {
                ProfilePage()
            }
            Tab(value: AppTab.search) {
                SearchPage()
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            tabBar
                .padding(.horizontal, 24)
                .padding(.bottom, 6)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 2) {
                item(.home)
                item(.profile)
            }
            .padding(5)
            .background(.ultraThinMaterial, in: Capsule())

            Button {
                selection = .search
            } label: {
                Image(systemName: AppTab.search.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(selection == .search ? Color.accentColor : Color.primary)
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(.plain)
            .background(.ultraThinMaterial, in: Circle())
            .overlay {
                Circle().stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            }
            .accessibilityLabel(AppTab.search.title)
        }
    }

    private func item(_ tab: AppTab) -> some View {
        Button {
            selection = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 20, weight: .medium))
                Text(tab.title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(selection == tab ? Color.accentColor : Color.primary)
            .frame(width: 92, height: 50)
            .background {
                Capsule().fill(selection == tab ? Color(uiColor: .tertiarySystemFill) : Color.clear)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
    }
}

#Preview {
    RootTabView()
}
