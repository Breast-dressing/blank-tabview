import SwiftUI

/// 统一页面骨架：顶部左侧标题 + 内容。内容多时传 scroll: true。
struct PageScaffold<Content: View>: View {
    let title: String
    let background: Color
    let scroll: Bool
    let content: Content

    init(
        title: String,
        background: Color = Color(uiColor: .systemBackground),
        scroll: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.background = background
        self.scroll = scroll
        self.content = content()
    }

    var body: some View {
        Group {
            if scroll {
                ScrollView {
                    stack
                }
                .scrollIndicators(.hidden)
            } else {
                stack
            }
        }
        .background(background.ignoresSafeArea())
    }

    private var stack: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageTitle(text: title)
            content
            if !scroll {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, scroll ? 24 : 0)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(maxHeight: scroll ? nil : .infinity, alignment: .topLeading)
    }
}

extension PageScaffold where Content == EmptyView {
    init(title: String, background: Color = Color(uiColor: .systemBackground)) {
        self.init(title: title, background: background, scroll: false) { EmptyView() }
    }
}

#Preview {
    PageScaffold(title: "首页")
}
