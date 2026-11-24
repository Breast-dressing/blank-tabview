import Foundation

/// 模块分页与皮肤序列扫描（`GetModuleDetail` + `skin_detail.html`）。
/// 单独分包，避免把主页接口层再撑大。
final class QqMedalExtra: @unchecked Sendable {
    private static let apiURL = "https://u6.y.qq.com/cgi-bin/musics.fcg"
    private static let skinBase = "https://i2.y.qq.com/n3/medal_collection/pages/medal_collection_v3"

    private let http: QqHttp

    init(http: QqHttp = QqHttp()) {
        self.http = http
    }

    // MARK: - CGI

    private func cgi(_ key: String, _ param: [String: Any], _ module: String, _ method: String) async throws -> [String: Any] {
        let payload: [String: Any] = [
            "comm": [String: Any](),
            "req_0": ["module": module, "method": method, "param": param] as [String: Any]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let body = String(data: data, encoding: .utf8) else {
            throw ApiError("请求序列化失败")
        }
        let millis = Int(Date().timeIntervalSince1970 * 1000)
        let url = "\(Self.apiURL)?_webcgikey=\(key)&_=\(millis)&sign=\(QqSign.sign(body))"
        let decoded = try await http.postJSON(url, body: body)
        guard let dict = decoded as? [String: Any] else { throw ApiError("上游返回格式异常") }
        return dict["req_0"] as? [String: Any] ?? [:]
    }

    private func encUinOf(_ url: String) async -> String {
        guard let ssr = try? await http.getText(url),
              let parsed = QqApi.extractSsr(ssr) else { return "" }
        let data = QqApi.map(parsed["data"])
        let fromData = QqApi.str(data["EncUin"])
        if !fromData.isEmpty { return fromData }
        return QqApi.str(QqApi.map(parsed["query"])["enc_uin"])
    }

    // MARK: - 模块

    func fetchModule(url: String, moduleId: String, lastPos: String = "", pageSize: Int = 21) async throws -> [String: Any] {
        let encUin = await encUinOf(url)
        let numberId = Int(moduleId.filter { $0.isNumber }) ?? 0
        let req = try await cgi(
            "GetModuleDetail",
            [
                "ModuleID": numberId,
                "EncUin": encUin,
                "PageSize": pageSize,
                "LastPos": lastPos,
                "SupportCardStyle": true
            ],
            "music.medalHall.MedalHallHomepageSrv",
            "GetModuleDetail"
        )
        let code = QqApi.int(req["code"])
        if code != 0 {
            let message = QqApi.str(req["msg"])
            throw ApiError(message.isEmpty ? "模块加载失败（code=\(code)）" : message, code: code)
        }
        return QqApi.map(req["data"])
    }

    static func parseItems(_ data: [String: Any]) -> [MedalItem] {
        let cards = QqApi.list(data["CardList"])
        let medals = QqApi.list(data["MedalList"])
        let source = cards.isEmpty ? medals : cards
        return source.map { item in
            let name = QqApi.str(item["Name"])
            return MedalItem(
                medalId: QqApi.str(item["MedalID"]),
                name: name.isEmpty ? "未命名" : name,
                picUrl: QqApi.str(item["PicURL"]),
                scheme: QqApi.str(item["Scheme"]),
                level: QqApi.int(item["Level"]),
                state: QqApi.int(item["State"]),
                numberText: QqApi.str(QqApi.map(item["NumberInfo"])["Content"]),
                createTime: QqApi.str(item["CreateTime"]),
                cornerTitle: QqApi.str(QqApi.map(item["Corner"])["Title"])
            )
        }
    }

    // MARK: - 皮肤序列

    /// 按 seq 批量抓皮肤详情页，最多 20 并发。
    func fetchSkinSeqs(uin: String, seqs: [Int], medalId: String) async -> [SkinItem] {
        guard !seqs.isEmpty else { return [] }
        var items: [SkinItem] = []
        var cursor = 0
        let workers = Swift.min(seqs.count, 20)

        await withTaskGroup(of: SkinItem?.self) { group in
            func addNext() {
                guard cursor < seqs.count else { return }
                let seq = seqs[cursor]
                cursor += 1
                group.addTask { [self] in await fetchSingleSkin(medalId: medalId, seq: seq, uin: uin) }
            }

            for _ in 0..<workers { addNext() }
            for await result in group {
                if let result { items.append(result) }
                addNext()
            }
        }
        return items
    }

    func fetchSingleSkin(medalId: String, seq: Int, uin: String, retries: Int = 1) async -> SkinItem? {
        let targetId = "\(medalId)-\(seq)"
        let decoded = uin.removingPercentEncoding ?? uin
        let safeUin = decoded.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? decoded
        let url = "\(Self.skinBase)/skin_detail.html?_hidehd=1&_fontscale=1&skin_id=\(targetId)&enc_uin=\(safeUin)"

        do {
            let html = try await http.getText(url, timeout: 15)
            guard let ssr = QqApi.extractSsr(html), QqApi.int(ssr["code"]) == 0 else { return nil }
            let data = QqApi.map(ssr["data"])
            let info = QqApi.map(data["SkinInfo"])
            guard !info.isEmpty else { return nil }

            let levels = QqApi.list(info["LevelList"])
            let level = levels.first ?? [:]
            let pic = QqApi.str(level["Pic"])
            guard !pic.isEmpty else { return nil }

            let unlockedTs = QqApi.int(info["UnlockedTs"])
            let unlocked = QqApi.int(level["State"]) == 2 || unlockedTs > 0
            let tasks = QqApi.list(QqApi.map(level["LevelUnlockGuide"])["TaskList"])
            let unlockTask = tasks.isEmpty ? "" : QqApi.str(tasks[0]["Title"])
            let name = QqApi.str(info["Name"])

            return SkinItem(
                id: QqApi.str(info["ID"]).isEmpty ? targetId : QqApi.str(info["ID"]),
                seq: seq,
                name: name.isEmpty ? "(未命名)" : name,
                pic: pic,
                categId: QqApi.str(info["CategID"]),
                seqNo: QqApi.str(level["SeqNo"]),
                unlockedDate: unlockedTs > 0 ? Self.formatDate(unlockedTs) : "",
                userCount: QqApi.int(info["UnlockedUserCnt"]),
                isUnlocked: unlocked,
                stateText: unlocked ? "已解锁" : "未解锁",
                unlockTask: unlockTask,
                bgColor: QqApi.str(level["BGColor"]).isEmpty ? "#FAFAFA" : QqApi.str(level["BGColor"])
            )
        } catch {
            if retries > 0 {
                return await fetchSingleSkin(medalId: medalId, seq: seq, uin: uin, retries: retries - 1)
            }
            return nil
        }
    }

    private static func formatDate(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
