import SwiftUI
import UIKit

extension SkinItem: Identifiable {}

/// 单个皮肤详情（sheet）：大图 + 名称 + 全服解锁人数 + 右下角「获取日期｜限定编号」。
/// 工具栏左上关闭、右上分享。弹窗高度随内容自适应。
struct SkinDetailSheet: View {
    let skin: SkinItem
    let seriesName: String
    let uin: String

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

    /// 右下角一行：获取日期｜限定编号（缺一项时只显示另一项）。
    private var metaText: String {
        [skin.unlockedDate, skin.seqNo]
            .filter { !$0.isEmpty }
            .joined(separator: "｜")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                imageView

                VStack(alignment: .leading, spacing: 4) {
                    Text(skin.name)
                        .font(.system(size: 19, weight: .bold))
                    Text(skin.userCount > 0 ? "全服解锁 \(Fmt.thousands(skin.userCount)) 人" : "全服解锁人数 -")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Spacer(minLength: 0)
                    Text(metaText.isEmpty ? "-" : metaText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                (Color(hex: skin.bgColor) ?? Color(uiColor: .systemGroupedBackground))
                    .ignoresSafeArea()
            )
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
        .presentationSizing(.fitted)
    }

    /// 大圆角卡片直接展示接口给的大图，不铺底色；加载中在整卡中心显示系统 ProgressView。
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
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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
