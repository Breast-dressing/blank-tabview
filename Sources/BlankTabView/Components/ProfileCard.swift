import SwiftUI

/// 票据卡的几何参数，全部对齐 Flutter 原版 `MemberTicketCard`：
/// 头像 80、头像与卡面缺口间隙 6、缺口倒角 8、卡面圆角 28。
/// 头像圆心：距卡片左边 = 半径 - 4 = 36，距卡片顶部 = 半径 - 6 = 34。
/// 左右两侧虚线处的半圆缺口与头像缺口的倒角共用 `sideNotchRadius` 这一个变量。
enum ProfileCardMetrics {
    static let cornerRadius: CGFloat = 28
    static let avatarSize: CGFloat = 80
    static let avatarRadius: CGFloat = avatarSize / 2
    /// 头像与卡片缺口之间的页面底色间隙
    static let gap: CGFloat = 6
    /// 缺口与顶边 / 左边交接处的倒角
    static let cutCorner: CGFloat = 8

    /// 左右两侧虚线处半圆缺口的半径（与头像缺口倒角同值，统一引用这一个变量）
    static let sideNotchRadius: CGFloat = cutCorner
    /// 半圆缺口直径
    static var sideNotchDiameter: CGFloat { sideNotchRadius * 2 }

    /// 卡片顶部留白：正好等于头像上探出卡片的高度，不留额外间隙
    static var cardTopInset: CGFloat { -avatarOffsetY }

    static let avatarCenterX: CGFloat = avatarRadius - 4
    static let avatarCenterY: CGFloat = avatarRadius - 6
    static let avatarOffsetX: CGFloat = avatarCenterX - avatarRadius
    static let avatarOffsetY: CGFloat = avatarCenterY - avatarRadius
    /// 卡片头部左侧缩进：头像直径 + 24
    static let headerLeading: CGFloat = avatarSize + 24
}

/// 票面轮廓：圆角矩形左上角被“头像 + 间隙”的圆咬出缺口，
/// 缺口与顶边 / 左边交接处用 8pt 圆角倒角；虚线处左右两边各被半圆咬开。
struct ProfileTicketShape: Shape {
    /// 虚线位置（卡片坐标系，0 时不挖侧面半圆）
    var notchY: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let corner = ProfileCardMetrics.cornerRadius
        let f = ProfileCardMetrics.cutCorner
        let r = ProfileCardMetrics.avatarRadius + ProfileCardMetrics.gap
        let cx = ProfileCardMetrics.avatarCenterX
        let cy = ProfileCardMetrics.avatarCenterY
        let d = r + f
        let sideNotch = ProfileCardMetrics.sideNotchRadius
        let hasSideNotch = notchY > sideNotch && notchY < rect.height - sideNotch

        let topCenter = CGPoint(
            x: cx + sqrt(max(0, d * d - (f - cy) * (f - cy))),
            y: f
        )
        let leftCenter = CGPoint(
            x: f,
            y: cy + sqrt(max(0, d * d - (f - cx) * (f - cx)))
        )

        if topCenter.x >= rect.width - corner || leftCenter.y >= rect.height - f {
            return Path(roundedRect: rect, cornerRadius: corner)
        }

        let hole = CGPoint(x: cx, y: cy)
        let thetaTop = atan2(topCenter.y - hole.y, topCenter.x - hole.x)
        let thetaLeft = atan2(leftCenter.y - hole.y, leftCenter.x - hole.x)

        func point(_ center: CGPoint, _ radius: CGFloat, _ angle: CGFloat) -> CGPoint {
            CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }
        func appendArc(_ path: inout Path, center: CGPoint, radius: CGFloat, start: CGFloat, sweep: CGFloat) {
            let steps = 24
            for i in 1...steps {
                let angle = start + sweep * CGFloat(i) / CGFloat(steps)
                path.addLine(to: point(center, radius, angle))
            }
        }

        var path = Path()
        path.move(to: point(topCenter, f, -.pi / 2))

        let topTangent = point(hole, r, thetaTop)
        var topSweep = atan2(topTangent.y - topCenter.y, topTangent.x - topCenter.x) - (-.pi / 2)
        if topSweep > 0 { topSweep -= 2 * .pi }
        appendArc(&path, center: topCenter, radius: f, start: -.pi / 2, sweep: topSweep)

        appendArc(&path, center: hole, radius: r, start: thetaTop, sweep: thetaLeft - thetaTop)

        let leftTangent = point(hole, r, thetaLeft)
        let leftStart = atan2(leftTangent.y - leftCenter.y, leftTangent.x - leftCenter.x)
        var leftSweep = CGFloat.pi - leftStart
        if leftSweep > 0 { leftSweep -= 2 * .pi }
        appendArc(&path, center: leftCenter, radius: f, start: leftStart, sweep: leftSweep)

        if hasSideNotch {
            path.addLine(to: CGPoint(x: 0, y: notchY - sideNotch))
            appendArc(&path, center: CGPoint(x: 0, y: notchY), radius: sideNotch, start: -.pi / 2, sweep: .pi)
        }
        path.addLine(to: CGPoint(x: 0, y: rect.height - corner))
        appendArc(&path, center: CGPoint(x: corner, y: rect.height - corner), radius: corner, start: .pi, sweep: -.pi / 2)
        path.addLine(to: CGPoint(x: rect.width - corner, y: rect.height))
        appendArc(&path, center: CGPoint(x: rect.width - corner, y: rect.height - corner), radius: corner, start: .pi / 2, sweep: -.pi / 2)

        if hasSideNotch {
            path.addLine(to: CGPoint(x: rect.width, y: notchY + sideNotch))
            appendArc(&path, center: CGPoint(x: rect.width, y: notchY), radius: sideNotch, start: .pi / 2, sweep: .pi)
        }
        path.addLine(to: CGPoint(x: rect.width, y: corner))
        appendArc(&path, center: CGPoint(x: rect.width - corner, y: corner), radius: corner, start: 0, sweep: -.pi / 2)
        path.closeSubpath()
        return path
    }
}

/// 头像：统一走 `RemoteImageLoader`（带 Referer / UA，QQ 图床才能拿到图）；
/// `showsRing` 控制那圈浅色描边（「我的」票据卡不带）。
struct AvatarCircle: View {
    let urlString: String
    var size: CGFloat = ProfileCardMetrics.avatarSize
    var showsRing: Bool = true

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            Circle().fill(Color(uiColor: .tertiarySystemFill))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if urlString.isEmpty || failed {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            if showsRing {
                Circle().strokeBorder(Color(uiColor: .systemBackground).opacity(0.9), lineWidth: 1)
            }
        }
        .task(id: urlString) {
            if let hit = RemoteImageLoader.cached(urlString) {
                image = hit
                failed = false
                return
            }
            let loaded = await RemoteImageLoader.image(for: urlString)
            image = loaded
            failed = loaded == nil
        }
    }

    private var fallback: some View {
        Image(systemName: "person.fill")
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}

#Preview {
    ProfileTicketShape(notchY: 120)
        .fill(Color(uiColor: .secondarySystemGroupedBackground))
        .frame(height: 220)
        .padding(20)
        .background(Color(uiColor: .systemGroupedBackground))
}
