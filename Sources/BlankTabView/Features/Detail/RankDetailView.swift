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
    @Published private(set) var error: String?
    @Published private(set) var member: Member

    /// 已检索到的本人名次；找到后不再被后续扫描覆盖。
    private var foundRank: Int?

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
            MedalTab(name: "总榜", type: 3, id: 3)
        ]
        let preferred = tabName.isEmpty ? 0 : (tabs.firstIndex { $0.name.contains(tabName) } ?? 0)
        tab = tabs[min(max(preferred, 0), tabs.count - 1)]
        visibleCount = pageSize
    }

    /// 首屏：进入时点默认选中的榜。
    func load() async {
        loading = true
        error = nil
        resetStreaming()
        // 仅 CI 截图核对：-demoRank 直接喂演示数据。
        if ProcessInfo.processInfo.arguments.contains("-demoRank") {
            tabs = [
                MedalTab(name: "周榜", type: 1, id: 1),
                MedalTab(name: "月榜", type: 2, id: 2),
                MedalTab(name: "总榜", type: 3, id: 3)
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
            // 仅 CI 截图核对：-demoRankNotice 强制展示状态提示（标题 / 正文 / 按钮）。
            if ProcessInfo.processInfo.arguments.contains("-demoRankNotice") {
                detail = nil
                items = []
                rankProgress = 0
                error = "无法连接到榜单服务，请检查网络后重试。"
            }
            return
        }
        do {
            let page = try await services.medals.rankPage(scheme, force: true)
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
                detail = try await services.medals.rankTab(scheme, tab: chosen, onPartial: partialHandler)
                items = detail?.items ?? items
                rankProgress = rankOf(detail?.items ?? [])
                visibleCount = pageSize
            }
        } catch {
            self.error = error.localizedDescription
            detail = nil
        }
        loading = false
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
        visibleCount = pageSize
        loading = true
        error = nil
        do {
            let detail = try await services.medals.rankTab(scheme, tab: target, onPartial: partialHandler)
            self.detail = detail
            self.items = detail.items
            self.rankProgress = rankOf(detail.items)
            self.visibleCount = pageSize
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    /// 解析回调：每解析出一段就先把它显示出来，名次跟着扫描进度走。
    private var partialHandler: @MainActor @Sendable ([RankMember]) -> Void {
        { [weak self] partial in
            self?.showStreaming(partial)
        }
    }

    private func showStreaming(_ incoming: [RankMember]) {
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

// MARK: - View

/// 榜单详情：系统电话「最近通话」式列表（原生 List，不画卡片），页面底色统一分组灰。
struct RankDetailView: View {
    @StateObject private var model: RankDetailModel
    /// 点榜单成员 → 该成员的「已获得奖章」；响应里的 ItemID 与家族成员 ID 同源。
    @State private var openedMember: Member?
    /// 分享图（点工具栏分享按钮后离屏渲染出来，再走系统分享面板）。
    @State private var shareImage: ShareImage?

    init(
        memberId: String,
        scheme: String,
        title: String,
        tabName: String,
        weekTabName: String = "",
        monthTabName: String = ""
    ) {
        _model = StateObject(
            wrappedValue: RankDetailModel(
                memberId: memberId,
                scheme: scheme,
                title: title,
                tabName: tabName,
                weekTabName: weekTabName,
                monthTabName: monthTabName
            )
        )
    }

    /// 工具栏 tab 只显示前三个；第三个标签固定叫「总榜」。
    private var tabTitles: [String] {
        Array(model.tabs.prefix(3).enumerated()).map { index, item in
            index == 2 ? "总榜" : Fmt.cleanTabName(item.name)
        }
    }

    /// 当前选中榜在前三个标签里的下标。
    private var tabIndex: Int {
        guard let current = model.tab,
              let index = model.tabs.firstIndex(where: { $0.id == current.id }) else { return 0 }
        return min(index, 2)
    }

    private var headerSubtitle: String {
        let artist = model.member.artistName.trimmingCharacters(in: .whitespacesAndNewlines)
        let listName = model.tab.map { Fmt.cleanTabName($0.name) } ?? model.title
        return artist.isEmpty ? listName : "\(artist)的\(listName)"
    }

    /// 「最近通话」行的内边距：左右与成员信息对齐。
    private let rowInsets = EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)

    var body: some View {
        List {
            MemberSectionHeader(
                title: model.member.title,
                pic: model.member.pic,
                subtitle: headerSubtitle,
                count: "\(model.rankProgress)",
                countValue: model.rankProgress,
                unit: "名",
                label: "名次"
            )
            .listRowInsets(rowInsets)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            // 榜名已由导航栏标题承担，不再放灰色分节标题。
            rows
        }
        .listStyle(.plain)
        .contentMargins(.top, 0, for: .scrollContent)
        .padding(.top, -52)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationDestination(item: $openedMember) { member in
            MedalsHallView(memberId: member.itemId, seedMember: member)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                if model.tabs.count > 1 {
                    RankTabBar(titles: tabTitles, selectedIndex: tabIndex) { index in
                        guard model.tabs.indices.contains(index) else { return }
                        let target = model.tabs[index]
                        Task { await model.select(target) }
                    }
                    .frame(maxHeight: 30)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    guard let image = makeShareImage() else { return }
                    shareImage = ShareImage(image: image)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("分享榜单")
            }
        }
        .sheet(item: $shareImage) { payload in
            ShareSheet(items: [payload.image])
        }
        .task { await model.load() }
        .refreshable { await model.load() }
    }

    @ViewBuilder
    private var rows: some View {
        if model.loading, model.items.isEmpty {
            // 加载中也复用同一套行，只是喂空数据。
            ForEach(0..<8, id: \.self) { _ in
                RankMemberRow(item: RankMember())
                    .listRowBackground(Color.clear)
            }
        } else if let error = model.error {
            DetailPageNotice(
                StateNotice(title: "榜单加载失败", message: error, actionTitle: "重试") {
                    Task { await model.load() }
                }
            )
            .listRowInsets(rowInsets)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } else if !model.items.isEmpty {
            ForEach(Array(model.items.prefix(model.visibleCount).enumerated()), id: \.offset) { _, item in
                RankMemberRow(item: item)
                    .listRowBackground(Color.clear)
                    .contentShape(Rectangle())
                    .onAppear { model.revealMoreIfNeeded(after: item) }
                    .onTapGesture { openedMember = seedMember(for: item) }
            }
        } else {
            DetailPageNotice(StateNotice(title: "暂无数据", message: model.detail?.emptyText))
                .listRowInsets(rowInsets)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
    }

    /// 分享图：用 ImageRenderer 离屏渲染固定宽度的卡片。
    @MainActor
    private func makeShareImage() -> UIImage? {
        let items = model.items
        guard !items.isEmpty else { return nil }
        let card = RankShareCard(
            title: model.title,
            subtitle: headerSubtitle,
            members: items,
            ownerName: model.member.title
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        return renderer.uiImage
    }

    /// 用榜行数据做成员卡片入参，避免陌生成员落到「用户」占位。
    private func seedMember(for item: RankMember) -> Member? {
        let id = item.itemId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return nil }
        var member = AppServices.shared.member(id)
        if member.title.isEmpty || member.title == "用户" {
            member = Member(itemId: id, title: item.title, pic: item.pic)
        }
        return member
    }
}

/// 榜单行：头像在最左，右侧依次是名次与三行文本；最右是实心爱心与心动数。
struct RankMemberRow: View {
    let item: RankMember

    private var name: String { item.title.isEmpty ? " " : item.title }
    private var wears: [String] { item.wearTexts.filter { !$0.isEmpty } }
    private var honors: [String] { item.honorTexts.filter { !$0.isEmpty } }
    /// 称号胶囊高度：始终等于同排铭牌文字的实际高度（随语义字号自动变化）。
    @State private var plateHeight: CGFloat = 0
    /// 点赞数弹窗：1 万及以上点开显示完整数值。
    @State private var showExactPraise = false
    /// 没有铭牌时的兜底高度：说明（caption）语义字号的行高，随动态字体缩放。
    @ScaledMetric(relativeTo: .caption) private var captionHeight: CGFloat = 15

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // 头像贴最左；行内边距与分隔线缩进全部交给系统默认（系统会避让前导图）。
            AvatarCircle(urlString: item.pic, size: 48, showsRing: false)

            // 名次在头像右侧：与成员名字同一语义字号（subheadline + bold），数字横向居中。
            Text(item.position > 0 ? "\(item.position)" : "–")
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.primary)
                .frame(width: 28)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 3) {
                // 第一行：成员名字（iOS 副标题语义字号 subheadline，字重 bold）。
                Text(name)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)

                // 第二行：称号（WearList 的 Title，caption2 最小说明、默认字重，长条胶囊包裹，
                //         胶囊高度跟随铭牌文字高度）在前，铭牌（限定编号 NO.xxxx，caption 说明语义 + semibold，无底色）在后。
                if !wears.isEmpty || !honors.isEmpty {
                    HStack(alignment: .center, spacing: 6) {
                        ForEach(honors, id: \.self) { honor in
                            Text(honor)
                                .font(.caption2)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .frame(height: plateHeight > 0 ? plateHeight : captionHeight)
                                .background(Color(.tertiarySystemFill), in: Capsule())
                        }
                        ForEach(wears, id: \.self) { wear in
                            Text(wear)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear.preference(key: PlateHeightKey.self, value: geo.size.height)
                                    }
                                )
                        }
                    }
                    .lineLimit(1)
                    .onPreferenceChange(PlateHeightKey.self) { height in
                        if height > 0 { plateHeight = height }
                    }
                }

                // 第三行：原来的副文案（DescList，caption2 最小说明字号）。
                if !item.descTexts.isEmpty {
                    Text(item.descTexts.joined(separator: "  "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            // 心动数：实心爱心在上、数字在下方，数字用 caption（说明）语义字号。
            VStack(spacing: 2) {
                Image(systemName: "heart.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(item.isPraised ? Color.red : Color.secondary)
                    .contentShape(Rectangle())
                    .onTapGesture { revealExactPraise() }

                Text(item.praiseNum > 0 ? RankPraise.short(item.praiseNum) : " ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentShape(Rectangle())
                    .onTapGesture { revealExactPraise() }
                    .popover(isPresented: $showExactPraise, arrowEdge: .top) {
                        Text(RankPraise.exact(item.praiseNum))
                            .font(.footnote.monospacedDigit())
                            .padding(12)
                            .presentationCompactAdaptation(.popover)
                    }
            }
        }
    }

    /// 1 万及以上才弹具体数值；不足 1 万数字本身就是完整值，不弹。
    private func revealExactPraise() {
        if item.praiseNum >= 10000 { showExactPraise = true }
    }
}

#Preview {
    NavigationStack {
        RankDetailView(memberId: "12345", scheme: "https://i2.y.qq.com/x?a=1", title: "周榜", tabName: "周榜")
    }
}

private struct PlateHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
