import XCTest
@testable import BlankTabView

// MARK: - 签名

final class QqSignTests: XCTestCase {
    func testKnownSignature() {
        let payload = #"{"comm":{},"req_0":{"module":"music.medalHall.MedalRankListSrv","method":"GetRankTabDetail","param":{"MedalID":"3069960","TabID":5,"FirstPageSize":20,"From":2,"Target":"12345"}}}"#
        XCTAssertEqual(
            QqSign.sign(payload),
            "zzc46df8d3a8hs6bnnja11wafoaauxebogyy85c03674"
        )
    }

    func testSignatureIsLowercaseAndPrefixed() {
        let sign = QqSign.sign("{\"a\":1}")
        XCTAssertTrue(sign.hasPrefix("zzc"))
        XCTAssertEqual(sign, sign.lowercased())
        XCTAssertFalse(sign.contains("+"))
        XCTAssertFalse(sign.contains("/"))
        XCTAssertFalse(sign.contains("="))
    }
}

// MARK: - 家族链接

final class FamilyURLTests: XCTestCase {
    func testNormalizeKeepsFullLink() throws {
        let url = try FamilyRepository.normalizeFamilyUrl("  https://c6.y.qq.com/base/fcgi-bin/u?__=oe67e7GaIegF\n")
        XCTAssertEqual(url, "https://c6.y.qq.com/base/fcgi-bin/u?__=oe67e7GaIegF")
        XCTAssertEqual(URL(string: url)?.host, "c6.y.qq.com")
    }

    func testNormalizeStripsZeroWidthCharacters() throws {
        let url = try FamilyRepository.normalizeFamilyUrl("\u{200B}https://i2.y.qq.com/?family_id=123456\u{200B}")
        XCTAssertEqual(url, "https://i2.y.qq.com/?family_id=123456")
    }

    func testNormalizeBareShortCode() throws {
        let url = try FamilyRepository.normalizeFamilyUrl("oe67e7GaIegF")
        XCTAssertEqual(url, "https://c6.y.qq.com/base/fcgi-bin/u?__=oe67e7GaIegF")
    }

    func testNormalizeRejectsEmpty() {
        XCTAssertThrowsError(try FamilyRepository.normalizeFamilyUrl("   \n"))
    }
}

// MARK: - 格式化

final class FmtTests: XCTestCase {
    func testThousands() {
        XCTAssertEqual(Fmt.thousands("1557"), "1,557")
        XCTAssertEqual(Fmt.thousands("960"), "960")
        XCTAssertEqual(Fmt.thousands("1,557"), "1,557")
        XCTAssertEqual(Fmt.thousands(""), "--")
        XCTAssertEqual(Fmt.thousands(nil), "--")
        XCTAssertEqual(Fmt.thousands("暂无"), "暂无")
        XCTAssertEqual(Fmt.thousands(1234567), "1,234,567")
    }

    func testParseNumber() {
        XCTAssertEqual(Fmt.parseNumber("1,557人"), 1557)
        XCTAssertEqual(Fmt.parseNumber(nil), 0)
        XCTAssertEqual(Fmt.parseNumber("960.5"), 960.5)
    }

    func testDateKeyAndCleanTabName() {
        XCTAssertEqual(Fmt.dateKey("2025年11月20日 12:30"), "2025年11月20日")
        XCTAssertEqual(Fmt.dateKey("2025-11-20 12:30"), "2025-11-20")
        XCTAssertEqual(Fmt.cleanTabName("周榜(3)"), "周榜")
        XCTAssertEqual(Fmt.cleanTabName("月榜 3"), "月榜")
        XCTAssertEqual(Fmt.cleanTabName("总榜"), "总榜")
    }

    func testParseHonorDate() {
        XCTAssertNotNil(Fmt.parseHonorDate("2025年11月20日 12:30"))
        XCTAssertNotNil(Fmt.parseHonorDate("2025-11-20 12:30"))
        XCTAssertNil(Fmt.parseHonorDate("不是日期"))
    }
}

// MARK: - SSR 解析

final class SsrTests: XCTestCase {
    func testExtractSsrPayload() {
        let html = #"<script>window.__ssrFirstPageData__ = "{\"data\":{\"Name\":\"石榴裙\",\"family_id\":\"123456\"}}";</script>"#
        let ssr = QqApi.extractSsr(html)
        XCTAssertEqual(QqApi.str(QqApi.map(ssr?["data"])["Name"]), "石榴裙")
        XCTAssertEqual(QqApi.str(QqApi.map(ssr?["data"])["family_id"]), "123456")
    }

    func testExtractSsrMissing() {
        XCTAssertNil(QqApi.extractSsr("<html><body>nothing</body></html>"))
    }
}

// MARK: - 模型

final class MemberModelTests: XCTestCase {
    func testMedalTextJoinsArtistAndLevel() {
        let member = Member(itemId: "1", title: "星欣", medal: "V141", artistName: "虞书欣")
        XCTAssertEqual(member.medalText, "虞书欣V141")
    }

    func testMedalTextKeepsExistingArtist() {
        let member = Member(itemId: "1", title: "星欣", medal: "虞书欣V141", artistName: "虞书欣")
        XCTAssertEqual(member.medalText, "虞书欣V141")
    }

    func testMedalTextEmpty() {
        XCTAssertEqual(Member(itemId: "1", title: "星欣").medalText, "")
    }

    func testMetricsDisplayFallbacks() {
        let metrics = MemberMetrics(member: Member(itemId: "1", title: "星欣"))
        XCTAssertEqual(metrics.displayWeekRank, "--")
        XCTAssertEqual(metrics.displayMonthRank, "--")
        XCTAssertEqual(metrics.displaySkinCount, "--")
        XCTAssertFalse(metrics.hasSkinMedal)
    }

    func testFanPercentIsClamped() {
        let fan = FanMedal(name: "乐迷", current: 120, upper: 100)
        XCTAssertEqual(fan.percent, 1)
        XCTAssertTrue(fan.hasProgress)
        XCTAssertFalse(FanMedal().hasProgress)
    }
}

// MARK: - 荣誉

final class HonorRepositoryTests: XCTestCase {
    private func makeStore() -> AppStore {
        let name = "blank-tabview-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return AppStore(defaults: defaults)
    }

    func testGroupSortsByDayAndSums() {
        let store = makeStore()
        let repo = HonorRepository(store: store)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年MM月dd日 "

        let todayText = "\(formatter.string(from: today))12:30"
        let yesterdayText = "\(formatter.string(from: calendar.date(byAdding: .day, value: -1, to: today)!))09:10"

        repo.save([
            HonorRecord(id: "", taskName: "任务A", date: todayText, value: "10"),
            HonorRecord(id: "", taskName: "任务B", date: todayText, value: "5"),
            HonorRecord(id: "", taskName: "任务C", date: yesterdayText, value: "7")
        ], memberName: "星欣")

        let groups = repo.groupsOf("星欣")
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups.first?.total, 15)
        XCTAssertEqual(groups.first?.records.count, 2)

        let totals = repo.dailyTotals("星欣")
        XCTAssertEqual(totals.values.count, 7)
        XCTAssertEqual(totals.values.last, 15)
        XCTAssertEqual(totals.values[5], 7)
        XCTAssertTrue(totals.hasData)
    }

    func testFamilyDailyTotalsSumsMembers() {
        let store = makeStore()
        let repo = HonorRepository(store: store)
        repo.save([HonorRecord(id: "", taskName: "任务", date: "2025-01-01 10:00", value: "3")], memberName: "A")
        repo.save([HonorRecord(id: "", taskName: "任务", date: "2025-01-01 10:00", value: "4")], memberName: "B")
        let totals = repo.familyDailyTotals(["A", "B"], days: 7, now: Date())
        XCTAssertEqual(totals.values.reduce(0, +), 0)
    }

    func testSaveDeduplicates() {
        let store = makeStore()
        let repo = HonorRepository(store: store)
        let record = HonorRecord(id: "", taskName: "任务", date: "2025年01月01日 10:00", value: "3")
        repo.save([record], memberName: "星欣")
        repo.save([record], memberName: "星欣")
        XCTAssertEqual(repo.recordsOf("星欣").count, 1)
    }
}
