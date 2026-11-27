import SwiftUI

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
        item.wearTexts = position <= 3 ? ["铁粉"] : []
        item.descTexts = ["贡献值 \(1000 - position * 60)"]
        item.praiseNum = 1200 - position * 45
        return item
    }
}

// MARK: - View

/// 榜单详情：系统电话「最近通话」式列表（原生 List，不画卡片），页面底色统一分组灰。
struct RankDetailView: View {
    @StateObject private var model: RankDetailModel
    /// 点榜单成员 → 该成员的「已获得奖章」；响应里的 ItemID 与家族成员 ID 同源。
    @State private var openedMember: Member?

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

            // 榜名已由导航栏标题承担，不再放灰色分节标题。
            rows
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationDestination(item: $openedMember) { member in
            MedalsHallView(memberId: member.itemId, seedMember: member)
        }
        .navigationTitle(model.title)
        .navigationBarTitleDisplayMode(.inline)
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

/// 榜单行：第一行成员名字，第二行勋章铭牌，第三行副文案；右侧是心动数。
struct RankMemberRow: View {
    let item: RankMember

    private var name: String { item.title.isEmpty ? " " : item.title }
    private var wears: [String] { item.wearTexts.filter { !$0.isEmpty } }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // 名次：语义字号 subheadline（默认 15pt）+ bold。
            Text(item.position > 0 ? "\(item.position)" : "–")
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(item.position > 0 && item.position <= 3 ? Color.accentColor : Color.primary)
                .frame(width: 24, alignment: .leading)

            // 头像与页面顶部成员信息同尺寸，且不要白边。
            AvatarCircle(urlString: item.pic, size: 48, showsRing: false)

            VStack(alignment: .leading, spacing: 3) {
                // 第一行：成员名字（语义字号 footnote + bold）。
                HStack(spacing: 6) {
                    Text(name)
                        .font(.footnote.weight(.bold))
                        .lineLimit(1)
                    if let selected = AppServices.shared.store.selectedMemberId,
                       !item.itemId.isEmpty,
                       MemberId.matches(item.itemId, selected) {
                        MeBadge()
                    }
                }

                // 第二行：勋章铭牌（caption 字号，见 Plate 组件）。
                if !wears.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(wears, id: \.self) { wear in
                            Plate(text: wear)
                        }
                    }
                }

                // 第三行：原来的副文案（DescList）。
                if !item.descTexts.isEmpty {
                    Text(item.descTexts.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                Image(systemName: item.isPraised ? "heart.fill" : "heart")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(item.isPraised ? Color.red : Color.secondary)
                Text(item.praiseNum > 0 ? Fmt.compact(item.praiseNum) : " ")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}

#Preview {
    NavigationStack {
        RankDetailView(memberId: "12345", scheme: "https://i2.y.qq.com/x?a=1", title: "周榜", tabName: "周榜")
    }
}
