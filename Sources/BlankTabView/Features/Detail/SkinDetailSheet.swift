import SwiftUI
import UIKit

extension SkinItem: Identifiable {}

/// 单个皮肤详情：原生半屏 sheet（默认液态玻璃背景、隐藏抓手、内容不滚动）。
struct SkinDetailSheet: View {
    let skin: SkinItem
    let seriesName: String
    let uin: String
    var zoomNamespace: Namespace.ID? = nil
    /// 截图 / 调试时用本地图片，避免依赖网络。
    var localImage: UIImage? = nil

    @State private var imageHeight: CGFloat = 280

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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        // 默认半屏 + 系统自带液态玻璃背景，不自己铺白条底色。
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(36)
        .zoomNavigationTransitionIfAvailable(id: skin.id, in: zoomNamespace)
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
                let height = min(280, maxWidth * ratio)
                imageHeight = height
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
