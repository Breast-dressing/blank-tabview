import SwiftUI
import UIKit

/// 勋章卡：与乐迷皮肤完全同一套卡片形态（图片 86 / 名字 / 日期或「待解锁」）。
struct MedalSkinTileCell: View {
    let item: MedalItem
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .saturation(item.attained ? 1 : 0)
                        .opacity(item.attained ? 1 : 0.55)
                } else if failed || item.picUrl.isEmpty {
                    // 没图或加载失败给个静态占位，不要一直转圈。
                    Image(systemName: "rosette")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(.tertiary)
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 86)
            .task(id: item.picUrl) {
                guard !item.picUrl.isEmpty else { return }
                let loaded = await RemoteImageLoader.image(for: item.picUrl)
                image = loaded
                failed = loaded == nil
            }

            Text(item.name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(item.tileSubtitle)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(height: 13)
        }
    }
}

/// 勋章三列格（带 zoom 出发地）：整块包在透明圆角矩形里，zoom 挂在矩形上。
struct ZoomedMedalTileGrid: View {
    let items: [MedalItem]
    var zoomNamespace: Namespace.ID? = nil
    /// 划到最后一张时触发，用于分页懒加载。
    var onLastAppear: (() -> Void)? = nil
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
                .onAppear {
                    guard let last = items.last, last == item else { return }
                    onLastAppear?()
                }
            }
        }
    }
}
