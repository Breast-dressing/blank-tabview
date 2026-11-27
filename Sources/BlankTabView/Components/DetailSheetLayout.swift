import SwiftUI

/// 详情弹窗统一尺寸：皮肤详情与奖章详情共用同一套数值。
enum DetailSheetMetrics {
    /// 弹窗总高：保持之前的 369，不做任何放大。
    static let height: CGFloat = 369
    static let cornerRadius: CGFloat = 28
    static let leadingInset: CGFloat = 20
    static let edgeInset: CGFloat = 16
}

/// 皮肤 / 奖章详情共用的弹窗内容骨架：媒体区 + 左下两行 + 右下「打开」玻璃按钮。
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
            // 图片区吃掉除底部两行之外的全部可用空间：与之前的 280 框表现一致，且不裁切。
            let mediaHeight = max(160, proxy.size.height - max(44, rowHeight) - 8 - DetailSheetMetrics.edgeInset)
            let mediaWidth = proxy.size.width - DetailSheetMetrics.leadingInset - DetailSheetMetrics.edgeInset

            VStack(alignment: .leading, spacing: 8) {
                media
                    .frame(width: mediaWidth, height: mediaHeight)
                    .clipShape(
                        RoundedRectangle(cornerRadius: DetailSheetMetrics.cornerRadius, style: .continuous)
                    )

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        // 限定编号 / 标题：系统语义字号 title3（默认 20pt）+ bold 字重。
                        Text(primary)
                            .font(.title3)
                            .fontWeight(.bold)
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
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .frame(maxHeight: .infinity)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .frame(height: max(44, rowHeight))
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

/// 弹窗里的媒体图：保持原比例居中，完整显示、绝不裁切（高图等比缩到图片区高度）。
struct DetailSheetImage: View {
    let image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
