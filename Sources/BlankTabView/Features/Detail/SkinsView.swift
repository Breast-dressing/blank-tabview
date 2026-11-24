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

    func load() async {
        skins = services.medals.cachedSkins(medalId)
        scanning = true
        error = nil
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

    init(memberId: String, medalId: String, medalName: String, scheme: String) {
        _model = StateObject(
            wrappedValue: SkinsModel(memberId: memberId, medalId: medalId, medalName: medalName, scheme: scheme)
        )
    }

    var body: some View {
        DetailScroll {
            skinHeader

            if model.groups.isEmpty {
                if model.scanning {
                    StateNotice(title: "正在深度扫描乐迷皮肤…", progress: true)
                } else {
                    StateNotice(title: "未找到乐迷皮肤数据", message: model.error)
                }
            } else {
                ForEach(model.groups) { group in
                    seriesCard(group)
                }

                if model.scanning {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("正在深度扫描乐迷皮肤…")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(model.medalName.isEmpty ? "乐迷皮肤" : model.medalName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .onDisappear { model.stop() }
        .sheet(item: $selectedSkin) { skin in
            SkinDetailSheet(skin: skin, seriesName: selectedSeries, uin: model.memberId)
        }
    }

    /// 头部直接铺在页面里（不套卡片）：40 头像 + 名字 / 勋章名 + 右侧皮肤数量。
    private var skinHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            AvatarCircle(urlString: model.member.pic, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.member.title.isEmpty ? "未知成员" : model.member.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(model.medalName.isEmpty ? "乐迷皮肤" : model.medalName)
                    .font(.headline)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(model.skins.count)")
                        .font(.title3)
                    Text("枚")
                        .font(.subheadline)
                }
                Text("已获得")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func seriesCard(_ group: SkinSeriesGroup) -> some View {
        InfoCard(padding: 14) {
            NavigationLink(value: ProfileDestination.skinSeries(seriesName: group.name, skins: group.skins)) {
                HStack {
                    Text(group.name)
                        .font(.system(size: 16, weight: .semibold))
                    Text("\(group.skins.count)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            SkinTileGrid(items: Array(group.skins.prefix(3))) { skin in
                selectedSeries = group.name
                selectedSkin = skin
            }
        }
    }
}

/// 皮肤卡：大圆角卡片，不铺底色；加载中在整卡中心显示系统 ProgressView（无淡入动画）。
struct SkinTileCell: View {
    let skin: SkinItem
    @State private var image: UIImage?

    private let radius: CGFloat = 24

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 86)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .task(id: skin.pic) {
                image = await RemoteImageLoader.image(for: skin.pic)
            }

            Text(skin.name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if !skin.subtitle.isEmpty {
                Text(skin.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

/// 皮肤三列格。
struct SkinTileGrid: View {
    let items: [SkinItem]
    let onTap: (SkinItem) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(items, id: \.self) { skin in
                Button {
                    onTap(skin)
                } label: {
                    SkinTileCell(skin: skin)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SkinsView(memberId: "12345", medalId: "3069960", medalName: "虞书欣乐迷", scheme: "")
    }
}
