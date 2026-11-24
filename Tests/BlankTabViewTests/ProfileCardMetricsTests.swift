import XCTest
@testable import BlankTabView

/// 票据卡几何参数对齐 Flutter 原版（MemberTicketCard）：
/// 头像 80 / 间隙 6 / 倒角 8 / 圆角 28 / 卡顶留白 20，圆心距左 36、距顶 34。
final class ProfileCardMetricsTests: XCTestCase {
    func testAvatarGeometryMatchesFlutter() {
        XCTAssertEqual(ProfileCardMetrics.avatarSize, 80)
        XCTAssertEqual(ProfileCardMetrics.avatarRadius, 40)
        XCTAssertEqual(ProfileCardMetrics.gap, 6)
        XCTAssertEqual(ProfileCardMetrics.cutCorner, 8)
        XCTAssertEqual(ProfileCardMetrics.cornerRadius, 28)
        XCTAssertEqual(ProfileCardMetrics.cardTopInset, 20)
    }

    func testAvatarCenterIsPlacedRelativeToCard() {
        // 圆心距卡片左边 = 半径 - 4，距卡片顶部 = 半径 - 6
        XCTAssertEqual(ProfileCardMetrics.avatarCenterX, ProfileCardMetrics.avatarRadius - 4)
        XCTAssertEqual(ProfileCardMetrics.avatarCenterY, ProfileCardMetrics.avatarRadius - 6)
    }

    func testAvatarOffsetComesFromCenterAndRadius() {
        XCTAssertEqual(
            ProfileCardMetrics.avatarOffsetX,
            ProfileCardMetrics.avatarCenterX - ProfileCardMetrics.avatarRadius
        )
        XCTAssertEqual(
            ProfileCardMetrics.avatarOffsetY,
            ProfileCardMetrics.avatarCenterY - ProfileCardMetrics.avatarRadius
        )
        // 头像左右各探出卡片 4pt、上方探出 6pt
        XCTAssertEqual(ProfileCardMetrics.avatarOffsetX, -4)
        XCTAssertEqual(ProfileCardMetrics.avatarOffsetY, -6)
    }

    func testGapAndCutArePositive() {
        XCTAssertGreaterThan(ProfileCardMetrics.gap, 0)
        XCTAssertGreaterThan(ProfileCardMetrics.cutCorner, 0)
        XCTAssertLessThan(ProfileCardMetrics.cutCorner, ProfileCardMetrics.avatarRadius)
    }

    func testHeaderClearsAvatar() {
        XCTAssertEqual(ProfileCardMetrics.headerLeading, ProfileCardMetrics.avatarSize + 24)
    }

    func testTicketShapeFillsRequestedRect() {
        let rect = CGRect(x: 0, y: 0, width: 340, height: 260)
        let path = ProfileTicketShape().path(in: rect)
        XCTAssertEqual(path.boundingRect.width, 340, accuracy: 0.5)
        XCTAssertEqual(path.boundingRect.height, 260, accuracy: 0.5)
    }

    func testTicketShapeFallsBackOnTinyRect() {
        let rect = CGRect(x: 0, y: 0, width: 60, height: 40)
        let path = ProfileTicketShape().path(in: rect)
        XCTAssertFalse(path.isEmpty)
    }
}
