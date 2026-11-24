import SwiftUI

// MARK: - Model

@MainActor
final class RankDetailModel: ObservableObject {
    private let services = AppServices.shared

    let memberId: String
    let scheme: String
    let title: String
    private let wantedTab: String

    @Published private(set) var tabs: [MedalTab] = []
    @Published private(set) var selectedIndex = 0
    @Published private(set) var detail: RankDetail?
    @Published private(set) var loading = true
    @Published private(set) var tabLoading = false
    @Published private(set) var error: String?
    @Published private(set) var member: Member

    private var pageData: RankPageData?

    init(memberId: String, scheme: String, title: String, tabName: String) {
        self.memberId = memberId
        self.scheme = scheme
        self.title = title
        self.wantedTab = tabName
        self.member = AppServices.shared.member(memberId)
    }

    var currentTab: MedalTab? {
        tabs.indices.contains(selectedIndex) ? tabs[selectedIndex] : nil
    }

    func load() async {
        loading = true
        error = nil
        do {
            let page = try await services.medals.rankPage(scheme, force: true)
            pageData = page
            tabs = page.tabs
            guard !tabs.isEmpty else {
                detail = nil
                loading = false
                return
            }

            var index = page.activeIndex
            if !wantedTab.isEmpty {
                if let exact = tabs.firstIndex(where: { $0.name == wantedTab }) {
                    index = exact
                } else if let partial = tabs.firstIndex(where: { $0.name.contains(wantedTab) }) {
                    index = partial
                }
            }
            selectedIndex = min(max(index, 0), tabs.count - 1)

            if let cached = page.results.first(where: { $0.tab.id == tabs[selectedIndex].id }), cached.success {
                detail = cached.detail
            } else {
                await fetchCurrentTab()
            }
        } catch {
            self.error = error.localizedDescription
            detail = nil
        }
        loading = false
    }

    func select(_ index: Int) async {
        guard tabs.indices.contains(index), index != selectedIndex || detail == nil else { return }
        selectedIndex = index
        if let pageData,
           let cached = pageData.results.first(where: { $0.tab.id == tabs[index].id }),
           cached.success {
            detail = cached.detail
            error = nil
            return
        }
        await fetchCurrentTab()
    }

    private func fetchCurrentTab() async {
        guard let tab = currentTab else { return }
        tabLoading = true
        error = nil
        do {
            detail = try await services.medals.rankTab(scheme, tab: tab)
        } catch {
            self.error = error.localizedDescription
            detail = nil
        }
        tabLoading = false
    }
}

// MARK: - View

struct RankDetailView: View {
    @StateObject private var model: RankDetailModel

    init(memberId: String, scheme: String, title: String, tabName: String) {
        _model = StateObject(
            wrappedValue: RankDetailModel(memberId: memberId, scheme: scheme, title: title, tabName: tabName)
        )
    }

    var body: some View {
        DetailScroll {
            MemberHeaderBar(
                name: model.member.title,
                pic: model.member.pic,
                subtitle: model.member.medalText
            )

            if model.tabs.count > 1 {
                PillTabsView(
                    titles: model.tabs.map { Fmt.cleanTabName($0.name) },
                    selected: model.selectedIndex,
                    onSelect: { index in Task { await model.select(index) } }
                )
                .padding(.horizontal, -20)
            }

            content
        }
        .navigationTitle(model.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .refreshable { await model.load() }
    }

    @ViewBuilder
    private var content: some View {
        if model.loading {
            StateNotice(title: "正在读取榜单…", progress: true)
        } else if let error = model.error, model.tabLoading == false {
            StateNotice(title: "榜单加载失败", message: error, actionTitle: "重试") {
                Task { await model.load() }
            }
        } else if model.tabLoading {
            StateNotice(title: "正在读取该榜单…", progress: true)
        } else if let detail = model.detail, !detail.items.isEmpty {
            InfoCard(padding: 6) {
                VStack(spacing: 0) {
                    ForEach(Array(detail.items.enumerated()), id: \.offset) { index, item in
                        row(item)
                        if index < detail.items.count - 1 {
                            Divider().padding(.leading, 54)
                        }
                    }
                }
            }
        } else {
            StateNotice(title: "暂无数据", message: model.detail?.emptyText)
        }
    }

    private func row(_ item: RankMember) -> some View {
        HStack(spacing: 10) {
            Text("\(item.position)")
                .font(.system(size: 15, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(item.position <= 3 ? Color.accentColor : Color.primary)
                .frame(width: 28, alignment: .leading)

            AvatarCircle(urlString: item.pic, size: 36)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(item.title.isEmpty ? "未知成员" : item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    if let selected = AppServices.shared.store.selectedMemberId,
                       Fmt.decodeId(item.itemId) == selected {
                        MeBadge()
                    }
                    if let wear = item.wearTexts.first, !wear.isEmpty {
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
                Text(Fmt.compact(item.praiseNum))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }
}

#Preview {
    NavigationStack {
        RankDetailView(memberId: "12345", scheme: "https://i2.y.qq.com/x?a=1", title: "周榜", tabName: "周榜")
    }
}
