import SwiftUI
import UIKit

/// 系列详情：和乐迷皮肤页同一套版式——顶部成员信息（透明容器）+ 下面三列皮肤。
struct SkinSeriesView: View {
    let member: Member
    let artistName: String
    let seriesName: String
    let skins: [SkinItem]

    @State private var selectedSkin: SkinItem?
    @Namespace private var zoomNS

    private var unlockedCount: Int { skins.filter { $0.isUnlocked }.count }

    private var headerSubtitle: String {
        let artist = artistName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = member.artistName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = artist.isEmpty ? fallback : artist
        return name.isEmpty ? seriesName : "\(name)的\(seriesName)"
    }

    var body: some View {
        List {
            Section {
                MemberSectionHeader(
                    title: member.title,
                    pic: member.pic,
                    subtitle: headerSubtitle,
                    count: "\(unlockedCount)",
                    unit: "款"
                )
                .memberInfoRow()
            }
            .listSectionSpacing(.custom(0))

            Section {
                if skins.isEmpty {
                    StateNotice(title: "这个系列还没有皮肤")
                        .listRowBackground(Color.clear)
                } else {
                    SkinTileGrid(items: skins.sorted { $0.seq < $1.seq }, zoomNamespace: zoomNS) { skin in
                        selectedSkin = skin
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 14, trailing: 16))
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .navigationTitle(seriesName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedSkin) { skin in
            SkinDetailSheet(
                skin: skin,
                seriesName: seriesName,
                uin: member.itemId.isEmpty ? "" : member.itemId,
                zoomNamespace: zoomNS
            )
        }
    }
}

#Preview {
    NavigationStack {
        SkinSeriesView(member: Member(), artistName: "虞书欣", seriesName: "系列 3", skins: [])
    }
}
