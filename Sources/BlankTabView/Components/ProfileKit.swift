import SwiftUI

/// “我”标记。
struct MeBadge: View {
    var body: some View {
        Text("我")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background { Capsule().fill(Color.accentColor) }
    }
}

/// 详情页统一滚动容器。
struct DetailScroll<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        // 根页自绘大标题时隐藏了导航栏，子页面要恢复系统导航栏（含默认返回按钮）
        .toolbar(.visible, for: .navigationBar)
    }
}
