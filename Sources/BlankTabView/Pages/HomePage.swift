import SwiftUI

/// 首页：标题在顶部左侧，内容保持空白。
struct HomePage: View {
    var body: some View {
        PageScaffold(title: AppTab.home.title)
    }
}

#Preview {
    HomePage()
}
