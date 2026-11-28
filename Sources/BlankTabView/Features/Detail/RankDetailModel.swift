import SwiftUI
import UIKit

// MARK: - Model

@MainActor
final class RankDetailModel: ObservableObject {
    private let services = AppServices.shared

    let memberId: String
    let scheme: String
    let title: String
    private let wantedTab: String

    @Published private(set) var tabs: [MedalTab] = []
    /// 真榜数据是否已回来（回来后用真实 tab 替换占位标签）。
    @Published private(set) var tabsReady = false
    /// 列表按页追加：首屏只上 20 行，滚到底再追加下一页。
    @Published private(set) var visibleCount = 20
    let pageSize = 20
    @Published private(set) var tab: MedalTab?
    @Published private(set) var detail: RankDetail?
    /// 边解析边显示的榜行：解析出来多少就先显示多少。
    @Published private(set) var items: [RankMember] = []
    /// 成员信息里的名次：扫描到哪个名次就显示哪个名次，命中本人后停住。
    @Published private(set) var rankProgress = 0
    @Published private(set) var loading = true
    @Published private(set) var member: Member

    /// 已检索到的本人名次；找到后不再被后续扫描覆盖。
    private var foundRank: Int?

    /// 每次换榜 / 重新加载都换一代；上一代的流式回调和结果一律丢弃。
    private var generation = 0

    init(
        memberId: String,
        scheme: String,
        title: String,
        tabName: String,
        weekTabName: String = "",
        monthTabName: String = ""
    ) {
        self.memberId = memberId
        self.scheme = scheme
        self.title = title
        self.wantedTab = tabName
        self.member = AppServices.shared.member(memberId)

        // 成员卡片上已经有「周榜 / 月榜」这两个标签，进页面就先把它显示出来，不等榜单数据。
        let week = Fmt.cleanTabName(weekTabName)
        let month = Fmt.cleanTabName(monthTabName)
        let weekLabel = week.isEmpty ? "周榜" : week
        let monthLabel = month.isEmpty ? "月榜" : month
        tabs = [
            MedalTab(name: weekLabel, type: 1, id: 1),
            MedalTab(name: monthLabel, type: 2, id: 2),
            MedalTab(name: "乐迷总榜", type: 3, id: 3),
            MedalTab(name: "家族总榜", type: 4, id: 4)
        ]
        let preferred = tabName.isEmpty ? 0 : (tabs.firstIndex { $0.name.contains(tabName) } ?? 0)
        tab = tabs[min(max(preferred, 0), tabs.count - 1)]
        visibleCount = pageSize
    }

    /// 首屏：进入时点默认选中的榜。
    func load() async {
        loading = true
        resetStreaming()
        let gen = generation
        // 仅 CI 截图核对：-demoRank 直接喂演示数据。
        if ProcessInfo.processInfo.arguments.contains("-demoRank") {
            tabs = [
                MedalTab(name: "周榜", type: 1, id: 1),
                MedalTab(name: "月榜", type: 2, id: 2),
                MedalTab(name: "乐迷总榜", type: 3, id: 3),
                MedalTab(name: "家族总榜", type: 4, id: 4)
            ]
            tabsReady = true
            tab = tabs[0]
            // 演示数据里让第 3 名对应当前成员，便于核对名次数字（0→3）的递增。
            var demo = Self.demoMembers
            demo[2].itemId = memberId
            detail = RankDetail(items: demo)
            items = demo
            rankProgress = 3
            foundRank = 3
            visibleCount = pageSize
            loading = false
            return
        }
        do {
            let page = try await services.medals.rankPage(scheme, force: true)
            guard gen == generation else { return }
            guard !page.tabs.isEmpty else {
                detail = nil
                loading = false
                return
            }

            var index = page.activeIndex
            if !wantedTab.isEmpty {
                if let exact = page.tabs.firstIndex(where: { $0.name == wantedTab }) {
                    index = exact
                } else if let partial = page.tabs.firstIndex(where: { $0.name.contains(wantedTab) }) {
                    index = partial
                } else if page.tabs.count > 1 {
                    index = min(index, page.tabs.count - 1)
                }
            }
            index = min(max(index, 0), page.tabs.count - 1)
            tabs = page.tabs
            tabsReady = true
            let chosen = page.tabs[index]
            tab = chosen

            if let cached = page.results.first(where: { $0.tab.id == chosen.id }), cached.success {
                detail = cached.detail
                items = cached.detail.items
                rankProgress = rankOf(cached.detail.items)
                foundRank = rankProgress > 0 ? rankProgress : nil
                visibleCount = pageSize
            } else {
                let detail = try await services.medals.rankTab(scheme, tab: chosen, onPartial: partialHandler(gen: gen))
                guard gen == generation else { return }
                self.detail = detail
                items = detail.items
                rankProgress = rankOf(detail.items)
                foundRank = rankProgress > 0 ? rankProgress : nil
                visibleCount = pageSize
            }
        } catch {
            guard gen == generation else { return }
            detail = nil
        }
        if gen == generation { loading = false }
    }

    /// 切换榜单标签：页面先切过去，数据随后填入。
    func select(_ target: MedalTab) async {
        guard tabsReady, target.id != tab?.id else { return }
        if ProcessInfo.processInfo.arguments.contains("-demoRank") {
            tab = target
            return
        }
        // 先切页面：标签、榜名立即更新，列表回到加载态，之后再把数据填进来。
        tab = target
        detail = nil
        resetStreaming()
        let gen = generation
        visibleCount = pageSize
        loading = true
        do {
            let detail = try await services.medals.rankTab(scheme, tab: target, onPartial: partialHandler(gen: gen))
            guard gen == generation else { return }
            self.detail = detail
            self.items = detail.items
            self.rankProgress = rankOf(detail.items)
            self.foundRank = self.rankProgress > 0 ? self.rankProgress : nil
            self.visibleCount = pageSize
        } catch {
            guard gen == generation else { return }
        }
        if gen == generation { loading = false }
    }

    /// 解析回调：每解析出一段就先把它显示出来，名次跟着扫描进度走。
    /// 回调带着发起时的代号，换榜之后到达的旧回调直接丢弃。
    private func partialHandler(gen: Int) -> @MainActor @Sendable ([RankMember]) -> Void {
        { [weak self] partial in
            self?.showStreaming(partial, gen: gen)
        }
    }

    private func showStreaming(_ incoming: [RankMember], gen: Int) {
        guard gen == generation else { return }
        guard incoming.count >= items.count else { return }
        items = incoming
        if let foundRank {
            rankProgress = foundRank
            return
        }
        if let hit = incoming.first(where: { MemberId.matches($0.itemId, memberId) }) {
            foundRank = hit.position
            rankProgress = hit.position
        } else if let last = incoming.last {
            rankProgress = last.position
        }
    }

    private func resetStreaming() {
        generation += 1
        items = []
        rankProgress = 0
        foundRank = nil
    }

    /// 榜单里当前这位成员的名次；没命中则为 0。
    private func rankOf(_ list: [RankMember]) -> Int {
        guard !memberId.isEmpty,
              let hit = list.first(where: { MemberId.matches($0.itemId, memberId) }) else { return 0 }
        return hit.position
    }

    /// 滚到接近本页末尾时再追加一页。
    func revealMoreIfNeeded(after item: RankMember) {
        guard !items.isEmpty else { return }
        guard let index = items.firstIndex(where: { $0.itemId == item.itemId && $0.position == item.position }) else { return }
        if index >= visibleCount - 2, visibleCount < items.count {
            visibleCount = min(visibleCount + pageSize, items.count)
        }
    }

    static let demoMembers: [RankMember] = (1...10).map { position in
        var item = RankMember()
        item.position = position
        item.title = "乐迷用户 \(position)"
        item.wearTexts = position <= 3 ? ["NO.5200370"] : []
        item.honorTexts = position <= 3 ? ["月第1 马鞍山 CARAT"] : []
        item.descTexts = ["乐迷值 50546", "上榜12次"]
        item.praiseNum = position == 1 ? 12362 : 1200 - position * 45
        return item
    }
}
