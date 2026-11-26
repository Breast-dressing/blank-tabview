import Foundation

/// 「限定编号」补充解析。
///
/// 编号挂在 `GetMedalDetail` 返回数据里的 `MedalList[*].NumberInfo.Content`
/// （node 项目 `/api/medal` 只是把同一份 `req_0.data` 原样转发，字段就在这一层）。
/// 分级解析不在这里重写：直接复用 `QqApi.extractLevels`，本文件只负责取编号。
struct MedalDetailNumbers: Sendable {
    var levels: [MedalLevel] = []
    /// 按实例勋章 ID 记录编号（同一枚勋章不同分级各有自己的编号）。
    var byMedalId: [String: String] = [:]
    /// 顶层共享编号（部分勋章只给一个总编号）。
    var shared: String = ""

    static func clean(_ raw: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty || text == "NO.----" || text == "--" { return "" }
        return text
    }

    func number(for medalId: String) -> String {
        let hit = Self.clean(byMedalId[medalId] ?? "")
        if !hit.isEmpty { return hit }
        return Self.clean(shared)
    }
}

extension QqApi {
    /// 一次请求同时拿到「分级列表 + 限定编号」，避免弹窗为了编号再多打一次接口。
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
        var result = MedalDetailNumbers()
        result.levels = extractLevels(data)
        result.shared = Self.numberText(of: data)

        let lists = [
            Self.list(Self.map(data["OldMedalDetail"])["MedalList"]),
            Self.list(Self.map(data["FanMedalDetail"])["MedalList"]),
            Self.list(data["MedalList"])
        ]
        for list in lists where !list.isEmpty {
            for item in list {
                let id = Self.str(item["MedalID"])
                let number = Self.numberText(of: item)
                if !id.isEmpty && !number.isEmpty { result.byMedalId[id] = number }
            }
            break
        }
        return result
    }

    /// 编号字段兜底顺序：NumberInfo.Content → Number / SerialNumber → Corner.Content → Corner.Title 里的 NO.x。
    static func numberText(of item: [String: Any]) -> String {
        let info = map(item["NumberInfo"])
        let direct = str(info["Content"])
        if !MedalDetailNumbers.clean(direct).isEmpty { return MedalDetailNumbers.clean(direct) }

        for key in ["Number", "SerialNumber", "SerialNo", "No"] {
            let value = str(item[key])
            if !MedalDetailNumbers.clean(value).isEmpty { return MedalDetailNumbers.clean(value) }
        }

        let corner = map(item["Corner"])
        let cornerContent = str(corner["Content"])
        if !MedalDetailNumbers.clean(cornerContent).isEmpty { return MedalDetailNumbers.clean(cornerContent) }
        let cornerTitle = str(corner["Title"])
        if cornerTitle.hasPrefix("NO.") { return MedalDetailNumbers.clean(cornerTitle) }
        return ""
    }
}
