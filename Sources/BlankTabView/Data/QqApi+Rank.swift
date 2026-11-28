import Foundation

// MARK: - 排行榜

/// 排行榜的解析、切榜拉取与「边解析边出结果」的增量回调。
extension QqApi {
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

    func fetchRankTab(
        url: String,
        tab: MedalTab,
        onPartial: (@MainActor @Sendable ([RankMember]) -> Void)? = nil
    ) async throws -> RankDetail {
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
        return try await enrichRankDetail(
            medalId: params.medalId,
            tabType: tab.type,
            detail: detail,
            onPartial: onPartial
        )
    }

    /// 首屏只带 ItemList（无头像/昵称/铭牌），用 BatchGetRankItem 批量补全；
    /// 每补一批就把「已解析到的那部分」交出去，界面边解析边显示。
    private func enrichRankDetail(
        medalId: String,
        tabType: Int,
        detail: [String: Any],
        onPartial: (@MainActor @Sendable ([RankMember]) -> Void)? = nil
    ) async throws -> RankDetail {
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

        let source = itemList.isEmpty ? firstPage : itemList

        func members(upTo limit: Int) -> [RankMember] {
            var result: [RankMember] = []
            for (index, item) in source.prefix(limit).enumerated() {
                let id = Self.str(item["ItemID"])
                var merged = item
                if let extra = itemMap[id] {
                    for (key, value) in extra { merged[key] = value }
                }
                if merged.isEmpty { continue }
                result.append(parseRankMember(merged, fallbackPosition: index + 1))
            }
            return result
        }

        func emit(upTo limit: Int) async {
            guard let onPartial else { return }
            let partial = members(upTo: limit)
            await MainActor.run { onPartial(partial) }
        }

        // 首屏自带的那些条目已经完整，先直接显示出来。
        if !firstPage.isEmpty {
            let firstPageIds = Set(firstPage.map { Self.str($0["ItemID"]) })
            let limit = source.lastIndex { firstPageIds.contains(Self.str($0["ItemID"])) }.map { $0 + 1 }
                ?? firstPage.count
            await emit(upTo: Swift.min(limit, source.count))
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
                var covered = start
                for (key, value) in map {
                    if let raw = value as? [String: Any] { itemMap[key] = raw }
                    if let index = source.firstIndex(where: { Self.str($0["ItemID"]) == key }) {
                        covered = Swift.max(covered, index + 1)
                    }
                }
                await emit(upTo: Swift.min(covered, source.count))
            }
        }

        return RankDetail(
            fixedTitle: Self.str(fixed["Title"]),
            emptyText: Self.str(empty["Text"]),
            bannerUrl: Self.str(banner["Url"]),
            bannerTitle: Self.str(banner["Title"]),
            bannerBtnText: Self.str(banner["BtnText"]),
            items: members(upTo: source.count)
        )
    }

    private func parseRankMember(_ item: [String: Any], fallbackPosition: Int) -> RankMember {
        var wear: [String] = []
        var honors: [String] = []
        for entry in Self.list(item["WearList"]) {
            // 铭牌：只取 WearList.Segment.Contents 里的限定编号（NO.xxxxx），其余 Content 全部丢弃。
            for content in Self.list(Self.map(entry["Segment"])["Contents"]) {
                let text = Self.str(content["Content"]).trimmingCharacters(in: .whitespacesAndNewlines)
                if text.hasPrefix("NO.") { wear.append(text) }
            }
            // 称号：直接取 WearList.Title，不做任何裁剪。
            let honor = Self.str(entry["Title"]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !honor.isEmpty { honors.append(honor) }
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
            honorTexts: honors,
            descTexts: desc,
            praiseNum: Self.int(item["PraiseNum"]),
            isPraised: (item["IsPraised"] as? Bool) ?? false
        )
    }
}
