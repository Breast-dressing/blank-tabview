import SwiftUI

/// 我的页可跳转的详情页。
enum ProfileDestination: Hashable {
    case rank(memberId: String, scheme: String, title: String, tabName: String)
    case medalHall(memberId: String)
    case medalModule(memberId: String, moduleId: String, moduleName: String, tabName: String)
    case skins(memberId: String, medalId: String, medalName: String, scheme: String)
    case skinSeries(seriesName: String, skins: [SkinItem])
    case family(Family)
    case member(String)
    case memberList(Family)
}
