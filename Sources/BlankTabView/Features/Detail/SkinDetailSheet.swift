import SwiftUI
import UIKit

extension SkinItem: Identifiable {}

/// 单个皮肤详情：原生 sheet（内容不滚动、固定高度、禁用液态玻璃、隐藏抓手）。
struct SkinDetailSheet: View {
    let skin: SkinItem
    let seriesName: String
    let uin: String
    var zoomNamespace: Namespace.ID? = nil
    /// 截图 / 调试时用本地图片，避免依赖网络。
    var localImage: UIImage? = nil

    /// 图片最大显示高度：280 实测偏高，收到 235。
    static let maxImageHeight: CGFloat = 235
    /// 固定高度：工具栏 55 + 图片 235 + 间距 8 + 两行文本 42 + 底部 8 = 348。
    private static let baseHeight: CGFloat = 55 + SkinDetailSheet.maxImageHeight + 8 + 42 + 8
    /// 图片按真实宽高比算出来的显示高度（最大 maxImageHeight）。
    @State private var imageHeight: CGFloat = SkinDetailSheet.maxImageHeight
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
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbarBackground(Color(uiColor: .systemGroupedBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
        // 整个 sheet 子树统一圆角裁切：内容底色 / 导航栏底色都裁成 36 圆角，
        // zoom 过渡期间不会露出直角底色。
        .background(Color(uiColor: .systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        // 固定 348，图片比 235 矮时把差值减掉，底部不出现多出来的空白。
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.hidden)
        // 背景交给内容自己画，sheet 容器只保留圆角，避免 zoom 过渡时露出直角底色。
        .presentationBackground(.clear)
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
            let loaded: UIImage?
            if let localImage {
                loaded = localImage
            } else {
                loaded = await RemoteImageLoader.image(for: skin.pic)
            }
            image = loaded
            if let image = loaded {
                let maxWidth = UIScreen.main.bounds.width - 40
                let ratio = image.size.height / max(1, image.size.width)
                let height = min(SkinDetailSheet.maxImageHeight, maxWidth * ratio)
                imageHeight = height
                sheetHeight = SkinDetailSheet.baseHeight - (SkinDetailSheet.maxImageHeight - height)
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
