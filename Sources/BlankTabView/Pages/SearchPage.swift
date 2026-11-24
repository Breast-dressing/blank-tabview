import SwiftUI

/// 搜索：标题在顶部左侧，内容保持空白。
struct SearchPage: View {
    var body: some View {
        PageScaffold(title: AppTab.search.title)
    }
}

#Preview {
    SearchPage()
}
