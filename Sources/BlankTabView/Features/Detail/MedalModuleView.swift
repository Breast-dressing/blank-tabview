import SwiftUI
import UIKit

// MARK: - Model

@MainActor
final class MedalModuleModel: ObservableObject {
    private let services = AppServices.shared

    let memberId: String
    let moduleId: String
    let moduleName: String
    let tabName: String

    @Published private(set) var items: [MedalItem] = []
    @Published private(set) var hasNext = false
    @Published private(set) var loading = true
    @Published private(set) var loadingMore = false
    @Published private(set) var error: String?
    @Published private(set) var member: Member
    @Published var sheetTarget: MedalSheetTarget?

    private var lastPos = ""
    private let pageSize = 21

    init(memberId: String, moduleId: String, moduleName: String, tabName: String) {
        self.memberId = memberId
        self.moduleId = moduleId
        self.moduleName = moduleName
        self.tabName = tabName
        self.member = AppServices.shared.member(memberId)
    }

    var unlockedCount: Int { items.filter { $0.attained }.count }

    /// 成员信息下方文案：「的 + 系列名」。
    var headerSubtitle: String {
        let artist = member.artistName.trimmingCharacters(in: .whitespacesAndNewlines)
        let series = moduleName.isEmpty ? "勋章馆" : moduleName
        return artist.isEmpty ? "的\(series)" : "\(artist)的\(series)"
    }

    func load() async {
        loading = true
        error = nil
        do {
            let page = try await services.medals.modulePage(
                url: services.hallURL(memberId),
                moduleId: moduleId,
                moduleName: moduleName,
                pageSize: pageSize
            )
            items = page.module.items
            hasNext = page.hasNext
            lastPos = page.lastPos
        } catch {
            self.error = error.localizedDescription
            items = []
        }
        loading = false
    }

    /// 划到底自动续拉：接口自带 HasNext / LastPos，直接翻页。
    func loadMoreIfNeeded() async {
        guard hasNext, !loadingMore, !loading else { return }
        loadingMore = true
        do {
            let page = try await services.medals.modulePage(
                url: services.hallURL(memberId),
                moduleId: moduleId,
                moduleName: moduleName,
                lastPos: lastPos,
                pageSize: pageSize
            )
            let existing = Set(items.map { $0.medalId })
            items.append(contentsOf: page.module.items.filter { !existing.contains($0.medalId) })
            hasNext = page.hasNext
            lastPos = page.lastPos
        } catch {
            hasNext = false
            self.error = error.localizedDescription
        }
        loadingMore = false
    }

    func openTile(_ item: MedalItem) -> ProfileDestination? {
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

struct MedalModuleView: View {
    @StateObject private var model: MedalModuleModel
    @State private var pendingPush: ProfileDestination?
    @Namespace private var zoomNS

    init(memberId: String, moduleId: String, moduleName: String, tabName: String) {
        _model = StateObject(
            wrappedValue: MedalModuleModel(
                memberId: memberId,
                moduleId: moduleId,
                moduleName: moduleName,
                tabName: tabName
            )
        )
    }

    var body: some View {
        DetailPageScaffold(
            header: MemberSectionHeader(
                title: model.member.title,
                pic: model.member.pic,
                subtitle: model.headerSubtitle,
                count: "\(model.unlockedCount)",
                unit: "枚"
            )
        ) {
            if model.loading {
                // 加载中复用同一套卡片 UI，只是喂占位项。
                DetailSeriesCard(title: "") {
                    ZoomedMedalTileGrid(items: MedalsHallView.placeholderItems(ns: 1), zoomNamespace: nil) { _ in }
                }
            } else if model.items.isEmpty {
                DetailPageNotice(StateNotice(title: "这个模块还没有勋章"))
            } else {
                DetailSeriesCard(title: model.moduleName.isEmpty ? "全部" : model.moduleName) {
                    ZoomedMedalTileGrid(
                        items: model.items,
                        zoomNamespace: zoomNS,
                        onLastAppear: {
                            // 划到最后一张自动续拉，不再放「加载更多」按钮。
                            Task { await model.loadMoreIfNeeded() }
                        }
                    ) { item in
                        if let route = model.openTile(item) {
                            pendingPush = route
                        }
                    }

                    if model.loadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                }
            }

            if let error = model.error, !model.loading {
                DetailPageNotice(
                    StateNotice(title: "模块加载失败", message: error, actionTitle: "重试") {
                        Task { await model.load() }
                    }
                )
            }
        }
        .navigationTitle(model.moduleName.isEmpty ? "模块详情" : model.moduleName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .sheet(item: $model.sheetTarget) { target in
            MedalDetailSheet(memberId: model.memberId, target: target, zoomNamespace: zoomNS)
        }
        .navigationDestination(isPresented: Binding(
            get: { pendingPush != nil },
            set: { if !$0 { pendingPush = nil } }
        )) {
            if let route = pendingPush, case let .skins(memberId, medalId, medalName, scheme) = route {
                SkinsView(memberId: memberId, medalId: medalId, medalName: medalName, scheme: scheme)
            }
        }
    }
}
