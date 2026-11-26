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

/// 排行榜详情：与「乐迷皮肤」页同一套骨架（成员信息平铺 + 白卡片），页面内不再放分类胶囊。
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

    var body: some View {
        DetailPageScaffold(
            header: MemberSectionHeader(
                title: model.member.title,
                pic: model.member.pic,
                subtitle: headerSubtitle,
                count: "\(model.detail?.items.count ?? 0)",
                unit: "人",
                label: "上榜"
            )
        ) {
            if model.loading {
                // 加载中直接复用同一套行 UI，只是喂空数据。
                DetailSeriesCard(title: model.title) {
                    VStack(spacing: 0) {
                        ForEach(0..<6, id: \.self) { _ in
                            RankMemberRow(item: RankMember())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if let error = model.error {
                DetailPageNotice(
                    StateNotice(title: "榜单加载失败", message: error, actionTitle: "重试") {
                        Task { await model.load() }
                    }
                )
            } else if let detail = model.detail, !detail.items.isEmpty {
                DetailSeriesCard(title: model.title) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(detail.items.enumerated()), id: \.offset) { _, item in
                            RankMemberRow(item: item)
                                .contentShape(Rectangle())
                                .onTapGesture { openedMember = seedMember(for: item) }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                DetailPageNotice(StateNotice(title: "暂无数据", message: model.detail?.emptyText))
            }
        }
        .navigationDestination(item: $openedMember) { member in
            MedalsHallView(memberId: member.itemId, seedMember: member)
        }
        .navigationTitle(model.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .refreshable { await model.load() }
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

/// 榜单行：名次 + 头像 + 名字/勋章铭牌 + 心动数。
struct RankMemberRow: View {
    let item: RankMember

    var body: some View {
        HStack(spacing: 10) {
            Text(item.position > 0 ? "\(item.position)" : "–")
                .font(.system(size: 15, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(item.position > 0 && item.position <= 3 ? Color.accentColor : Color.primary)
                .frame(width: 28, alignment: .leading)

            AvatarCircle(urlString: item.pic, size: 36)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(item.title.isEmpty ? " " : item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    if let selected = AppServices.shared.store.selectedMemberId,
                       !item.itemId.isEmpty,
                       MemberId.matches(item.itemId, selected) {
                        MeBadge()
                    }
                    // 与 node renderRankItem 一致：WearList 有几段就显示几枚铭牌。
                    ForEach(item.wearTexts.filter { !$0.isEmpty }, id: \.self) { wear in
                        Plate(text: wear, filled: true)
                    }
                }
                if !item.descTexts.isEmpty {
                    Text(item.descTexts.joined(separator: " · "))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            HStack(spacing: 3) {
                Image(systemName: item.isPraised ? "heart.fill" : "heart")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(item.isPraised ? Color.red : Color.secondary)
                Text(item.praiseNum > 0 ? Fmt.compact(item.praiseNum) : " ")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        RankDetailView(memberId: "12345", scheme: "https://i2.y.qq.com/x?a=1", title: "周榜", tabName: "周榜")
    }
}
