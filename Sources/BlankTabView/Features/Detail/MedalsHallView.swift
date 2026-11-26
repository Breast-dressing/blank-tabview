import SwiftUI
import UIKit

/// 勋章详情 sheet 入参。
struct MedalSheetTarget: Identifiable {
    let medalId: String
    let medalName: String
    let scheme: String
    let imageUrl: String
    let date: String

    var id: String { medalId + "|" + imageUrl }
}

// MARK: - Model

@MainActor
final class MedalsHallModel: ObservableObject {
    private let services = AppServices.shared

    let memberId: String

    @Published private(set) var tabs: [MedalTab] = []
    @Published private(set) var results: [ModuleTabResult] = []
    @Published private(set) var selectedIndex = 0
    @Published private(set) var desc = ""
    @Published private(set) var loading = true
    @Published private(set) var error: String?
    @Published private(set) var member: Member
    @Published var sheetTarget: MedalSheetTarget?

    private var page: MedalHallPage?

    init(memberId: String) {
        self.memberId = memberId
        self.member = AppServices.shared.member(memberId)
    }

    var current: ModuleTabResult? {
        results.indices.contains(selectedIndex) ? results[selectedIndex] : results.first
    }

    var medalTotal: Int { current?.modules.flatMap(\.items).count ?? 0 }

    var medalUnlocked: Int { current?.modules.flatMap(\.items).filter { $0.unlocked }.count ?? 0 }

    var errorIndexes: Set<Int> {
        Set(results.indices.filter { !results[$0].success && !results[$0].loading })
    }

    /// 成员信息下方的文案：固定为「的勋章馆」。
    var headerSubtitle: String {
        let artist = member.artistName.trimmingCharacters(in: .whitespacesAndNewlines)
        return artist.isEmpty ? "的勋章馆" : "\(artist)的勋章馆"
    }

    func load() async {
        loading = true
        error = nil
        do {
            let page = try await services.medals.hallPage(services.hallURL(memberId), onlyInitial: true)
            self.page = page
            tabs = page.tabs
            desc = page.desc
            results = page.results
            selectedIndex = page.initialTabIndex
            loading = false
            Task { await self.fillRemainingTabs() }
        } catch {
            self.error = error.localizedDescription
            loading = false
        }
    }

    private func fillRemainingTabs() async {
        guard let page else { return }
        await services.medals.ensureHallTabs(page) { [weak self] updated in
            let snapshot = updated.results
            Task { @MainActor in self?.apply(snapshot) }
        }
    }

    private func apply(_ snapshot: [ModuleTabResult]) {
        guard !snapshot.isEmpty else { return }
        results = snapshot
    }

    func select(_ index: Int) async {
        guard results.indices.contains(index) else { return }
        selectedIndex = index
        if results[index].success || results[index].loading { return }
        guard let page else { return }
        _ = await services.medals.hallTab(page, index: index)
        apply(page.results)
    }

    // MARK: - 勋章点击

    func openTile(_ item: MedalItem, tabName: String) -> ProfileDestination? {
        if tabName.contains("乐迷") {
            return .skins(
                memberId: memberId,
                medalId: item.medalId,
                medalName: item.name,
                scheme: item.scheme
            )
        }
        sheetTarget = MedalSheetTarget(
            medalId: item.medalId,
            medalName: item.name,
            scheme: item.scheme,
            imageUrl: item.picUrl,
            date: item.createTime.isEmpty ? item.cornerTitle : item.createTime
        )
        return nil
    }
}

// MARK: - View

struct MedalsHallView: View {
    @StateObject private var model: MedalsHallModel
    @State private var pendingPush: ProfileDestination?
    @Namespace private var zoomNS

    init(memberId: String) {
        _model = StateObject(wrappedValue: MedalsHallModel(memberId: memberId))
    }

    var body: some View {
        DetailPageScaffold(
            header: MemberSectionHeader(
                title: model.member.title,
                pic: model.member.pic,
                subtitle: model.headerSubtitle,
                count: "\(model.medalUnlocked)",
                unit: "枚"
            )
        ) {
            if model.tabs.count > 1 {
                PillTabsView(
                    titles: model.tabs.map { Fmt.cleanTabName($0.name) },
                    selected: model.selectedIndex,
                    errorIndexes: model.errorIndexes,
                    onSelect: { index in Task { await model.select(index) } }
                )
                .padding(.horizontal, 16)
            }

            ForEach(Array(moduleSections.enumerated()), id: \.offset) { _, pair in
                moduleCard(pair.module, tabName: pair.tabName)
            }

            if model.loading {
                StateNotice(title: "正在读取勋章数据…", progress: true)
                    .padding(.horizontal, 16)
            } else if let error = model.error {
                StateNotice(title: "勋章数据加载失败", message: error, actionTitle: "重试") {
                    Task { await model.load() }
                }
                .padding(.horizontal, 16)
            } else if let current = model.current, !current.success {
                StateNotice(title: "该分类加载失败", message: current.error, actionTitle: "重试") {
                    Task { await model.load() }
                }
                .padding(.horizontal, 16)
            } else if moduleSections.isEmpty {
                StateNotice(title: "暂无奖章数据")
                    .padding(.horizontal, 16)
            }
        }
        .navigationTitle("已获得奖章")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .refreshable { await model.load() }
        .sheet(item: $model.sheetTarget) { target in
            MedalDetailSheet(memberId: model.memberId, target: target, zoomNamespace: zoomNS)
        }
        .navigationDestination(isPresented: Binding(
            get: { pendingPush != nil },
            set: { if !$0 { pendingPush = nil } }
        )) {
            if let route = pendingPush {
                pushDestination(route)
            }
        }
    }

    private var moduleSections: [(module: MedalModule, tabName: String)] {
        guard let current = model.current, current.success else { return [] }
        return current.modules.map { ($0, current.tab.name) }
    }

    /// 卡片：与乐迷皮肤页的系列卡同一套（标题 + 「全部」+ 三列奖章）。
    private func moduleCard(_ module: MedalModule, tabName: String) -> some View {
        DetailSeriesCard(
            title: module.moduleName.isEmpty ? "模块 \(module.moduleId)" : module.moduleName,
            trailing: module.moduleId.isEmpty ? nil : "全部",
            onTrailingTap: module.moduleId.isEmpty ? nil : {
                pendingPush = .medalModule(
                    memberId: model.memberId,
                    moduleId: module.moduleId,
                    moduleName: module.moduleName,
                    tabName: tabName
                )
            }
        ) {
            ZoomedMedalTileGrid(items: Array(module.items.prefix(3)), zoomNamespace: zoomNS) { item in
                if let route = model.openTile(item, tabName: tabName) {
                    pendingPush = route
                }
            }
        }
    }

    @ViewBuilder
    private func pushDestination(_ route: ProfileDestination) -> some View {
        switch route {
        case let .medalModule(memberId, moduleId, moduleName, tabName):
            MedalModuleView(memberId: memberId, moduleId: moduleId, moduleName: moduleName, tabName: tabName)
        case let .skins(memberId, medalId, medalName, scheme):
            SkinsView(memberId: memberId, medalId: medalId, medalName: medalName, scheme: scheme)
        default:
            EmptyView()
        }
    }
}

#Preview {
    NavigationStack {
        MedalsHallView(memberId: "12345")
    }
}
