import SwiftUI

// MARK: - 共用列表样式

/// 成员信息行：透明容器，内容左右与下方卡片边缘对齐，底部留出与卡片一致的间距。
/// 供乐迷皮肤、系列详情、已获得奖章、勋章模块等页面统一使用。
extension View {
    func memberInfoRow(top: CGFloat = 8, bottom: CGFloat = 20) -> some View {
        self
            // 列表行默认左右各缩进 16，这里反向抵消，内容左右与下方卡片边缘齐平。
            .padding(.horizontal, -16)
            .listRowInsets(EdgeInsets(top: top, leading: 0, bottom: bottom, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

// MARK: - 共用弹窗样式

/// 皮肤 / 勋章详情共用弹窗外壳：固定高度、禁用液态玻璃、圆角在 zoom 动画全程保持。
struct DetailSheetChrome: ViewModifier {
    let height: CGFloat
    var cornerRadius: CGFloat = 36

    func body(content: Content) -> some View {
        content
            // 材质自己画成圆角矩形并铺到屏幕底部：动画过程中容器边角不会露出直角，
            // 也不会因为忽略安全区而把 sheet 布局撑高。
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
                    .ignoresSafeArea(edges: .bottom)
            }
            .presentationDetents([.height(height)])
            .presentationDragIndicator(.hidden)
            .presentationBackground(.clear)
            .presentationCornerRadius(cornerRadius)
    }
}

extension View {
    func detailSheetChrome(height: CGFloat, cornerRadius: CGFloat = 36) -> some View {
        modifier(DetailSheetChrome(height: height, cornerRadius: cornerRadius))
    }
}
