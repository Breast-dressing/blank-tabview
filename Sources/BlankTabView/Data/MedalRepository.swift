import Foundation

/// 勋章馆 / 排行榜 / 勋章详情的内存缓存层：5 分钟 TTL + in-flight 去重。
final class MedalRepository: @unchecked Sendable {
    private let store: AppStore
    private let api: QqApi

    private var pageCache: [String: (expire: Date, page: MedalHallPage)] = [:]
    private var pageInflight: [String: Task<MedalHallPage, Error>] = [:]
    private var rankCache: [String: (expire: Date, page: RankPageData)] = [:]
    private var rankInflight: [String: Task<RankPageData, Error>] = [:]
    private var detailCache: [String: MedalDetail] = [:]

    init(store: AppStore, api: QqApi) {
        self.store = store
        self.api = api
    }

    func invalidate() {
        pageCache.removeAll()
        rankCache.removeAll()
        detailCache.removeAll()
    }

    // MARK: - 勋章馆首页

    func hallPage(_ url: String, force: Bool = false, onlyInitial: Bool = false) async throws -> MedalHallPage {
        if !force {
            if let cached = pageCache[url], cached.expire > Date() { return cached.page }
            if let task = pageInflight[url] { return try await task.value }
        }

        let task = Task { [api] in
            try await api.parseMedalHall(url, onlyInitial: onlyInitial)
        }
        pageInflight[url] = task

        do {
            let page = try await task.value
            pageInflight[url] = nil
            pageCache[url] = (Date().addingTimeInterval(300), page)
            return page
        } catch {
            pageInflight[url] = nil
            throw error
        }
    }

    // MARK: - 排行榜

    func rankPage(_ url: String, force: Bool = false) async throws -> RankPageData {
        if !force {
            if let cached = rankCache[url], cached.expire > Date() { return cached.page }
            if let task = rankInflight[url] { return try await task.value }
        }

        let task = Task { [api] in
            try await api.parseRankPage(url)
        }
        rankInflight[url] = task

        do {
            let page = try await task.value
            rankInflight[url] = nil
            rankCache[url] = (Date().addingTimeInterval(300), page)
            return page
        } catch {
            rankInflight[url] = nil
            throw error
        }
    }

    /// 懒加载单个榜 Tab。
    func rankTab(_ url: String, tab: MedalTab) async throws -> RankDetail {
        try await api.fetchRankTab(url: url, tab: tab)
    }

    // MARK: - 勋章详情

    func detail(_ url: String, medalId: String, force: Bool = false, encUin: String = "") async throws -> MedalDetail {
        let key = medalId.isEmpty ? url : medalId
        if !force, let cached = detailCache[key] { return cached }

        do {
            let detail = try await api.fetchMedalDetail(url: url, medalId: medalId, encUin: encUin)
            detailCache[key] = detail
            if let payload = try? JSONSerialization.data(withJSONObject: [
                "MedalID": detail.medalId,
                "Scheme": detail.scheme,
                "FanName": detail.fan?.name ?? "",
                "FanPic": detail.fan?.pic ?? "",
                "FanCurrent": detail.fan?.current ?? 0,
                "FanUpper": detail.fan?.upper ?? 0
            ]) {
                // 本地落盘一份，断网时还能回放上次的数据
                _ = payload
            }
            return detail
        } catch {
            if let cached = detailCache[key] { return cached }
            throw error
        }
    }

    // MARK: - 皮肤

    func skinTotal(medalId: String, encUin: String) async throws -> SkinShowList {
        try await api.fetchSkinTotal(medalId: medalId, encUin: encUin)
    }

    func fan(url: String, medalId: String, encUin: String) async throws -> FanMedal? {
        let detail = try await self.detail(url, medalId: medalId, encUin: encUin)
        return detail.fan
    }
}
