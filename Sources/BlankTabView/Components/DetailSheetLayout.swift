import SwiftUI

/// 详情弹窗统一尺寸：皮肤详情与奖章详情共用同一套数值。
/// 54（工具栏）+ 280（图片）+ 8（间距）+ 40（底部行）+ 16（底边距）。
enum DetailSheetMetrics {
    static let height: CGFloat = 400
    static let mediaHeight: CGFloat = 280
    static let cornerRadius: CGFloat = 28
    static let leadingInset: CGFloat = 20
    static let edgeInset: CGFloat = 16
}

/// 皮肤 / 奖章详情共用的弹窗内容骨架：等高媒体区 + 左下两行 + 右下「打开」玻璃按钮。
/// 所有弹窗只写这一套 UI，只是喂不同数据。
struct DetailSheetContent<Media: View>: View {
    let primary: String
    let secondary: String
    let onOpen: () -> Void
    let media: Media

    @State private var rowHeight: CGFloat = 0

    init(
        primary: String,
        secondary: String,
        onOpen: @escaping () -> Void,
        @ViewBuilder media: () -> Media
    ) {
        self.primary = primary
        self.secondary = secondary
        self.onOpen = onOpen
        self.media = media()
    }

    var body: some View {
        GeometryReader { proxy in
            let mediaWidth = proxy.size.width - DetailSheetMetrics.leadingInset - DetailSheetMetrics.edgeInset

            VStack(alignment: .leading, spacing: 8) {
                media
                    .frame(width: mediaWidth, height: DetailSheetMetrics.mediaHeight)
                    .clipShape(
                        RoundedRectangle(cornerRadius: DetailSheetMetrics.cornerRadius, style: .continuous)
                    )

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(primary)
                            .font(.system(size: 19, weight: .bold))
                            .lineLimit(1)

                        Text(secondary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowHeight = $0 }

                    Spacer(minLength: 8)

                    Button(action: onOpen) {
                        Text("打开")
                            .font(.system(size: 15, weight: .semibold))
                            .padding(.horizontal, 14)
                            .frame(maxHeight: .infinity)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .frame(height: rowHeight > 0 ? rowHeight : 44)
                }
            }
            .padding(.leading, DetailSheetMetrics.leadingInset)
            .padding(.trailing, DetailSheetMetrics.edgeInset)
            .padding(.bottom, DetailSheetMetrics.edgeInset)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }
}

/// 弹窗里的等比媒体图：高度恒等于设定高度，宽度按比例铺满后裁切。
struct DetailSheetImage: View {
    let image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}
