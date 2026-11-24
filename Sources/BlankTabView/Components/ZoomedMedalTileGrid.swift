import SwiftUI

/// 勋章三列格（带 zoom 出发地）：整块（图 + 名字 + 日期）包在透明圆角矩形里。
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
                    MedalTileCell(item: item)
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
