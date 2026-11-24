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
        self.member = AppServices.shared.member(memberId)
    }

    func stop() { flag.on = false }

    var displayTotal: Int { total > 0 ? total : skins.count }

    /// 头部副标题：「艺人名字」+「的乐迷皮肤」。
    var headerSubtitle: String {
        let artist = artistName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !artist.isEmpty { return "\(artist)的乐迷皮肤" }
        let fallback = member.artistName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fallback.isEmpty { return "\(fallback)的乐迷皮肤" }
        return "乐迷皮肤"
    }

    func load() async {
        let cached = services.medals.cachedSkins(medalId)
        skins = cached
        total = cached.count
        scanning = true
        error = nil

        // 与成员卡片同一口径：优先用接口返回的皮肤总数。
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
            uin: memberId,
            isActive: { flagRef.on },
            onUpdate: { [weak self] list in
                Task { @MainActor in self?.skins = list }
            }
        )
        scanning = false
    }

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

// MARK: - View

struct SkinsView: View {
    @StateObject private var model: SkinsModel
    @State private var selectedSkin: SkinItem?
    @State private var selectedSeries = ""
    @Namespace private var zoomNS

    init(memberId: String, medalId: String, medalName: String, scheme: String) {
        _model = StateObject(
            wrappedValue: SkinsModel(memberId: memberId, medalId: medalId, medalName: medalName, scheme: scheme)
        )
    }

    var body: some View {
        List {
            Section {
                MemberSectionHeader(
                    title: model.member.title,
                    pic: model.member.pic,
                    subtitle: model.headerSubtitle,
                    count: "\(model.displayTotal)",
                    unit: "款"
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
            .listRowBackground(Color.clear)

            if model.groups.isEmpty {
                stateRow
            } else {
                ForEach(model.groups) { group in
                    Section {
                        HStack(spacing: 6) {
                            Text(group.name)
                                .font(.system(size: 16, weight: .semibold))
                            Spacer(minLength: 8)
                            Text("\(group.unlockedCount)/\(group.skins.count)")
                                .font(.system(size: 14))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            // 只有箭头可点：整行不再响应点击。
                            NavigationLink(value: route(for: group)) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 44, height: 44, alignment: .trailing)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .listRowSeparator(.hidden)

                        SkinTileGrid(items: Array(group.skins.prefix(3)), zoomNamespace: zoomNS) { skin in
                            selectedSeries = group.name
                            selectedSkin = skin
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 14, trailing: 16))
                        .listRowSeparator(.hidden)
                    }
                }

                if model.scanning {
                    scanningRow
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .navigationTitle(model.medalName.isEmpty ? "乐迷皮肤" : model.medalName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .onDisappear { model.stop() }
        .sheet(item: $selectedSkin) { skin in
            SkinDetailSheet(
                skin: skin,
                seriesName: selectedSeries,
                uin: model.memberId,
                zoomNamespace: zoomNS
            )
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

    @ViewBuilder
    private var stateRow: some View {
        if model.scanning {
            StateNotice(title: "正在深度扫描乐迷皮肤…", progress: true)
                .listRowBackground(Color.clear)
        } else {
            StateNotice(title: "未找到乐迷皮肤数据", message: model.error)
                .listRowBackground(Color.clear)
        }
    }

    private var scanningRow: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text("正在深度扫描乐迷皮肤…")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .listRowBackground(Color.clear)
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
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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
