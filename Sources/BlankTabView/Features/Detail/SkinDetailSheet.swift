import SwiftUI
import UIKit

extension SkinItem: Identifiable {}

/// 单个皮肤详情：原生 sheet（固定 369 高度、普通材质背景、隐藏抓手、内容不滚动）。
struct SkinDetailSheet: View {
    let skin: SkinItem
    let seriesName: String
    let uin: String
    var zoomNamespace: Namespace.ID? = nil
    /// 截图 / 调试时用本地图片，避免依赖网络。
    var localImage: UIImage? = nil

    /// 固定高度 369：工具栏 + 图片 + 间距 + 底部一行文本与按钮。
    private static let baseHeight: CGFloat = 369

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    /// 左侧两行文本的实际高度，用来让「打开」按钮等高。
    @State private var textHeight: CGFloat = 0

    private var link: String {
        let safeId = skin.id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? skin.id
        let safeUin = uin.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? uin
        return "https://i2.y.qq.com/n3/medal_collection/pages/medal_collection_v3/skin_detail.html"
            + "?_hidehd=1&_fontscale=1&skin_id=\(safeId)&enc_uin=\(safeUin)"
    }

    /// 没有限定编号时，把获得时间放到编号的位置。
    private var primaryText: String {
        if !skin.seqNo.isEmpty { return skin.seqNo }
        return skin.unlockedDate.isEmpty ? "-" : skin.unlockedDate
    }

    private var secondaryText: String {
        let count = skin.userCount > 0 ? "\(Fmt.thousands(skin.userCount)) 人已获得" : "- 人已获得"
        if skin.seqNo.isEmpty { return count }
        return skin.unlockedDate.isEmpty ? count : "\(skin.unlockedDate)  \(count)"
    }

    private var shareURL: URL {
        URL(string: link) ?? URL(string: "https://y.qq.com")!
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 8) {
                // 图片吃掉剩余高度，底部一行因此能稳定压在底部边距上。
                imageView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 左下两行文本（限定编号 / 获得时间 + 人数），右下「打开」玻璃按钮，与两行文本等高。
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(primaryText)
                            .font(.system(size: 19, weight: .bold))
                            .lineLimit(1)

                        Text(secondaryText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { textHeight = $0 }

                    Spacer(minLength: 8)

                    Button {
                        openInQQMusic()
                    } label: {
                        Text("打开")
                            .font(.system(size: 15, weight: .semibold))
                            .padding(.horizontal, 14)
                            .frame(maxHeight: .infinity)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .frame(height: textHeight > 0 ? textHeight : 44)
                }
            }
            // 左右与底边距跟工具栏按钮一致：左 20 / 右 16 / 底 16（底边向屏幕边缘量，不叠加安全区）。
            .padding(.leading, 20)
            .padding(.trailing, 16)
            .padding(.bottom, 16)
            .ignoresSafeArea(.container, edges: .bottom)
            .navigationTitle(skin.name.isEmpty ? "皮肤详情" : skin.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: shareURL) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        // 高度恒为 369：不随图片比例变化，避免关掉再开时 detent 落回全屏。
        .detailSheetChrome(height: Self.baseHeight)
        .zoomNavigationTransitionIfAvailable(id: skin.id, in: zoomNamespace)
    }

    /// 用 QQ 音乐打开这张皮肤对应的页面。
    private func openInQQMusic() {
        guard let url = URL(string: link) else { return }
        UIApplication.shared.open(url)
    }

    private var imageView: some View {
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
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .task(id: skin.pic) {
            if let localImage {
                image = localImage
            } else {
                image = await RemoteImageLoader.image(for: skin.pic)
            }
        }
    }
}

extension Color {
    init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text.removeFirst() }
        guard !text.isEmpty else { return nil }
        if text.count == 3 {
            text = text.map { "\($0)\($0)" }.joined()
        }
        guard text.count == 6, let value = UInt64(text, radix: 16) else { return nil }
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self = Color(red: red, green: green, blue: blue)
    }
}
