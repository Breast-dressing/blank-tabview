import SwiftUI

/// 统一页面骨架：左上角大标题（自绘头部，34pt 粗体，纯文字不用按钮），
/// 与右侧动作（如设置齿轮）同一行；内容紧贴标题下方。
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
        VStack(spacing: 0) {
            header
            if scroll {
                ScrollView {
                    stack
                }
                .scrollIndicators(.hidden)
            } else {
                stack
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.system(size: 34, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 10)
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

extension PageScaffold where Content == EmptyView {
    init(title: String, background: Color = Color(uiColor: .systemBackground)) {
        self.init(title: title, background: background, scroll: false, trailing: { EmptyView() }) { EmptyView() }
    }
}

#Preview {
    NavigationStack {
        PageScaffold(title: "首页")
    }
}
