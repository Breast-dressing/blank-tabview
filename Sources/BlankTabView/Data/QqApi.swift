import Foundation

/// QQ 音乐勋章相关接口的封装：签名与 SSR 解析都在客户端完成。
/// 家族成员、勋章馆（分类 + 模块分页）、排行榜、勋章详情、皮肤序列全部在这里解析，
/// UI / 仓库层不再重复实现任何解析逻辑。
final class QqApi: @unchecked Sendable {
    static let apiURL = "https://u6.y.qq.com/cgi-bin/musics.fcg"
    private static let skinBase = "https://i2.y.qq.com/n3/medal_collection/pages/medal_collection_v3"

    private let http: QqHttp
    private var skinCache: [String: (expire: Date, list: SkinShowList)] = [:]

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

    private func ssrOf(_ url: String) async throws -> [String: Any]? {
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

        let remaining: [[String: Any]] = itemList.filter { !seen.contains(Self.str($0["ItemID"])) }

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

    // MARK: - 排行榜

    struct StarDetailParams: Sendable {
        var medalId: String = ""
        var encUin: String = ""
        var level: String = ""
    }

    func parseStarDetailURL(_ url: String) -> StarDetailParams {
        guard let components = URLComponents(string: url) else { return StarDetailParams() }
        let items = components.queryItems ?? []
        func value(_ name: String) -> String {
            items.first { $0.name == name }?.value ?? ""
        }
        return StarDetailParams(medalId: value("medal_id"), encUin: value("enc_uin"), level: value("level"))
    }

    func parseRankPage(_ url: String) async throws -> RankPageData {
        let params = parseStarDetailURL(url)

        let moduleReq = try await cgi(
            "GetRankModule",
            ["MedalID": params.medalId, "FirstPageSize": 20, "From": 1, "Target": params.encUin],
            "music.medalHall.MedalRankListSrv",
            "GetRankModule"
        )

        let data = Self.map(moduleReq["data"])
        var tabs: [MedalTab] = []
        for group in Self.list(data["GroupList"]) {
            let groupName = Self.str(group["Name"])
            for tab in Self.list(group["Tabs"]) {
                let type = Self.int(tab["Type"])
                let firstShow = (tab["FirstShow"] as? Bool) ?? false
                tabs.append(MedalTab(name: Self.str(tab["Name"]), type: type, id: type, firstShow: firstShow, groupName: groupName))
            }
        }

        let firstTabDetail = Self.map(data["FirstTabDetail"])
        let firstTabId = Self.int(firstTabDetail["TabID"])
        let activeIndex = tabs.firstIndex { $0.type == firstTabId } ?? 0

        var results = tabs.map { RankTabResult(tab: $0) }
        if let index = tabs.firstIndex(where: { $0.type == firstTabId }), !firstTabDetail.isEmpty {
            results[index] = RankTabResult(
                tab: tabs[index],
                success: true,
                detail: try await enrichRankDetail(medalId: params.medalId, tabType: tabs[index].type, detail: firstTabDetail)
            )
        }

        return RankPageData(
            tabs: tabs,
            results: results,
            activeIndex: tabs.isEmpty ? 0 : activeIndex,
            artistName: "",
            medalId: params.medalId,
            encUin: params.encUin
        )
    }

    func fetchRankTab(url: String, tab: MedalTab) async throws -> RankDetail {
        let params = parseStarDetailURL(url)
        let req = try await cgi(
            "GetRankTabDetail",
            ["MedalID": params.medalId, "TabID": tab.type, "FirstPageSize": 20, "From": 1, "Target": params.encUin],
            "music.medalHall.MedalRankListSrv",
            "GetRankTabDetail"
        )
        let code = Self.int(req["code"])
        if code != 0 {
            let message = Self.str(req["msg"])
            throw ApiError(message.isEmpty ? "排行榜加载失败（code=\(code)）" : message, code: code)
        }
        let data = Self.map(req["data"])
        let nested = Self.map(data["Detail"])
        let detail = nested.isEmpty ? data : nested
        return try await enrichRankDetail(medalId: params.medalId, tabType: tab.type, detail: detail)
    }

    /// 首屏只带 ItemList（无头像/昵称/铭牌），用 BatchGetRankItem 批量补全。
    private func enrichRankDetail(medalId: String, tabType: Int, detail: [String: Any]) async throws -> RankDetail {
        let firstPage = Self.list(detail["FirstPageInfo"])
        let itemList = Self.list(detail["ItemList"])
        let banner = Self.map(detail["Banner"])
        let fixed = Self.map(detail["FixedInfo"])
        let empty = Self.map(detail["EmptyInfo"])

        var itemMap: [String: [String: Any]] = [:]
        for item in firstPage {
            let id = Self.str(item["ItemID"])
            if !id.isEmpty { itemMap[id] = item }
        }

        // 与 node server.js 一致：把 ItemList 的原始条目整体回传，服务端按 ItemID
        // 回填昵称、头像、勋章铭牌（WearList）与贡献（DescList）。
        let toFetch: [[String: Any]] = itemList.filter { item in
            let id = Self.str(item["ItemID"])
            return !id.isEmpty && itemMap[id] == nil
        }

        let batchSize = 20
        var start = 0
        while start < toFetch.count {
            let end = Swift.min(start + batchSize, toFetch.count)
            let batch = Array(toFetch[start..<end])
            start = end
            if let req = try? await cgi(
                "BatchGetRankItem",
                ["MedalID": medalId, "TabID": tabType, "Items": batch],
                "music.medalHall.MedalRankListSrv",
                "BatchGetRankItem"
            ) {
                let map = Self.map(Self.map(req["data"])["ItemMap"])
                for (key, value) in map {
                    if let raw = value as? [String: Any] { itemMap[key] = raw }
                }
            }
        }

        let source = itemList.isEmpty ? firstPage : itemList
        var members: [RankMember] = []
        for (index, item) in source.enumerated() {
            let id = Self.str(item["ItemID"])
            var merged = item
            if let extra = itemMap[id] {
                for (key, value) in extra { merged[key] = value }
            }
            if merged.isEmpty { continue }
            members.append(parseRankMember(merged, fallbackPosition: index + 1))
        }

        return RankDetail(
            fixedTitle: Self.str(fixed["Title"]),
            emptyText: Self.str(empty["Text"]),
            bannerUrl: Self.str(banner["Url"]),
            bannerTitle: Self.str(banner["Title"]),
            bannerBtnText: Self.str(banner["BtnText"]),
            items: members
        )
    }

    private func parseRankMember(_ item: [String: Any], fallbackPosition: Int) -> RankMember {
        var wear: [String] = []
        for entry in Self.list(item["WearList"]) {
            let contents = Self.list(Self.map(entry["Segment"])["Contents"])
                .map { Self.str($0["Content"]) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !contents.isEmpty { wear.append(contents) }
        }
        let desc = Self.list(item["DescList"]).map { Self.str($0["Desc"]) }.filter { !$0.isEmpty }

        let rawPosition = Self.int(item["Position"])
        var title = Self.str(item["Title"])
        if title.isEmpty { title = Self.str(item["Nick"]) }
        if title.isEmpty { title = Self.str(item["Name"]) }
        if title.isEmpty { title = "未知成员" }

        var pic = Self.str(item["Pic"])
        if pic.isEmpty { pic = Self.str(item["PicURL"]) }
        if pic.isEmpty { pic = Self.str(item["Avatar"]) }
        if pic.isEmpty { pic = Self.str(item["HeadPic"]) }

        return RankMember(
            position: rawPosition > 0 ? rawPosition : fallbackPosition,
            title: title,
            pic: pic,
            itemId: Self.str(item["ItemID"]),
            wearTexts: wear,
            descTexts: desc,
            praiseNum: Self.int(item["PraiseNum"]),
            isPraised: (item["IsPraised"] as? Bool) ?? false
        )
    }

    // MARK: - 勋章详情

    func fetchMedalDetail(url: String, medalId: String, encUin: String = "") async throws -> MedalDetail {
        var uin = encUin
        if uin.isEmpty, let ssr = try? await ssrOf(url) {
            let data = Self.map(ssr["data"])
            uin = Self.str(data["EncUin"])
            if uin.isEmpty { uin = Self.str(Self.map(ssr["query"])["enc_uin"]) }
        }

        let req = try await cgi(
            "GetMedalDetail",
            ["MedalID": medalId, "EncUin": uin],
            "music.medalHall.MedalHallHomepageSrv",
            "GetMedalDetail"
        )
        let code = Self.int(req["code"])
        if code != 0 {
            let message = Self.str(req["msg"])
            throw ApiError(message.isEmpty ? "勋章详情加载失败（code=\(code)）" : message, code: code)
        }
        let data = Self.map(req["data"])
        let resolvedId = Self.str(data["MedalID"])
        return MedalDetail(
            medalId: resolvedId.isEmpty ? medalId : resolvedId,
            scheme: Self.str(data["Scheme"]),
            levels: extractLevels(data),
            fan: parseFan(data)
        )
    }

    func extractLevels(_ data: [String: Any]) -> [MedalLevel] {
        let candidates = [
            Self.list(Self.map(data["OldMedalDetail"])["MedalList"]),
            Self.list(Self.map(data["FanMedalDetail"])["MedalList"]),
            Self.list(data["MedalList"])
        ]
        for list in candidates where !list.isEmpty {
            return list.map { item in
                let name = Self.str(item["Name"])
                return MedalLevel(
                    level: Self.int(item["Level"]),
                    state: Self.int(item["State"]),
                    name: name.isEmpty ? "未命名" : name,
                    picUrl: Self.str(item["PicURL"]),
                    medalId: Self.str(item["MedalID"]),
                    createTime: Self.str(item["CreateTime"])
                )
            }
        }

        let center = Self.list(Self.map(Self.map(data["FanMedalDetail"])["Center"])["ItemList"])
        if !center.isEmpty {
            return center.map { item in
                let section = Self.map(item["Section"])
                let corner = Self.map(item["Corner"])
                let sectionText = Self.str(section["Section"])
                let level = Int(sectionText.replacingOccurrences(of: "^", with: "", options: .regularExpression))
                    ?? Int(sectionText.replacingOccurrences(of: "V", with: ""))
                    ?? 0
                let owned = Self.str(corner["Desc"]) == "获得"
                return MedalLevel(
                    level: level,
                    state: owned ? 2 : 1,
                    name: Self.str(section["Alias"]),
                    picUrl: Self.str(section["PicURL"]),
                    medalId: "center_\(sectionText)",
                    createTime: owned ? Self.str(corner["Title"]) : "",
                    sectionText: sectionText,
                    isCenter: true
                )
            }
        }
        return []
    }

    func parseFan(_ data: [String: Any]) -> FanMedal? {
        let fan = Self.map(data["FanMedalDetail"])
        if fan.isEmpty { return nil }
        let section = Self.map(fan["Section"])
        let corner = Self.map(fan["Corner"])
        let proportion = Self.map(fan["Proportion"])
        return FanMedal(
            name: Self.str(fan["Name"]),
            pic: Self.str(fan["PicURL"]),
            levelText: Self.str(section["Section"]),
            alias: Self.str(section["Alias"]),
            rankTitle: Self.str(corner["Title"]),
            rankDesc: Self.str(corner["Desc"]),
            current: Self.int(proportion["Current"]),
            upper: Self.int(proportion["UpperLimit"])
        )
    }

    // MARK: - 皮肤

    func fetchSkinShowList(medalId: String, encUin: String = "", cursor: String = "", pageSize: Int = 4) async throws -> SkinShowList {
        let req = try await cgi(
            "GetSkinShowList",
            ["MedalID": medalId, "ShowPos": 1, "PageSize": pageSize, "Cursor": cursor, "EncUin": encUin],
            "music.medalSkin.MedalSkinHomepageSrv",
            "GetSkinShowList"
        )

        let data = Self.map(req["data"])
        let hasPayload = Self.int(data["SkinTotal"]) > 0
            || !Self.list(data["SkinList"]).isEmpty
            || !Self.str(data["MedalName"]).isEmpty
        let code = Self.int(req["code"])
        if code != 0 && !hasPayload {
            let message = Self.str(req["msg"])
            throw ApiError(message.isEmpty ? "皮肤数据获取失败（code=\(code)）" : message, code: code)
        }

        return SkinShowList(
            total: Self.int(data["SkinTotal"]),
            skins: Self.list(data["SkinList"]).map(parseSkinShowItem),
            medalName: Self.str(data["MedalName"]),
            hasMore: (data["HasMore"] as? Bool) ?? false,
            nextCursor: Self.str(data["NextCursor"])
        )
    }

    private func parseSkinShowItem(_ skin: [String: Any]) -> SkinItem {
        let unlockedTs = Self.int(skin["UnlockedTs"])
        let name = Self.str(skin["Name"])
        return SkinItem(
            id: Self.str(skin["ID"]),
            seq: Self.int(skin["Seq"]),
            name: name.isEmpty ? "无皮肤" : name,
            pic: Self.str(skin["Pic"]),
            categId: Self.str(skin["CategID"]),
            seqNo: Self.str(skin["SeqNo"]),
            userCount: Self.int(skin["UnlockedUserCnt"]),
            isUnlocked: unlockedTs > 0,
            stateText: unlockedTs > 0 ? "已解锁" : "未解锁"
        )
    }

    /// 只取「总数 + 首屏列表」，成员详情走这里（5 分钟缓存 + 同 key 去重）。
    func fetchSkinTotal(medalId: String, encUin: String) async throws -> SkinShowList {
        let key = "\(medalId)::\(encUin)"
        if let cached = skinCache[key], cached.expire > Date() {
            return cached.list
        }
        let list = try await fetchSkinShowList(medalId: medalId, encUin: encUin)
        skinCache[key] = (Date().addingTimeInterval(300), list)
        return list
    }

    /// 按 seq 批量抓皮肤详情页：每批最多 20 并发，解析与详情页共用 `fetchSingleSkin`。
    func fetchSkinSeqs(uin: String, seqs: [Int], medalId: String) async -> [SkinItem] {
        guard !seqs.isEmpty else { return [] }
        var items: [SkinItem] = []
        var index = 0
        while index < seqs.count {
            let end = Swift.min(index + 20, seqs.count)
            let chunk = Array(seqs[index..<end])
            index = end
            await withTaskGroup(of: SkinItem?.self) { group in
                for seq in chunk {
                    group.addTask { [self] in
                        await fetchSingleSkin(medalId: medalId, seq: seq, uin: uin)
                    }
                }
                for await result in group {
                    if let result { items.append(result) }
                }
            }
        }
        return items
    }

    /// `skin_detail.html` 的 SSR → SkinItem；无图时返回 nil（不写入缓存）。
    func fetchSingleSkin(medalId: String, seq: Int, uin: String, retries: Int = 1) async -> SkinItem? {
        let targetId = "\(medalId)-\(seq)"
        let decoded = uin.removingPercentEncoding ?? uin
        let safeUin = decoded.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? decoded
        let url = "\(Self.skinBase)/skin_detail.html?_hidehd=1&_fontscale=1&skin_id=\(targetId)&enc_uin=\(safeUin)"

        do {
            let html = try await http.getText(url, timeout: 15)
            guard let ssr = Self.extractSsr(html), Self.int(ssr["code"]) == 0 else { return nil }
            let data = Self.map(ssr["data"])
            let info = Self.map(data["SkinInfo"])
            guard !info.isEmpty else { return nil }

            let levels = Self.list(info["LevelList"])
            let level = levels.first ?? [:]
            let pic = Self.str(level["Pic"])
            guard !pic.isEmpty else { return nil }

            let unlockedTs = Self.int(info["UnlockedTs"])
            let unlocked = Self.int(level["State"]) == 2 || unlockedTs > 0
            let tasks = Self.list(Self.map(level["LevelUnlockGuide"])["TaskList"])
            let unlockTask = tasks.isEmpty ? "" : Self.str(tasks[0]["Title"])
            let name = Self.str(info["Name"])

            return SkinItem(
                id: Self.str(info["ID"]).isEmpty ? targetId : Self.str(info["ID"]),
                seq: seq,
                name: name.isEmpty ? "(未命名)" : name,
                pic: pic,
                categId: Self.str(info["CategID"]),
                seqNo: Self.str(level["SeqNo"]),
                unlockedDate: unlockedTs > 0 ? Self.skinDate(unlockedTs) : "",
                userCount: Self.int(info["UnlockedUserCnt"]),
                isUnlocked: unlocked,
                stateText: unlocked ? "已解锁" : "未解锁",
                unlockTask: unlockTask,
                bgColor: Self.str(level["BGColor"]).isEmpty ? "#FAFAFA" : Self.str(level["BGColor"])
            )
        } catch {
            if retries > 0 {
                return await fetchSingleSkin(medalId: medalId, seq: seq, uin: uin, retries: retries - 1)
            }
            return nil
        }
    }

    private static func skinDate(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - 其他

    func fetchHtml(_ url: String) async throws -> String {
        try await http.getText(url)
    }

    func fetchImageBytes(_ url: String) async -> Data? {
        await http.getBytes(url)
    }
}
