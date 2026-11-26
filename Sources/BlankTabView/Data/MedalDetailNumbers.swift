import Foundation

/// 「限定编号」补充解析。
///
/// 编号来自 `GetMedalDetail` 的原始 `req_0.data`（node 项目 `/api/medal` 原样转发的就是这份数据），
/// 落在 `MedalList[*].NumberInfo.Content` 一类的位置；不同勋章层级不完全一致，
/// 所以这里按「已知路径优先 + 全量深扫兜底」取值。
/// 分级解析不重写：直接复用 `QqApi.extractLevels`。
struct MedalDetailNumbers: Sendable {
    var levels: [MedalLevel] = []
    /// 按实例勋章 ID 记录编号（同一枚勋章不同分级各有各的编号）。
    var byMedalId: [String: String] = [:]
    /// 兜底编号（数据只给一个总编号时用）。
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
    /// 一次请求同时拿到「分级列表 + 限定编号」，弹窗不必为编号再打一次接口。
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

        // 已知路径都没命中时，把整份 data 深扫一遍，找任意 NumberInfo.Content。
        if result.shared.isEmpty && result.byMedalId.isEmpty {
            var found: [String: String] = [:]
            var fallback = ""
            Self.deepScanNumberInfo(data, medalId: medalId, found: &found, shared: &fallback)
            result.byMedalId = found
            result.shared = fallback
        }
        return result
    }

    /// 递归查找 `NumberInfo.Content`：带 MedalID 的记到对应勋章，其余作为兜底编号。
    static func deepScanNumberInfo(
        _ value: Any,
        medalId: String,
        found: inout [String: String],
        shared: inout String
    ) {
        if let dict = value as? [String: Any] {
            let ownId = str(dict["MedalID"]).isEmpty ? medalId : str(dict["MedalID"])
            let number = numberText(of: dict)
            if !number.isEmpty {
                if ownId.isEmpty {
                    if shared.isEmpty { shared = number }
                } else if found[ownId] == nil {
                    found[ownId] = number
                }
            }
            for (_, child) in dict {
                deepScanNumberInfo(child, medalId: ownId, found: &found, shared: &shared)
            }
            return
        }
        if let items = value as? [Any] {
            for child in items {
                deepScanNumberInfo(child, medalId: medalId, found: &found, shared: &shared)
            }
        }
    }

    /// 编号字段兜底顺序：NumberInfo.Content → Number / SerialNumber → Corner.Content → Corner.Title 里的 NO.x。
    static func numberText(of item: [String: Any]) -> String {
        let info = map(item["NumberInfo"])
        let direct = MedalDetailNumbers.clean(str(info["Content"]))
        if !direct.isEmpty { return direct }

        for key in ["Number", "SerialNumber", "SerialNo", "No"] {
            let value = MedalDetailNumbers.clean(str(item[key]))
            if !value.isEmpty { return value }
        }

        let corner = map(item["Corner"])
        let cornerContent = MedalDetailNumbers.clean(str(corner["Content"]))
        if !cornerContent.isEmpty { return cornerContent }
        let cornerTitle = str(corner["Title"])
        if cornerTitle.hasPrefix("NO.") { return MedalDetailNumbers.clean(cornerTitle) }
        return ""
    }
}
