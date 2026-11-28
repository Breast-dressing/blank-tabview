import Foundation

extension QqApi {
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
