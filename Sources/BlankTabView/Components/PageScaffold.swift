import SwiftUI

/// 统一页面骨架：标题用系统工具栏标题位（`inlineLarge` = 同一行内的大标题），
/// 再用 `toolbarTitleAlignment(.leading)` 顶到左侧；右侧动作（齿轮等）在同一条工具栏里。
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
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbarTitleLeading()
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
        .padding(.top, 2)
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

/// iOS 27.2 才有的标题对齐 API：在该版本以下保持系统默认。
private struct ToolbarTitleLeading: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 27.2, *) {
            content.toolbarTitleAlignment(.leading)
        } else {
            content
        }
    }
}

extension View {
    func toolbarTitleLeading() -> some View {
        modifier(ToolbarTitleLeading())
    }
}

#Preview {
    NavigationStack {
        PageScaffold(title: "首页") { EmptyView() }
    }
}
