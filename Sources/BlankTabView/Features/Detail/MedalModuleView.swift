import SwiftUI

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

    init(memberId: String, moduleId: String, moduleName: String, tabName: String) {
        self.memberId = memberId
        self.moduleId = moduleId
        self.moduleName = moduleName
        self.tabName = tabName
        self.member = AppServices.shared.member(memberId)
    }

    func load() async {
        loading = true
        error = nil
        do {
            let page = try await services.medals.modulePage(
                url: services.hallURL(memberId),
                moduleId: moduleId,
                moduleName: moduleName,
                pageSize: 50
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

    func loadMore() async {
        guard hasNext, !loadingMore else { return }
        loadingMore = true
        do {
            let page = try await services.medals.modulePage(
                url: services.hallURL(memberId),
                moduleId: moduleId,
                moduleName: moduleName,
                lastPos: lastPos,
                pageSize: 21
            )
            items.append(contentsOf: page.module.items)
            hasNext = page.hasNext
            lastPos = page.lastPos
        } catch {
            hasNext = false
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
            date: item.createTime.isEmpty ? item.cornerTitle : item.createTime
        )
        return nil
    }
}

// MARK: - View

struct MedalModuleView: View {
    @StateObject private var model: MedalModuleModel
    @State private var pendingPush: ProfileDestination?

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
        DetailScroll {
            MemberHeaderBar(
                name: model.member.title,
                pic: model.member.pic,
                subtitle: "勋章馆 · \(Fmt.cleanTabName(model.tabName))"
            )

            if model.loading {
                StateNotice(title: "正在读取模块…", progress: true)
            } else if let error = model.error {
                StateNotice(title: "模块加载失败", message: error, actionTitle: "重试") {
                    Task { await model.load() }
                }
            } else if model.items.isEmpty {
                StateNotice(title: "这个模块还没有勋章")
            } else {
                MedalTileGrid(items: model.items) { item in
                    if let route = model.openTile(item) {
                        pendingPush = route
                    }
                }

                if model.hasNext {
                    Button {
                        Task { await model.loadMore() }
                    } label: {
                        HStack(spacing: 6) {
                            if model.loadingMore { ProgressView() }
                            Text(model.loadingMore ? "正在加载…" : "加载更多")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.loadingMore)
                }
            }
        }
        .navigationTitle(model.moduleName.isEmpty ? "模块详情" : model.moduleName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .sheet(item: $model.sheetTarget) { target in
            MedalDetailSheet(memberId: model.memberId, target: target)
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
