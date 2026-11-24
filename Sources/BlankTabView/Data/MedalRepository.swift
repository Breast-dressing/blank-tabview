import Foundation

/// 勋章馆 / 排行榜 / 勋章详情 / 皮肤序列的内存缓存层：5 分钟 TTL + in-flight 去重。
/// 解析全部交给 `QqApi`，这里只做缓存、并发编排与落盘。
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

        let apiRef = api
        let task = Task { try await apiRef.parseMedalHall(url, onlyInitial: onlyInitial) }
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

    /// 并行补齐所有未加载 Tab，每完成一个就回调，页面边拉边渲染。
    func ensureHallTabs(_ page: MedalHallPage, onUpdate: @escaping (MedalHallPage) -> Void) async {
        let pending = page.results.indices.filter { page.results[$0].loading && !page.results[$0].success }
        guard !pending.isEmpty else { return }
        let apiRef = api
        let uin = page.encUin

        await withTaskGroup(of: (Int, ModuleTabResult).self) { group in
            for index in pending {
                let tab = page.results[index].tab
                group.addTask {
                    (index, await apiRef.fetchHallTab(encUin: uin, tab: tab))
                }
            }
            for await (index, fresh) in group {
                guard page.results.indices.contains(index) else { continue }
                page.results[index] = fresh
                onUpdate(page)
            }
        }
    }

    /// 拉取单个 Tab 并写回页面缓存。
    func hallTab(_ page: MedalHallPage, index: Int) async -> ModuleTabResult {
        guard page.results.indices.contains(index) else {
            return ModuleTabResult(tab: MedalTab(name: "", type: 0, id: 0))
        }
        let fresh = await api.fetchHallTab(encUin: page.encUin, tab: page.results[index].tab)
        page.results[index] = fresh
        return fresh
    }

    // MARK: - 模块分页

    func modulePage(
        url: String,
        moduleId: String,
        moduleName: String,
        lastPos: String = "",
        pageSize: Int = 21
    ) async throws -> HallModulePage {
        let page = try await api.fetchModule(
            url: url,
            moduleId: moduleId,
            lastPos: lastPos,
            pageSize: pageSize
        )
        var module = page.module
        module.moduleName = moduleName.isEmpty ? "模块 \(moduleId)" : moduleName
        return HallModulePage(module: module, hasNext: page.hasNext, lastPos: page.lastPos)
    }

    // MARK: - 排行榜

    func rankPage(_ url: String, force: Bool = false) async throws -> RankPageData {
        if !force {
            if let cached = rankCache[url], cached.expire > Date() { return cached.page }
            if let task = rankInflight[url] { return try await task.value }
        }

        let apiRef = api
        let task = Task { try await apiRef.parseRankPage(url) }
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

    func cachedSkins(_ medalId: String) -> [SkinItem] {
        store.skinCache(medalId)
    }

    /// 渐进扫描：每扫完一批就回调最新列表，UI 无需等待全量。
    /// 20 个 seq 一批（外层 100 一档），连续 100 个空位就停止，最多扫到 2000。
    func scanSkins(
        medalId: String,
        uin: String,
        chunkSize: Int = 100,
        isActive: @escaping () -> Bool,
        onUpdate: @escaping ([SkinItem]) -> Void
    ) async {
        var currentSeq = 1
        var emptyStreak = 0
        var map: [Int: SkinItem] = [:]

        for skin in store.skinCache(medalId) {
            map[skin.seq] = skin
        }
        if !map.isEmpty { onUpdate(sortedSkins(map)) }

        let total = (try? await skinTotal(medalId: medalId, encUin: uin))?.total

        while isActive() {
            if emptyStreak >= 100 || currentSeq > 2000 { break }
            if let total, total > 0, map.count >= total { break }

            let seqs = (0..<chunkSize).map { currentSeq + $0 }
            let result = await api.fetchSkinSeqs(uin: uin, seqs: seqs, medalId: medalId)
            var hasSkin = false
            for skin in result {
                map[skin.seq] = skin
                if !skin.pic.isEmpty { hasSkin = true }
            }
            emptyStreak = hasSkin ? 0 : emptyStreak + chunkSize
            currentSeq += chunkSize

            let skins = sortedSkins(map)
            if !skins.isEmpty {
                onUpdate(skins)
                store.saveSkinCache(medalId, skins: skins)
            }
        }
        store.saveSkinCache(medalId, skins: sortedSkins(map))
    }

    private func sortedSkins(_ map: [Int: SkinItem]) -> [SkinItem] {
        map.values
            .filter { !$0.pic.isEmpty }
            .sorted { $0.seq < $1.seq }
    }
}
