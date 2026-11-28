import Foundation

/// QQ 音乐勋章相关接口的封装：签名与 SSR 解析都在客户端完成。
/// 家族成员等在本文件，排行榜在 `QqApi+Rank.swift`，勋章详情与皮肤在 `QqApi+MedalSkin.swift`。
final class QqApi: @unchecked Sendable {
    static let apiURL = "https://u6.y.qq.com/cgi-bin/musics.fcg"
    static let skinBase = "https://i2.y.qq.com/n3/medal_collection/pages/medal_collection_v3"

    let http: QqHttp
    var skinCache: [String: (expire: Date, list: SkinShowList)] = [:]

    init(http: QqHttp = QqHttp()) {
        self.http = http
    }

    // MARK: - 解析辅助

    static func map(_ value: Any?) -> [String: Any] { value as? [String: Any] ?? [:] }

    static func list(_ value: Any?) -> [[String: Any]] {
        guard let items = value as? [Any] else { return [] }
        return items.compactMap { $0 as? [String: Any] }
    }

    static func str(_ value: Any?) -> String {
        if let text = value as? String { return text }
        guard let value else { return "" }
        return String(describing: value)
    }

    static func int(_ value: Any?) -> Int {
        if let number = value as? NSNumber { return number.intValue }
        if let number = value as? Int { return number }
        if let text = value as? String {
            return Int(text.filter { $0.isNumber || $0 == "-" }) ?? 0
        }
        return 0
    }

    // MARK: - 底层 CGI

    func cgi(_ key: String, _ param: [String: Any], _ module: String, _ method: String) async throws -> [String: Any] {
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

    /// 从 HTML 中提取 window.__ssrFirstPageData__
    static func extractSsr(_ html: String) -> [String: Any]? {
        let pattern = "window\\.__ssrFirstPageData__\\s*=\\s*\"((?:[^\"\\\\]|\\\\.)*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = html as NSString
        guard let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges > 1 else { return nil }
        var raw = ns.substring(with: match.range(at: 1))
        raw = raw.replacingOccurrences(of: "\\\"", with: "\"")
        raw = raw.replacingOccurrences(of: "\\\\", with: "\\")
        raw = raw.replacingOccurrences(of: "\\u002F", with: "/")
        raw = raw.replacingOccurrences(of: "\\u0026", with: "&")
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return object as? [String: Any]
    }

    func ssrOf(_ url: String) async throws -> [String: Any]? {
        let html = try await http.getText(url)
        return Self.extractSsr(html)
    }

    /// 从勋章馆 / 皮肤页的 SSR 里拿 enc_uin。
    private func encUinOf(_ url: String) async -> String {
        guard let ssr = try? await ssrOf(url) else { return "" }
        let data = Self.map(ssr["data"])
        let fromData = Self.str(data["EncUin"])
        if !fromData.isEmpty { return fromData }
        return Self.str(Self.map(ssr["query"])["enc_uin"])
    }

    // MARK: - 家族成员

    func fetchFamilyMembers(_ familyId: String) async throws -> [Member] {
        let normalized = String(familyId.split(separator: "#").first ?? "")
        let medalId = String(normalized.split(separator: "_").first ?? "")

        let req = try await cgi(
            "GetRankTabDetail",
            ["MedalID": medalId, "TabID": 5, "FirstPageSize": 20, "From": 2, "Target": normalized],
            "music.medalHall.MedalRankListSrv",
            "GetRankTabDetail"
        )

        let code = Self.int(req["code"])
        if code != 0 {
            let message = Self.str(req["msg"])
            throw ApiError(message.isEmpty ? "成员数据获取失败（code=\(code)）" : message, code: code)
        }

        let data = Self.map(req["data"])
        let nested = Self.map(data["Detail"])
        let detail = nested.isEmpty ? data : nested
        let firstPage = Self.list(detail["FirstPageInfo"])
        let itemList = Self.list(detail["ItemList"])

        var members: [Member] = []
        var seen: Set<String> = []
        for item in firstPage {
            members.append(parseMember(item))
            let id = Self.str(item["ItemID"])
            if !id.isEmpty { seen.insert(id) }
        }

        let remaining: [[String: Any]] = itemList.filter { item in
            let id = Self.str(item["ItemID"])
            return !seen.contains(id)
        }

        if !remaining.isEmpty {
            let batch = try await cgi(
                "BatchGetRankItem",
                ["MedalID": medalId, "TabID": 5, "Items": remaining],
                "music.medalHall.MedalRankListSrv",
                "BatchGetRankItem"
            )
            let itemMap = Self.map(Self.map(batch["data"])["ItemMap"])
            // 按 ItemList 顺序补全，避免服务端 map 顺序导致成员乱序
            for item in remaining {
                let id = Self.str(item["ItemID"])
                if let raw = itemMap[id] as? [String: Any] {
                    members.append(parseMember(raw))
                }
            }
        }

        return members
    }

    private func parseMember(_ item: [String: Any]) -> Member {
        var medal = ""
        var fanBadge = ""
        var artistName = ""
        let rawTitle = Self.str(item["Title"])
        let title = rawTitle.isEmpty ? "未知" : rawTitle

        for wear in Self.list(item["WearList"]) {
            let wearTitle = Self.str(wear["Title"])
            if wearTitle.contains("V"), let range = wearTitle.range(of: "V\\d+", options: .regularExpression) {
                medal = String(wearTitle[range])
                let prefix = String(wearTitle[wearTitle.startIndex..<range.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !prefix.isEmpty && artistName.isEmpty { artistName = prefix }
            }
            let segment = Self.map(wear["Segment"])
            for content in Self.list(segment["Contents"]) {
                let text = Self.str(content["Content"])
                if text.hasPrefix("NO.") { fanBadge = text }
            }
        }

        var honor = ""
        for desc in Self.list(item["DescList"]) {
            let text = Self.str(desc["Desc"])
            if text.contains("荣誉值"), let range = text.range(of: "[0-9]+", options: .regularExpression) {
                honor = String(text[range])
            }
        }

        return Member(
            itemId: Self.str(item["ItemID"]),
            title: title,
            pic: Self.str(item["Pic"]).replacingOccurrences(of: "http://", with: "https://"),
            medal: medal,
            fanBadge: fanBadge,
            honor: honor,
            artistName: artistName
        )
    }

    // MARK: - 勋章馆首页

    func parseMedalHall(_ url: String, onlyInitial: Bool = false) async throws -> MedalHallPage {
        guard let ssr = try await ssrOf(url) else {
            throw ApiError("解析失败：页面数据结构无法识别")
        }

        let data = Self.map(ssr["data"])
        var encUin = Self.str(data["EncUin"])
        if encUin.isEmpty { encUin = Self.str(Self.map(ssr["query"])["enc_uin"]) }

        let tabs = Self.list(data["TabList"]).map { tab -> MedalTab in
            let id = Self.int(tab["ID"])
            return MedalTab(name: Self.str(tab["Name"]), type: id, id: id)
        }
        let currentTabId = Self.int(data["CurrTabID"])
        let rawDesc = Self.str(data["Desc"])
        let desc = rawDesc.isEmpty ? "--" : rawDesc

        var results = tabs.map { tab -> ModuleTabResult in
            if tab.id == currentTabId {
                return ModuleTabResult(
                    tab: tab,
                    success: true,
                    modules: parseModules(Self.map(data["TabInfo"])["ModuleList"]),
                    fromSsr: true
                )
            }
            return ModuleTabResult(tab: tab, loading: onlyInitial)
        }

        if !onlyInitial {
            for (index, tab) in tabs.enumerated() where tab.id != currentTabId {
                results[index] = await fetchHallTab(encUin: encUin, tab: tab)
            }
            _ = results // 先逐个补齐，避免无上限并发压垮上游
        }

        return MedalHallPage(
            encUin: encUin,
            desc: desc,
            tabs: tabs,
            results: results,
            currentTabId: currentTabId
        )
    }

    /// 拉取单个 Tab 的模块数据。
    func fetchHallTab(encUin: String, tab: MedalTab) async -> ModuleTabResult {
        do {
            let req = try await cgi(
                "GetHomepageTabDetail",
                ["EncUin": encUin, "TabID": tab.id, "IsQueryTabDetail": true, "SupportCardStyle": true],
                "music.medalHall.MedalHallHomepageSrv",
                "GetHomepageTabDetail"
            )
            let ok = Self.int(req["code"]) == 0
            let message = Self.str(req["msg"])
            return ModuleTabResult(
                tab: tab,
                success: ok,
                error: ok ? "" : (message.isEmpty ? "code=\(Self.int(req["code"]))" : message),
                modules: parseModules(Self.map(Self.map(req["data"])["TabInfo"])["ModuleList"])
            )
        } catch {
            return ModuleTabResult(tab: tab, error: error.localizedDescription)
        }
    }

    /// 勋章卡解析：首页模块卡与模块分页共用这一套。
    static func parseItems(_ source: [[String: Any]]) -> [MedalItem] {
        source.map { item -> MedalItem in
            let name = str(item["Name"])
            return MedalItem(
                medalId: str(item["MedalID"]),
                name: name.isEmpty ? "未命名" : name,
                picUrl: str(item["PicURL"]),
                scheme: str(item["Scheme"]),
                level: int(item["Level"]),
                state: int(item["State"]),
                numberText: str(map(item["NumberInfo"])["Content"]),
                createTime: str(item["CreateTime"]),
                cornerTitle: str(map(item["Corner"])["Title"])
            )
        }
    }

    private func parseModules(_ raw: Any?) -> [MedalModule] {
        Self.list(raw).map { module -> MedalModule in
            let cards = Self.list(module["CardList"])
            let medals = Self.list(module["MedalList"])
            let moduleId = Self.str(module["ModuleID"])
            let moduleName = Self.str(module["ModuleName"])
            return MedalModule(
                moduleId: moduleId,
                moduleName: moduleName.isEmpty ? "模块 \(moduleId)" : moduleName,
                items: Self.parseItems(cards.isEmpty ? medals : cards)
            )
        }
    }

    // MARK: - 模块分页（「全部」页面）

    /// `GetModuleDetail`：接管模块分页的解析，和首页模块卡共用 `parseItems`。
    func fetchModule(
        url: String,
        moduleId: String,
        lastPos: String = "",
        pageSize: Int = 21
    ) async throws -> HallModulePage {
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
        let code = Self.int(req["code"])
        if code != 0 {
            let message = Self.str(req["msg"])
            throw ApiError(message.isEmpty ? "模块加载失败（code=\(code)）" : message, code: code)
        }
        let data = Self.map(req["data"])
        let cards = Self.list(data["CardList"])
        let medals = Self.list(data["MedalList"])
        return HallModulePage(
            module: MedalModule(moduleId: moduleId, moduleName: "", items: Self.parseItems(cards.isEmpty ? medals : cards)),
            hasNext: (data["HasNext"] as? Bool) ?? false,
            lastPos: Self.str(data["LastPos"])
        )
    }
}
