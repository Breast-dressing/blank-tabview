import SwiftUI

struct RootTabView: View {
    @State private var selection: AppTab = AppTab.launchTab

    var body: some View {
        TabView(selection: $selection) {
            Tab(AppTab.home.title, systemImage: AppTab.home.systemImage, value: .home) {
                HomePage()
            }
            Tab(AppTab.profile.title, systemImage: AppTab.profile.systemImage, value: .profile) {
                ProfilePage()
            }
            Tab(value: AppTab.search, role: .prominent) {
                SearchPage()
            } label: {
                Label(AppTab.search.title, systemImage: AppTab.search.systemImage)
            }
        }
        // 仅用于 CI 截图核对：-demoSkins 时直接展示乐迷皮肤页。
        .fullScreenCover(isPresented: .constant(ProcessInfo.processInfo.arguments.contains("-demoSkins"))) {
            NavigationStack {
                SkinsView(memberId: "", medalId: "", medalName: "乐迷皮肤", scheme: "")
            }
        }
        // 仅用于 CI 截图核对：-demoSkin 时直接弹出皮肤弹窗。
        .sheet(isPresented: .constant(ProcessInfo.processInfo.arguments.contains("-demoSkin"))) {
            SkinDetailSheet(
                skin: Self.demoSkin,
                seriesName: "系列 1",
                uin: "",
                localImage: Self.demoImage
            )
        }
        // 仅用于 CI 截图核对：-demoSkinLocked 时弹出未解锁皮肤的弹窗。
        .sheet(isPresented: .constant(ProcessInfo.processInfo.arguments.contains("-demoSkinLocked"))) {
            SkinDetailSheet(
                skin: Self.demoSkinLocked,
                seriesName: "系列 1",
                uin: "demo",
                localImage: Self.demoImage
            )
        }
        // 仅用于 CI 截图核对：-demoSeries 时直接展示系列详情页。
        .fullScreenCover(isPresented: .constant(ProcessInfo.processInfo.arguments.contains("-demoSeries"))) {
            NavigationStack {
                SkinSeriesView(
                    member: Member(),
                    artistName: "虞书欣",
                    seriesName: "系列 1",
                    skins: Array(SkinsModel.demoSkins.prefix(3))
                )
            }
        }
        // 仅用于 CI 截图核对：-demoMedals 时直接展示「已获得奖章」页。
        .fullScreenCover(isPresented: .constant(ProcessInfo.processInfo.arguments.contains("-demoMedals"))) {
            NavigationStack {
                MedalsHallView(memberId: "demo")
            }
        }
        // 仅用于 CI 截图核对：-demoRank 时直接展示周榜详情页。
        .fullScreenCover(isPresented: .constant(ProcessInfo.processInfo.arguments.contains("-demoRank"))) {
            NavigationStack {
                RankDetailView(memberId: "demo", scheme: "", title: "周榜", tabName: "周榜")
            }
        }
        // 仅用于 CI 截图核对：-demoMedalSheet 时直接弹出分级勋章弹窗（可左右滑动）。
        .sheet(isPresented: .constant(ProcessInfo.processInfo.arguments.contains("-demoMedalSheet"))) {
            MedalDetailSheet(
                memberId: "",
                target: Self.demoMedalTarget,
                demoLevels: Self.demoMedalLevels
            )
        }
    }

    private static var demoMedalTarget: MedalSheetTarget {
        MedalSheetTarget(
            medalId: "demo-medal",
            medalName: "10日见习天使",
            scheme: "",
            imageUrl: "",
            date: "2025-12-09",
            number: "NO.3"
        )
    }

    private static let demoMedalLevels: [MedalLevel] = (1...3).map { level in
        var item = MedalLevel()
        item.level = level
        item.state = level <= 2 ? 2 : 0
        item.name = "\(level * 10)日见习天使"
        item.medalId = "demo-medal"
        item.createTime = "2025-12-0\(level)"
        return item
    }

    private static var demoSkin: SkinItem {
        var skin = SkinItem()
        skin.id = "demo"
        skin.name = "10日见习天使"
        skin.seqNo = "-"
        skin.unlockedDate = "2025-12-09"
        skin.userCount = 18033
        return skin
    }

    /// 未解锁皮肤：用于核对弹窗里的「打开」按钮。
    private static var demoSkinLocked: SkinItem {
        var skin = SkinItem()
        skin.id = "demo-locked"
        skin.name = "100日晨星天使"
        skin.seqNo = "NO.3"
        skin.unlockedDate = ""
        skin.userCount = 0
        skin.isUnlocked = false
        return skin
    }

    /// 1:1 的占位图，用来核对弹窗高度。
    private static let demoImage: UIImage = {
        let size = CGSize(width: 800, height: 800)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 80, y: 300, width: 640, height: 200))
        }
    }()
}
