import SwiftUI

struct SkinSeriesView: View {
    let seriesName: String
    let skins: [SkinItem]

    @State private var selectedSkin: SkinItem?
    @State private var selectedSeries = ""

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        DetailScroll {
            Text("\(seriesName) · 共 \(skins.count) 款")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                ForEach(skins.sorted { $0.seq < $1.seq }, id: \.self) { skin in
                    Button {
                        selectedSeries = seriesName
                        selectedSkin = skin
                    } label: {
                        SkinTileCell(skin: skin)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(seriesName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedSkin) { skin in
            SkinDetailSheet(skin: skin, seriesName: selectedSeries, uin: "")
        }
    }
}

#Preview {
    NavigationStack {
        SkinSeriesView(seriesName: "系列 3", skins: [])
    }
}
