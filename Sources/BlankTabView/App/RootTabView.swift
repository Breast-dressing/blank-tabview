import SwiftUI
import UIKit

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
        // 仅用于 CI 截图核对：-demoSkins 时直接展示乐迷皮肤页（成员信息平铺效果）。
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

#Preview {
    RootTabView()
}
