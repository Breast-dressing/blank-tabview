import SwiftUI
import UIKit

/// 勋章详情 sheet 入参。
struct MedalSheetTarget: Identifiable {
    let medalId: String
    let medalName: String
    let scheme: String
    let imageUrl: String
    let date: String
    /// 限定编号（接口 NumberInfo.Content，降级读 Corner.Title）。
    var number: String = ""
    /// Corner.Title：可能承载「NO.xxx」也可能承载日期。
    var cornerTitle: String = ""

    var id: String { medalId + "|" + imageUrl }

    /// 编号优先取 NumberInfo，其次取 Corner.Title 里的 NO.x。
    static func numberText(of item: MedalItem) -> String {
        let number = item.numberText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !number.isEmpty && number != "NO.----" { return number }
        let corner = item.cornerTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if corner.hasPrefix("NO.") { return corner }
        return ""
    }
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

    var medalTotal: Int { modules.flatMap(\.items).count }

    var medalUnlocked: Int { modules.flatMap(\.items).filter { $0.unlocked }.count }

    /// 没有任何勋章数据的模块直接不展示。
    var modules: [MedalModule] {
        guard let current, current.success else { return [] }
        return current.modules.filter { !$0.items.isEmpty }
    }

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
            date: item.createTime.isEmpty ? item.cornerTitle : item.createTime,
            number: MedalSheetTarget.numberText(of: item),
            cornerTitle: item.cornerTitle
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

            if model.loading {
                // 加载中也用同一套卡片 UI，只是喂占位项。
                ForEach(0..<2, id: \.self) { _ in
                    placeholderCard
                }
            } else {
                ForEach(Array(model.modules.enumerated()), id: \.offset) { _, module in
                    moduleCard(module, tabName: model.current?.tab.name ?? "")
                }
            }

            if let error = model.error {
                StateNotice(title: "勋章数据加载失败", message: error, actionTitle: "重试") {
                    Task { await model.load() }
                }
                .padding(.horizontal, 16)
            } else if !model.loading, let current = model.current, !current.success {
                StateNotice(title: "该分类加载失败", message: current.error, actionTitle: "重试") {
                    Task { await model.load() }
                }
                .padding(.horizontal, 16)
            } else if !model.loading, model.modules.isEmpty {
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

    /// 加载中的占位卡：与真实卡完全同一套组件，只是数据为空。
    private var placeholderCard: some View {
        DetailSeriesCard(title: "") {
            ZoomedMedalTileGrid(items: Self.placeholderItems(ns: 0), zoomNamespace: nil) { _ in }
        }
    }

    static func placeholderItems(ns: Int) -> [MedalItem] {
        (0..<3).map { index in
            var item = MedalItem()
            item.medalId = "placeholder-\(ns)-\(index)"
            return item
        }
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
