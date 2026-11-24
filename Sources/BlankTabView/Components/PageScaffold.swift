import SwiftUI

/// 统一页面骨架：标题用导航栏自己的标题位（大标题），靠 `toolbarTitleAlignment(.leading)` 顶到左侧；
/// 右侧动作走工具栏尾部。
struct PageScaffold<Content: View, Trailing: View>: View {
    let title: String
    let background: Color
    let scroll: Bool
    let trailing: Trailing
    let content: Content

    init(
        title: String,
        background: Color = Color(uiColor: .systemBackground),
        scroll: Bool = false,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.background = background
        self.scroll = scroll
        self.trailing = trailing()
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
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .toolbarTitleAlignment(.leading)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                trailing
            }
        }
    }

    private var stack: some View {
        VStack(alignment: .leading, spacing: 18) {
            content
            if !scroll {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 0)
        .padding(.bottom, scroll ? 24 : 0)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(maxHeight: scroll ? nil : .infinity, alignment: .topLeading)
    }
}

extension PageScaffold where Trailing == EmptyView {
    init(
        title: String,
        background: Color = Color(uiColor: .systemBackground),
        scroll: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.init(title: title, background: background, scroll: scroll, trailing: { EmptyView() }, content: content)
    }
}

#Preview {
    NavigationStack {
        PageScaffold(title: "首页") { EmptyView() }
    }
}
