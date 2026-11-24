import XCTest
@testable import BlankTabView

final class ProfileCardMetricsTests: XCTestCase {
    func testLobeSurroundsAvatarWithRing() {
        XCTAssertEqual(
            ProfileCardMetrics.lobeDiameter,
            ProfileCardMetrics.avatarSize + ProfileCardMetrics.ringPadding * 2
        )
        XCTAssertGreaterThan(ProfileCardMetrics.lobeDiameter, ProfileCardMetrics.avatarSize)
    }

    func testLobeProtrudesBeyondCardCorner() {
        XCTAssertLessThan(ProfileCardMetrics.lobeOffset, 0)
        XCTAssertGreaterThan(ProfileCardMetrics.lobeDiameter, ProfileCardMetrics.cornerRadius)
    }

    func testAvatarSitsInsideLobe() {
        XCTAssertGreaterThan(ProfileCardMetrics.avatarOffset, ProfileCardMetrics.lobeOffset)
        XCTAssertEqual(
            ProfileCardMetrics.avatarOffset + ProfileCardMetrics.avatarSize + ProfileCardMetrics.ringPadding,
            ProfileCardMetrics.lobeDiameter + ProfileCardMetrics.lobeOffset
        )
    }
}
