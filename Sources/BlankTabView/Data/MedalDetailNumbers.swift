import Foundation

/// 「限量编号」：数据只有一处 —— `GetMedalDetail` 返回的
/// `OldMedalDetail.MedalList[*].NumberInfo.Content`（如 `NO.0025`，空值是 `NO.----`）。
/// node 项目的 `extractMedalLevels` → `normalizeMedalItem` 就是这么取的，index.html 也只读这一个字段。
/// 分级解析直接复用 `QqApi.extractLevels`，本文件只负责把编号按 MedalID 挂上去。
struct MedalDetailNumbers: Sendable {
    var levels: [MedalLevel] = []
    /// MedalID → 限量编号
    var byMedalId: [String: String] = [:]

    static func clean(_ raw: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty || text == "NO.----" { return "" }
        return text
    }

    func number(for medalId: String) -> String {
        Self.clean(byMedalId[medalId] ?? "")
    }
}

extension QqApi {
    /// 一次请求同时拿到「分级列表 + 限量编号」，弹窗不需要为编号再打第二次接口。
    func fetchMedalDetailNumbers(medalId: String, encUin: String) async throws -> MedalDetailNumbers {
        let param: [String: Any] = ["MedalID": medalId, "EncUin": encUin]
        let payload: [String: Any] = [
            "comm": [String: Any](),
            "req_0": [
                "module": "music.medalHall.MedalHallHomepageSrv",
                "method": "GetMedalDetail",
                "param": param
            ] as [String: Any]
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let body = String(data: bodyData, encoding: .utf8) else {
            throw ApiError("请求序列化失败")
        }
        let millis = Int(Date().timeIntervalSince1970 * 1000)
        let url = "\(Self.apiURL)?_webcgikey=GetMedalDetail&_=\(millis)&sign=\(QqSign.sign(body))"
        let decoded = try await QqHttp().postJSON(url, body: body)
        guard let dict = decoded as? [String: Any] else { throw ApiError("上游返回格式异常") }
        let req = dict["req_0"] as? [String: Any] ?? [:]
        let code = Self.int(req["code"])
        if code != 0 {
            let message = Self.str(req["msg"])
            throw ApiError(message.isEmpty ? "勋章详情加载失败（code=\(code)）" : message, code: code)
        }

        let data = Self.map(req["data"])
        var numbers: [String: String] = [:]
        for item in Self.list(Self.map(data["OldMedalDetail"])["MedalList"]) {
            let id = Self.str(item["MedalID"])
            let content = Self.str(Self.map(item["NumberInfo"])["Content"])
            let number = MedalDetailNumbers.clean(content)
            if !id.isEmpty && !number.isEmpty { numbers[id] = number }
        }
        return MedalDetailNumbers(levels: extractLevels(data), byMedalId: numbers)
    }
}
