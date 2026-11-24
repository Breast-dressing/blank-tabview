import SwiftUI

/// 首页：标题在导航栏左侧，内容保持空白。
struct HomePage: View {
    var body: some View {
        NavigationStack {
            PageScaffold(title: AppTab.home.title)
        }
    }
}

#Preview {
    HomePage()
}
