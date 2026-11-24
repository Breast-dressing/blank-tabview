import SwiftUI
import UIKit

extension SkinItem: Identifiable {}

/// 单个皮肤详情：原生 sheet（内容不滚动、固定高度、禁用液态玻璃、隐藏抓手）。
struct SkinDetailSheet: View {
    let skin: SkinItem
    let seriesName: String
    let uin: String
    var zoomNamespace: Namespace.ID? = nil

    /// 固定高度：工具栏 44 + 图片 280 + 间距 8 + 两行文本 42 + 底部边距 20。
    private static let baseHeight: CGFloat = 44 + 280 + 8 + 42 + 20
    /// 图片按真实宽高比算出来的显示高度（最大 280）。
    @State private var imageHeight: CGFloat = 280
    @State private var sheetHeight: CGFloat = SkinDetailSheet.baseHeight

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?

    private var link: String {
        let safeId = skin.id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? skin.id
        let safeUin = uin.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? uin
        return "https://i2.y.qq.com/n3/medal_collection/pages/medal_collection_v3/skin_detail.html"
            + "?_hidehd=1&_fontscale=1&skin_id=\(safeId)&enc_uin=\(safeUin)"
    }

    private var shareURL: URL {
        URL(string: link) ?? URL(string: "https://y.qq.com")!
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 8) {
                imageView

                VStack(alignment: .leading, spacing: 4) {
                    Text(skin.seqNo.isEmpty ? "-" : skin.seqNo)
                        .font(.system(size: 19, weight: .bold))

                    HStack(spacing: 8) {
                        if !skin.unlockedDate.isEmpty {
                            Text(skin.unlockedDate)
                        }
                        Text(skin.userCount > 0 ? "\(Fmt.thousands(skin.userCount)) 人已获得" : "- 人已获得")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Color(uiColor: .systemGroupedBackground))
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
        // 固定 394，图片比 280 矮时把差值减掉，底部不出现多出来的空白。
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color(uiColor: .systemGroupedBackground))
        .presentationCornerRadius(36)
        .zoomNavigationTransitionIfAvailable(id: skin.id, in: zoomNamespace)
    }

    /// 大图贴着工具栏，加载中在中心显示系统 ProgressView。
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
        .frame(maxWidth: .infinity)
        .frame(height: imageHeight)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .task(id: skin.pic) {
            image = await RemoteImageLoader.image(for: skin.pic)
            if let image {
                let maxWidth = UIScreen.main.bounds.width - 40
                let ratio = image.size.height / max(1, image.size.width)
                let height = min(280, maxWidth * ratio)
                imageHeight = height
                sheetHeight = SkinDetailSheet.baseHeight - (280 - height)
            }
        }
    }
}

extension Color {
    /// "#FAFAFA" / "#FFF" → Color。
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
