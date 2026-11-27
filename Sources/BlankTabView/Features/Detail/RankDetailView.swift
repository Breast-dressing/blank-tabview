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

    @Published private(set) var tab: MedalTab?
    @Published private(set) var detail: RankDetail?
    @Published private(set) var loading = true
    @Published private(set) var error: String?
    @Published private(set) var member: Member

    init(memberId: String, scheme: String, title: String, tabName: String) {
        self.memberId = memberId
        self.scheme = scheme
        self.title = title
        self.wantedTab = tabName
        self.member = AppServices.shared.member(memberId)
    }

    /// 只展示进入时点的那个榜：页面里不再有分类切换。
    func load() async {
        loading = true
        error = nil
        // 仅 CI 截图核对：-demoRank 直接喂演示数据。
        if ProcessInfo.processInfo.arguments.contains("-demoRank") {
            tab = MedalTab(name: "周榜", type: 1, id: 1)
            detail = RankDetail(items: Self.demoMembers)
            loading = false
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
            let chosen = page.tabs[index]
            tab = chosen

            if let cached = page.results.first(where: { $0.tab.id == chosen.id }), cached.success {
                detail = cached.detail
            } else {
                detail = try await services.medals.rankTab(scheme, tab: chosen)
            }
        } catch {
            self.error = error.localizedDescription
            detail = nil
        }
        loading = false
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
    /// 顶部成员信息被完全滚出屏幕后，工具栏中央显示它的第二行文本。
    @State private var showsHeaderTitle = false

    init(memberId: String, scheme: String, title: String, tabName: String) {
        _model = StateObject(
            wrappedValue: RankDetailModel(memberId: memberId, scheme: scheme, title: title, tabName: tabName)
        )
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
                count: "\(model.detail?.items.count ?? 0)",
                unit: "人",
                label: "上榜"
            )
            .listRowInsets(rowInsets)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: HeaderBottomKey.self, value: geo.frame(in: .global).maxY)
                }
            )
            .onPreferenceChange(HeaderBottomKey.self) { bottom in
                showsHeaderTitle = bottom < 104
            }

            // 榜名已由导航栏标题承担，不再放灰色分节标题。
            rows
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationDestination(item: $openedMember) { member in
            MedalsHallView(memberId: member.itemId, seedMember: member)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                if showsHeaderTitle {
                    Text(headerSubtitle)
                        .font(.headline)
                        .lineLimit(1)
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
        if model.loading {
            // 加载中也复用同一套行，只是喂空数据。
            ForEach(0..<8, id: \.self) { _ in
                RankMemberRow(item: RankMember())
                    .listRowInsets(rowInsets)
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 48 }
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
        } else if let detail = model.detail, !detail.items.isEmpty {
            ForEach(Array(detail.items.enumerated()), id: \.offset) { _, item in
                RankMemberRow(item: item)
                    .listRowInsets(rowInsets)
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 48 }
                    .listRowBackground(Color.clear)
                    .contentShape(Rectangle())
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
        let items = model.detail?.items ?? []
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
            // 头像贴最左；分隔线起点由行上固定的头像宽度决定（见 rows 里的 alignmentGuide），
            // 头像下方因此不出现分隔线，也不受名次文本长度影响。
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
                HStack(spacing: 6) {
                    Text(name)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                    if let selected = AppServices.shared.store.selectedMemberId,
                       !item.itemId.isEmpty,
                       MemberId.matches(item.itemId, selected) {
                        MeBadge()
                    }
                }

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

private struct HeaderBottomKey: PreferenceKey {
    static var defaultValue: CGFloat = 1000
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

private struct PlateHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
