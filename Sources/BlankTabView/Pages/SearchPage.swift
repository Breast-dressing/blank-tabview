import SwiftUI

/// 搜索：标题在导航栏左侧，内容保持空白。
struct SearchPage: View {
    var body: some View {
        NavigationStack {
            PageScaffold(title: AppTab.search.title) { EmptyView() }
        }
    }
}

#Preview {
    SearchPage()
}
