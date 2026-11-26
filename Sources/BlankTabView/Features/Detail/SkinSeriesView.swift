import SwiftUI

/// 系列详情：已经没有任何自己的 UI，整页复用乐迷皮肤页那一套（DetailPageScaffold + DetailSeriesCard）。
struct SkinSeriesView: View {
    let member: Member
    let artistName: String
    let seriesName: String
    let skins: [SkinItem]

    var body: some View {
        SkinSeriesPage(
            member: member,
            artistName: artistName,
            seriesName: seriesName,
            skins: skins,
            uin: member.itemId
        )
    }
}
