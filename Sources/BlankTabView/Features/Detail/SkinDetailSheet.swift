import SwiftUI
import UIKit

extension SkinItem: Identifiable {}

/// 单个皮肤详情：原生 sheet（内容不滚动、固定高度、禁用液态玻璃、隐藏抓手）。
/// 图片贴着工具栏、文本贴着图片底部，左 / 右 / 底部留白一致。
struct SkinDetailSheet: View {
    let skin: SkinItem
    let seriesName: String
    let uin: String
    var zoomNamespace: Namespace.ID? = nil

    /// 工具栏 44 + 图片 280 + 间距 8 + 两行文本 42 + 底部边距 20（与左边距一致）。
    static let sheetHeight: CGFloat = 44 + 280 + 8 + 42 + 20

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
                    // 原来是皮肤名字的位置，换成限定编号，字号字重不变。
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
            .frame(maxHeight: .infinity, alignment: .top)
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
        .presentationDetents([.height(SkinDetailSheet.sheetHeight)])
        .presentationDragIndicator(.hidden)
        // 关掉 sheet 的液态玻璃背景，改成不透明系统分组灰。
        .presentationBackground(Color(uiColor: .systemGroupedBackground))
        .presentationCornerRadius(36)
        .zoomNavigationTransitionIfAvailable(id: skin.id, in: zoomNamespace)
    }

    /// 大图直接贴着工具栏，圆角裁剪，加载中在中心显示系统 ProgressView。
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
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .task(id: skin.pic) {
            image = await RemoteImageLoader.image(for: skin.pic)
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
