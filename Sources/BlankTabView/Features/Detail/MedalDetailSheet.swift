import SwiftUI
import UIKit

/// 勋章详情：和皮肤详情共用同一套弹窗外壳；同一枚勋章有多个分级时，弹窗内左右滑动切换。
struct MedalDetailSheet: View {
    let memberId: String
    let target: MedalSheetTarget
    var zoomNamespace: Namespace.ID? = nil
    /// 截图 / 调试时直接喂分级数据，跳过网络。
    var demoLevels: [MedalLevel]? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var levels: [MedalLevel] = []
    @State private var index = 0

    /// 每页数据：没有接口数据时用点击进来的那一枚兜底。
    private var pages: [MedalLevel] {
        if levels.isEmpty {
            var fallback = MedalLevel()
            fallback.name = target.medalName
            fallback.picUrl = target.imageUrl
            fallback.createTime = target.date
            return [fallback]
        }
        return levels
    }

    private var current: MedalLevel {
        pages.indices.contains(index) ? pages[index] : pages[0]
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 8) {
                TabView(selection: $index) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { offset, level in
                        MedalLevelPage(level: level, fallbackURL: offset == 0 ? target.imageUrl : "")
                            .tag(offset)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(current.name.isEmpty ? target.medalName : current.name)
                        .font(.system(size: 19, weight: .bold))
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(text(for: current))
                        if pages.count > 1 {
                            Text("第 \(index + 1)/\(pages.count) 级")
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle(target.medalName.isEmpty ? "勋章详情" : target.medalName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: target.medalName) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        // 和皮肤详情完全同一套外壳：369 固定高度、禁用玻璃、圆角全程保持。
        .detailSheetChrome(height: 369)
        .zoomNavigationTransitionIfAvailable(id: target.medalId, in: zoomNamespace)
        .task { await load() }
    }

    private func text(for level: MedalLevel) -> String {
        var pieces: [String] = []
        let raw = level.createTime.isEmpty ? target.date : level.createTime
        if let date = Fmt.compact(raw).nilIfEmpty { pieces.append(date) }
        if level.owned { pieces.append("已获得") }
        return pieces.isEmpty ? "--" : pieces.joined(separator: "  ")
    }

    private func load() async {
        if let demoLevels, !demoLevels.isEmpty {
            levels = demoLevels.sorted { $0.level < $1.level }
            index = 0
            return
        }
        do {
            let detail = try await AppServices.shared.medals.detail(
                AppServices.shared.hallURL(memberId),
                medalId: target.medalId,
                encUin: memberId
            )
            var filtered = detail.levels.filter { !$0.picUrl.isEmpty }
            if filtered.contains(where: { $0.medalId == target.medalId }) {
                filtered = filtered.filter { $0.medalId == target.medalId || $0.medalId.isEmpty }
            }
            guard !filtered.isEmpty else { return }
            let sorted = filtered.sorted { $0.level < $1.level }
            levels = sorted
            // 默认停在点击进来的那一级（接口有对应 medalId 就用它，否则停最高级）。
            if let hit = sorted.firstIndex(where: { $0.medalId == target.medalId && !target.medalId.isEmpty }) {
                index = hit
            } else {
                index = max(0, sorted.count - 1)
            }
        } catch {
            // 取不到分级就只显示点击的那一枚。
        }
    }
}

/// 单级勋章：图片（固定 280 高、圆角 28），仅此一页。
private struct MedalLevelPage: View {
    let level: MedalLevel
    let fallbackURL: String

    @State private var image: UIImage?

    private var url: String { level.picUrl.isEmpty ? fallbackURL : level.picUrl }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: url) {
            guard !url.isEmpty else { return }
            image = await RemoteImageLoader.image(for: url)
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
