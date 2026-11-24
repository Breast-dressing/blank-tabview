import SwiftUI
import UIKit

/// 勋章卡：与乐迷皮肤完全同一套卡片形态（图片 86 / 大圆角 / 名字 / 日期或「待解锁」）。
struct MedalSkinTileCell: View {
    let item: MedalItem
    @State private var image: UIImage?

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .saturation(item.unlocked ? 1 : 0)
                        .opacity(item.unlocked ? 1 : 0.55)
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 86)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .task(id: item.picUrl) {
                image = await RemoteImageLoader.image(for: item.picUrl)
            }

            Text(item.name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(item.unlocked ? item.subtitle : "待解锁")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(height: 13)
        }
    }
}

/// 勋章三列格（带 zoom 出发地）：整块包在透明圆角矩形里。
struct ZoomedMedalTileGrid: View {
    let items: [MedalItem]
    var zoomNamespace: Namespace.ID? = nil
    let onTap: (MedalItem) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(items, id: \.self) { item in
                Button {
                    onTap(item)
                } label: {
                    MedalSkinTileCell(item: item)
                        .padding(6)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.clear)
                )
                .matchedTransitionSourceIfAvailable(id: item.medalId, in: zoomNamespace)
            }
        }
    }
}
