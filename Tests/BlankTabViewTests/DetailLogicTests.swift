import XCTest
@testable import BlankTabView

final class DetailLogicTests: XCTestCase {
    func testSkinItemCodableRoundTrip() throws {
        let skin = SkinItem(
            id: "3069960-3",
            seq: 3,
            name: "粉裙",
            pic: "https://x/3.png",
            categId: "3",
            seqNo: "NO.3",
            unlockedDate: "2025-11-20",
            userCount: 12345,
            isUnlocked: true,
            stateText: "已解锁",
            unlockTask: "",
            bgColor: "#FAFAFA"
        )
        let data = try JSONEncoder().encode([skin])
        let back = try JSONDecoder().decode([SkinItem].self, from: data)
        XCTAssertEqual(back, [skin])
    }

    func testSkinCacheOnlyKeepsSkinsWithPicture() throws {
        let name = "blanktabview.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = AppStore(defaults: defaults)

        store.saveSkinCache(
            "3069960",
            skins: [
                SkinItem(id: "3069960-1", seq: 1, name: "无皮肤"),
                SkinItem(id: "3069960-2", seq: 2, name: "有皮肤", pic: "https://x/2.png"),
                SkinItem(id: "3069960-5", seq: 5, name: "有皮肤5", pic: "https://x/5.png")
            ]
        )

        XCTAssertEqual(store.skinCache("3069960").map(\.seq), [2, 5])
        XCTAssertTrue(store.skinCache("unknown").isEmpty)
    }

    func testModuleItemsParseCards() {
        let payload: [String: Any] = [
            "CardList": [
                [
                    "Name": "废书欣",
                    "MedalID": "3069960",
                    "PicURL": "https://x/p.png",
                    "Scheme": "https://i2.y.qq.com/x?medal_id=3069960",
                    "Level": 3
                ]
            ],
            "HasNext": true
        ]

        let items = QqMedalExtra.parseItems(payload)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.name, "废书欣")
        XCTAssertEqual(items.first?.medalId, "3069960")
        XCTAssertTrue(items.first?.unlocked == true)
    }

    func testModuleItemsFallbackToMedalList() {
        let payload: [String: Any] = [
            "MedalList": [
                ["Name": "", "MedalID": "8"]
            ]
        ]
        let items = QqMedalExtra.parseItems(payload)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.name, "未命名")
        XCTAssertFalse(items.first?.unlocked ?? true)
    }

    func testDayLabelsProducesSevenEntries() {
        let labels = DayLabels.recent7
        XCTAssertEqual(labels.count, 7)
        XCTAssertTrue(labels.allSatisfy { $0.contains("/") })
    }
}
