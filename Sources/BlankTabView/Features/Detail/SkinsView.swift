import SwiftUI
import UIKit

/// 皮肤扫描的“页面还在”标志。
final class ScanFlag: @unchecked Sendable {
    var on = true
}

struct SkinSeriesGroup: Identifiable {
    let name: String
    let skins: [SkinItem]
    let categKey: String

    var id: String { name }
    var unlockedCount: Int { skins.filter { $0.isUnlocked }.count }
}

// MARK: - Model

@MainActor
final class SkinsModel: ObservableObject {
    private let services = AppServices.shared
    private let flag = ScanFlag()

    let memberId: String
    let medalId: String
    let medalName: String
    let scheme: String
    /// 是否是展示成员（本人）的勋章：只有本人的勋章才记录「无皮肤序号」。
    let isOwner: Bool

    @Published private(set) var skins: [SkinItem] = []
    @Published private(set) var total = 0
    @Published private(set) var scanning = true
    @Published private(set) var error: String?
    @Published private(set) var member: Member
    @Published private(set) var artistName = ""

    init(memberId: String, medalId: String, medalName: String, scheme: String) {
        self.memberId = memberId
        self.medalId = medalId
        self.medalName = medalName
        self.scheme = scheme
        let canonical = MemberId.canonical(memberId)
        self.isOwner = !canonical.isEmpty && canonical == AppServices.shared.store.selectedMemberId
        self.member = AppServices.shared.member(memberId)
    }

    func stop() { flag.on = false }

    var displayTotal: Int { total > 0 ? total : skins.count }

    var headerSubtitle: String {
        let artist = artistName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !artist.isEmpty { return "\(artist)的乐迷皮肤" }
        let fallback = member.artistName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fallback.isEmpty { return "\(fallback)的乐迷皮肤" }
        return "乐迷皮肤"
    }

    func load() async {
        // 仅 CI 截图核对用：-demoSkins 直接喂演示数据。
        if ProcessInfo.processInfo.arguments.contains("-demoSkins") {
            skins = Self.demoSkins
            total = skins.count
            scanning = false
            error = nil
            return
        }

        let cached = services.medals.cachedSkins(medalId, memberId: memberId)
        skins = cached
        total = cached.count
        scanning = true
        error = nil

        if let list = try? await services.medals.skinTotal(medalId: medalId, encUin: memberId) {
            total = list.total > 0 ? list.total : list.skins.count
        }

        do {
            let detail = try await services.medals.detail(
                services.hallURL(memberId),
                medalId: medalId,
                encUin: memberId
            )
            if let fan = detail.fan, !fan.name.isEmpty { artistName = fan.name }
        } catch {
            self.error = error.localizedDescription
        }

        let flagRef = flag
        await services.medals.scanSkins(
            medalId: medalId,
            medalName: medalName.isEmpty ? medalId : medalName,
            uin: memberId,
            isOwner: isOwner,
            isActive: { flagRef.on },
            onUpdate: { [weak self] list in
                Task { @MainActor in self?.skins = list }
            }
        )
        scanning = false
    }

    /// 演示数据（仅 -demoSkins 截图用）。
    static let demoSkins: [SkinItem] = {
        var list: [SkinItem] = []
        for series in 1...3 {
            for index in 1...3 {
                var skin = SkinItem()
                skin.id = "demo-\(series)-\(index)"
                skin.seq = index
                skin.name = "\(series * 10)日徽章\(index)"
                skin.categId = "\(series)"
                skin.seqNo = "\(series * 10)日徽章\(index)"
                skin.unlockedDate = "2025-12-0\(index)"
                skin.userCount = 18033
                skin.isUnlocked = index != 3
                list.append(skin)
            }
        }
        return list
    }()

    var groups: [SkinSeriesGroup] {
        var buckets: [String: [SkinItem]] = [:]
        for skin in skins {
            let raw = skin.categId.trimmingCharacters(in: .whitespaces)
            let key = (raw.isEmpty || raw == "0" || raw.lowercased() == "other") ? "other" : raw
            buckets[key, default: []].append(skin)
        }
        let groups = buckets.map { key, list in
            SkinSeriesGroup(
                name: key == "other" ? "其他系列" : "系列 \(key)",
                skins: list.sorted { $0.seq < $1.seq },
                categKey: key
            )
        }
        return groups.sorted { lhs, rhs in
            if lhs.categKey == "other" { return false }
            if rhs.categKey == "other" { return true }
            let left = Int(lhs.categKey) ?? Int.max
            let right = Int(rhs.categKey) ?? Int.max
            if left == right { return lhs.categKey < rhs.categKey }
            return left < right
        }
    }
}

// MARK: - 乐迷皮肤页

struct SkinsView: View {
    @StateObject private var model: SkinsModel
    @State private var selectedSkin: SkinItem?
    @State private var selectedSeries = ""
    @State private var pendingSeries: ProfileDestination?
    /// 刚关掉弹窗的 0.4 秒内不接收新的点击，避免关闭动画中再开另一个弹窗。
    @State private var dismissLock = false
    @Namespace private var zoomNS

    init(memberId: String, medalId: String, medalName: String, scheme: String) {
        _model = StateObject(
            wrappedValue: SkinsModel(memberId: memberId, medalId: medalId, medalName: medalName, scheme: scheme)
        )
    }

    var body: some View {
        DetailPageScaffold(
            header: MemberSectionHeader(
                title: model.member.title,
                pic: model.member.pic,
                subtitle: model.headerSubtitle,
                count: "\(model.displayTotal)",
                unit: "款"
            )
        ) {
            if model.groups.isEmpty {
                // 加载中 / 暂无数据都复用同一套卡片 UI，只喂占位项。
                ForEach(0..<2, id: \.self) { index in
                    DetailSeriesCard(title: "") {
                        SkinTileGrid(items: Self.placeholderSkins(ns: index), zoomNamespace: nil) { _ in }
                    }
                }
            } else {
                ForEach(model.groups) { group in
                    DetailSeriesCard(
                        title: group.name,
                        trailing: "已收集 \(group.unlockedCount)/\(group.skins.count)",
                        onTrailingTap: { pendingSeries = route(for: group) }
                    ) {
                        SkinTileGrid(items: Array(group.skins.prefix(3)), zoomNamespace: zoomNS) { skin in
                            guard !dismissLock else { return }
                            selectedSeries = group.name
                            selectedSkin = skin
                        }
                    }
                }
            }
        }
        .navigationTitle(model.medalName.isEmpty ? "乐迷皮肤" : model.medalName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .onDisappear { model.stop() }
        .navigationDestination(isPresented: Binding(
            get: { pendingSeries != nil },
            set: { if !$0 { pendingSeries = nil } }
        )) {
            if let route = pendingSeries {
                pushDestination(route)
            }
        }
        .sheet(item: $selectedSkin, onDismiss: unlockDelay) { skin in
            SkinDetailSheet(
                skin: skin,
                seriesName: selectedSeries,
                uin: model.memberId,
                zoomNamespace: zoomNS
            )
        }
    }

    static func placeholderSkins(ns: Int) -> [SkinItem] {
        (0..<3).map { index in
            var skin = SkinItem()
            skin.id = "placeholder-\(ns)-\(index)"
            return skin
        }
    }

    /// 弹窗关闭后短暂锁一下，避免快速点另一个皮肤时新弹窗高度被旧弹窗动画打断。
    private func unlockDelay() {
        dismissLock = true
        Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            dismissLock = false
        }
    }

    @ViewBuilder
    private func pushDestination(_ route: ProfileDestination) -> some View {
        switch route {
        case let .skinSeries(member, artistName, seriesName, skins):
            SkinSeriesView(member: member, artistName: artistName, seriesName: seriesName, skins: skins)
        default:
            EmptyView()
        }
    }

    private func route(for group: SkinSeriesGroup) -> ProfileDestination {
        .skinSeries(
            member: model.member,
            artistName: model.artistName,
            seriesName: group.name,
            skins: group.skins
        )
    }
}

// MARK: - 乐迷皮肤系列页（与乐迷皮肤页同一套 UI，只是只有一组卡片）

struct SkinSeriesPage: View {
    let member: Member
    let artistName: String
    let seriesName: String
    let skins: [SkinItem]
    let uin: String

    @State private var selectedSkin: SkinItem?
    @State private var dismissLock = false
    @Namespace private var zoomNS

    private var unlockedCount: Int { skins.filter { $0.isUnlocked }.count }

    private var headerSubtitle: String {
        let artist = artistName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = member.artistName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = artist.isEmpty ? fallback : artist
        return name.isEmpty ? seriesName : "\(name)的\(seriesName)"
    }

    var body: some View {
        DetailPageScaffold(
            header: MemberSectionHeader(
                title: member.title,
                pic: member.pic,
                subtitle: headerSubtitle,
                count: "\(unlockedCount)",
                unit: "款"
            )
        ) {
            if skins.isEmpty {
                StateNotice(title: "这个系列还没有皮肤")
                    .padding(.horizontal, 16)
            } else {
                DetailSeriesCard(title: seriesName) {
                    SkinTileGrid(items: skins.sorted { $0.seq < $1.seq }, zoomNamespace: zoomNS) { skin in
                        guard !dismissLock else { return }
                        selectedSkin = skin
                    }
                }
            }
        }
        .navigationTitle(seriesName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedSkin, onDismiss: unlockDelay) { skin in
            SkinDetailSheet(
                skin: skin,
                seriesName: seriesName,
                uin: uin,
                zoomNamespace: zoomNS
            )
        }
    }

    private func unlockDelay() {
        dismissLock = true
        Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            dismissLock = false
        }
    }
}

/// 皮肤卡：透明圆角矩形包住图片 / 名字 / 日期，同时作为 zoom 过渡的出发点。
struct SkinTileCell: View {
    let skin: SkinItem
    @State private var image: UIImage?

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .saturation(skin.isUnlocked ? 1 : 0)
                        .opacity(skin.isUnlocked ? 1 : 0.55)
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 86)
            .task(id: skin.pic) {
                image = await RemoteImageLoader.image(for: skin.pic)
            }

            Text(skin.name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(skin.isUnlocked ? skin.subtitle : "待解锁")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(height: 13)
        }
    }
}

/// 皮肤三列格。整块（图片 + 名字 + 日期）包在透明圆角矩形里，zoom 挂在这块矩形上。
struct SkinTileGrid: View {
    let items: [SkinItem]
    var zoomNamespace: Namespace.ID? = nil
    let onTap: (SkinItem) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(items, id: \.self) { skin in
                Button {
                    onTap(skin)
                } label: {
                    SkinTileCell(skin: skin)
                        .padding(6)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.clear)
                )
                .matchedTransitionSourceIfAvailable(id: skin.id, in: zoomNamespace)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SkinsView(memberId: "12345", medalId: "3069960", medalName: "虞书欣乐迷", scheme: "")
    }
}
