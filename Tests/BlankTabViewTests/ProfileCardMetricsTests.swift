import XCTest
@testable import BlankTabView

final class ProfileCardMetricsTests: XCTestCase {
    func testLobeSurroundsAvatarWithRing() {
        let lobes = ProfileCardMetrics.lobeDiameter
        XCTAssertEqual(lobes, ProfileCardMetrics.avatarSize + ProfileCardMetrics.ringPadding * 2)
        XCTAssertGreaterThan(lobes, ProfileCardMetrics.avatarSize)
    }

    func testLobeProtrudesBeyondCardCorner() {
        XCTAssertLessThan(ProfileCardMetrics.lobeOffset, 0)
        XCTAssertGreaterThan(ProfileCardMetrics.lobeDiameter, ProfileCardMetrics.cornerRadius)
    }

    func testCardIsTallerThanLobe() {
        XCTAssertGreaterThan(ProfileCardMetrics.height, ProfileCardMetrics.lobeDiameter)
    }
}
