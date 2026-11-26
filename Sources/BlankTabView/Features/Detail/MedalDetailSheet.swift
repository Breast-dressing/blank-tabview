import SwiftUI
import UIKit

/// 奖章详情：与皮肤详情完全同一套弹窗外壳、媒体高度、两行文本与「打开」按钮。
/// 同一枚勋章有多个分级时，弹窗内左右滑动切换，编号随当前分级变化。
struct MedalDetailSheet: View {
    let memberId: String
    let target: MedalSheetTarget
    var zoomNamespace: Namespace.ID? = nil
    /// 截图 / 调试时直接喂分级数据，跳过网络。
    var demoLevels: [MedalLevel]? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var levels: [MedalLevel] = []
    @State private var numbers = MedalDetailNumbers()
    @State private var index = 0

    /// 每页数据：没有接口数据时用点击进来的那一枚兜底。
    private var pages: [MedalLevel] {
        if levels.isEmpty {
            var fallback = MedalLevel()
            fallback.name = target.medalName
            fallback.picUrl = target.imageUrl
            fallback.createTime = target.date
            fallback.medalId = target.medalId
            return [fallback]
        }
        return levels
    }

    private var current: MedalLevel {
        pages.indices.contains(index) ? pages[index] : pages[0]
    }

    /// 限量编号：只认 OldMedalDetail.MedalList[*].NumberInfo.Content；
    /// 接口还没回来时先用列表卡带过来的同一个字段（demo 也走这条）。
    private var numberText: String {
        let fromDetail = numbers.number(for: current.medalId)
        if !fromDetail.isEmpty { return fromDetail }
        return MedalDetailNumbers.clean(target.number)
    }

    private var dateText: String {
        let raw = current.createTime.isEmpty ? target.date : current.createTime
        // 日期字段里误塞了编号时，不当日期用。
        if raw.hasPrefix("NO.") { return "" }
        return Fmt.compact(raw)
    }

    /// 没有限定编号时，获得时间顶到编号位。
    private var primaryText: String {
        if !numberText.isEmpty { return numberText }
        return dateText.isEmpty ? "-" : dateText
    }

    /// 第二行：有编号时显示获得时间，再加上分级信息。
    private var secondaryText: String {
        var pieces: [String] = []
        if !numberText.isEmpty && !dateText.isEmpty { pieces.append(dateText) }
        if pages.count > 1 { pieces.append("第 \(index + 1)/\(pages.count) 级") }
        return pieces.isEmpty ? "--" : pieces.joined(separator: "  ")
    }

    private var openURL: URL? {
        URL(string: target.scheme)
    }

    var body: some View {
        NavigationStack {
            DetailSheetContent(
                primary: primaryText,
                secondary: secondaryText,
                onOpen: open
            ) {
                TabView(selection: $index) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { offset, level in
                        MedalLevelPage(level: level, fallbackURL: offset == 0 ? target.imageUrl : "")
                            .tag(offset)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
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
        .detailSheetChrome(height: DetailSheetMetrics.height, cornerRadius: 36)
        .zoomNavigationTransitionIfAvailable(id: target.medalId, in: zoomNamespace)
        .task { await load() }
    }

    private func open() {
        guard let openURL else { return }
        UIApplication.shared.open(openURL)
    }

    /// 分级排序后默认停在「已解锁的最高等级」上。
    private func apply(_ raw: [MedalLevel]) {
        let sorted = raw.sorted { $0.level < $1.level }
        guard !sorted.isEmpty else { return }
        levels = sorted
        index = sorted.lastIndex(where: { $0.state == 2 }) ?? 0
    }

    private func load() async {
        if let demoLevels, !demoLevels.isEmpty {
            apply(demoLevels)
            return
        }
        guard !target.medalId.isEmpty else { return }
        do {
            let info = try await AppServices.shared.api.fetchMedalDetailNumbers(
                medalId: target.medalId,
                encUin: memberId
            )
            numbers = info
            apply(info.levels.filter { !$0.picUrl.isEmpty })
        } catch {
            // 取不到分级就只显示点击的那一枚（编号仍可用列表卡带来的）。
        }
    }
}

/// 单级勋章：只负责图，尺寸由弹窗骨架统一给。
private struct MedalLevelPage: View {
    let level: MedalLevel
    let fallbackURL: String

    @State private var image: UIImage?

    private var url: String { level.picUrl.isEmpty ? fallbackURL : level.picUrl }

    var body: some View {
        DetailSheetImage(image: image)
            .task(id: url) {
                guard !url.isEmpty else { return }
                image = await RemoteImageLoader.image(for: url)
            }
    }
}
