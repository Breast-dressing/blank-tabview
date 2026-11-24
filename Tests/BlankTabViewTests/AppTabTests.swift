import XCTest
@testable import BlankTabView

final class AppTabTests: XCTestCase {
    func testThreeTabsInOrder() {
        XCTAssertEqual(AppTab.allCases, [.home, .profile, .search])
    }

    func testTitles() {
        XCTAssertEqual(AppTab.allCases.map(\.title), ["首页", "我的", "搜索"])
    }

    func testSystemImagesAreDistinct() {
        let images = AppTab.allCases.map(\.systemImage)
        XCTAssertEqual(Set(images).count, images.count)
    }

    func testRawValuesAreStable() {
        XCTAssertEqual(AppTab.allCases.map(\.rawValue), ["home", "profile", "search"])
    }
}
