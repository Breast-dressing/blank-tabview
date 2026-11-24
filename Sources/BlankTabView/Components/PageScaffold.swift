import SwiftUI

/// 统一页面骨架：顶部左侧标题 + 内容，内容默认留空。
struct PageScaffold<Content: View>: View {
    let title: String
    let background: Color
    let content: Content

    init(
        title: String,
        background: Color = Color(uiColor: .systemBackground),
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.background = background
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageTitle(text: title)
            content
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(background.ignoresSafeArea())
    }
}

extension PageScaffold where Content == EmptyView {
    init(title: String, background: Color = Color(uiColor: .systemBackground)) {
        self.init(title: title, background: background) { EmptyView() }
    }
}

#Preview {
    PageScaffold(title: "首页")
}
