import SwiftUI

/// 统一页面骨架：标题在顶部栏内左侧、大字号、纯文字（不是按钮，不是居中 inline 小标题）。
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text(title)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
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
        .padding(.top, 4)
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
    NavigationStack {
        PageScaffold(title: "首页")
    }
}
