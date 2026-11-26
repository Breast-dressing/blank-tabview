import SwiftUI
import UIKit

extension SkinItem: Identifiable {}

/// 单个皮肤详情：和奖章详情共用同一套弹窗外壳与内容骨架。
struct SkinDetailSheet: View {
    let skin: SkinItem
    let seriesName: String
    let uin: String
    var zoomNamespace: Namespace.ID? = nil
    /// 截图 / 调试时用本地图片，避免依赖网络。
    var localImage: UIImage? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?

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
            DetailSheetContent(
                primary: primaryText,
                secondary: secondaryText,
                onOpen: openInQQMusic
            ) {
                DetailSheetImage(image: image)
            }
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
        // 高度固定，不随图片比例变化。
        .detailSheetChrome(height: DetailSheetMetrics.height, cornerRadius: 36)
        .zoomNavigationTransitionIfAvailable(id: skin.id, in: zoomNamespace)
        .task(id: skin.pic) {
            if let localImage {
                image = localImage
            } else {
                image = await RemoteImageLoader.image(for: skin.pic)
            }
        }
    }

    /// 用 QQ 音乐打开这张皮肤对应的页面。
    private func openInQQMusic() {
        guard let url = URL(string: link) else { return }
        UIApplication.shared.open(url)
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
