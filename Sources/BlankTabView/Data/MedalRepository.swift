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

    /// 拉单个榜；`onPartial` 每解析出一段就回调一次，界面边解析边显示。
    func rankTab(
        _ url: String,
        tab: MedalTab,
        onPartial: (@MainActor @Sendable ([RankMember]) -> Void)? = nil
    ) async throws -> RankDetail {
        try await api.fetchRankTab(url: url, tab: tab, onPartial: onPartial)
    }

    // MARK: - 勋章详情

    func detail(_ url: String, medalId: String, force: Bool = false, encUin: String = "") async throws -> MedalDetail {
        // 详情按「链接 + 勋章 + 成员」缓存，否则不同成员的同名勋章会拿到展示成员的缓存。
        let key = "\(url)#\(medalId)#\(encUin)"
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

    func cachedSkins(_ medalId: String, memberId: String) -> [SkinItem] {
        store.skinCache(medalId, memberId: memberId)
    }

    /// 渐进扫描：从 1 开始逐个序号解析，连续 50 个序号没有皮肤就停止，最多扫到 2000。
    ///
    /// - 展示成员（拥有该勋章）：空序号按勋章名字记录，供同名字的勋章复用；再次进入时从最后一个
    ///   有皮肤的序号往前数（含自身）第 40 个序号起重扫一遍做校验，再继续往后扫。
    /// - 其他成员：跳过同名字勋章已记录的空序号，不写记录，下次仍从 1 开始。
    func scanSkins(
        medalId: String,
        medalName: String,
        uin: String,
        isOwner: Bool,
        batchSize: Int = 20,
        isActive: @escaping () -> Bool,
        onUpdate: @escaping ([SkinItem]) -> Void
    ) async {
        var map: [Int: SkinItem] = [:]
        for skin in store.skinCache(medalId, memberId: uin) {
            map[skin.seq] = skin
        }
        if !map.isEmpty { onUpdate(sortedSkins(map)) }

        // 展示成员写记录、其他成员只读记录。
        var emptySeqs = isOwner ? Set(store.skinEmptySeqs(medalName)) : []
        let skipSeqs: Set<Int> = isOwner ? [] : Set(store.skinEmptySeqs(medalName))

        var currentSeq = 1
        // 校验窗口的左边界：本人已有缓存时，这段序号会重新解析一遍做校验。
        var verifyFrom = Int.max
        if isOwner, let last = map.keys.max() {
            currentSeq = Swift.max(1, last - 39)
            verifyFrom = currentSeq
        }

        // 终止只看「连续 50 个序号没有皮肤」，不能用皮肤总数提前收工（总数可能不准）。
        var emptyStreak = 0
        var confirms = 0

        while isActive() {
            if currentSeq > 2000 { break }
            if emptyStreak >= 50 {
                // 连续 50 个空：再复核一遍这 50 个序号（失败与真没皮肤在底层都返回空）。
                confirms += 1
                let tail = Array(Swift.max(1, currentSeq - 50)..<currentSeq)
                let probe = await api.fetchSkinSeqs(uin: uin, seqs: tail, medalId: medalId)
                var recovered: [Int: SkinItem] = [:]
                for skin in probe where !skin.pic.isEmpty {
                    recovered[skin.seq] = skin
                }
                if recovered.isEmpty || confirms > 3 { break }
                for (seq, skin) in recovered {
                    map[seq] = skin
                    emptySeqs.remove(seq)
                }
                emptyStreak = 0
                let skins = sortedSkins(map)
                onUpdate(skins)
                store.saveSkinCache(medalId, memberId: uin, skins: skins)
                if isOwner { store.saveSkinEmptySeqs(medalName, seqs: emptySeqs.sorted()) }
                continue
            }

            // 组装本批待解析序号：跳过已知空序号；已落盘的在窗口外不重复请求，窗口内重扫。
            var seqs: [Int] = []
            while seqs.count < batchSize && currentSeq <= 2000 {
                let seq = currentSeq
                currentSeq += 1
                if skipSeqs.contains(seq) { continue }
                if map[seq] != nil && seq < verifyFrom { continue }
                seqs.append(seq)
            }
            guard !seqs.isEmpty else { break }

            let result = await api.fetchSkinSeqs(uin: uin, seqs: seqs, medalId: medalId)
            var got: [Int: SkinItem] = [:]
            for skin in result where !skin.pic.isEmpty {
                got[skin.seq] = skin
            }
            for seq in seqs {
                if let skin = got[seq] {
                    map[seq] = skin
                    emptyStreak = 0
                } else {
                    emptyStreak += 1
                    if isOwner { emptySeqs.insert(seq) }
                }
            }

            let skins = sortedSkins(map)
            if !skins.isEmpty { onUpdate(skins) }
            store.saveSkinCache(medalId, memberId: uin, skins: skins)
            if isOwner { store.saveSkinEmptySeqs(medalName, seqs: emptySeqs.sorted()) }
        }

        let skins = sortedSkins(map)
        store.saveSkinCache(medalId, memberId: uin, skins: skins)
        if isOwner { store.saveSkinEmptySeqs(medalName, seqs: emptySeqs.sorted()) }
        if !skins.isEmpty { onUpdate(skins) }
    }

    private func sortedSkins(_ map: [Int: SkinItem]) -> [SkinItem] {
        map.values
            .filter { !$0.pic.isEmpty }
            .sorted { $0.seq < $1.seq }
    }
}
