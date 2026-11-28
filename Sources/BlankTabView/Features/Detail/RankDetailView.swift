import SwiftUI
import UIKit

/// 榜单详情：系统电话「最近通话」式列表（原生 List，不画卡片），页面底色统一分组灰。
struct RankDetailView: View {
    @StateObject private var model: RankDetailModel
    /// 点榜单成员 → 该成员的「已获得奖章」；响应里的 ItemID 与家族成员 ID 同源。
    @State private var openedMember: Member?

    init(
        memberId: String,
        scheme: String,
        title: String,
        tabName: String,
        weekTabName: String = "",
        monthTabName: String = ""
    ) {
        _model = StateObject(
            wrappedValue: RankDetailModel(
                memberId: memberId,
                scheme: scheme,
                title: title,
                tabName: tabName,
                weekTabName: weekTabName,
                monthTabName: monthTabName
            )
        )
    }

    /// 工具栏 tab 只显示前三个；第三个标签固定叫「总榜」。
    private var tabTitles: [String] {
        Array(model.tabs.prefix(3).enumerated()).map { index, item in
            index == 2 ? "总榜" : Fmt.cleanTabName(item.name)
        }
    }

    /// 当前选中榜在前三个标签里的下标。
    private var tabIndex: Int {
        guard let current = model.tab,
              let index = model.tabs.firstIndex(where: { $0.id == current.id }) else { return 0 }
        return min(index, 2)
    }

    private var headerSubtitle: String {
        let artist = model.member.artistName.trimmingCharacters(in: .whitespacesAndNewlines)
        let listName = model.tab.map { Fmt.cleanTabName($0.name) } ?? model.title
        return artist.isEmpty ? listName : "\(artist)的\(listName)"
    }

    /// 「最近通话」行的内边距：左右与成员信息对齐。
    private let rowInsets = EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)

    var body: some View {
        List {
            MemberSectionHeader(
                title: model.member.title,
                pic: model.member.pic,
                subtitle: headerSubtitle,
                count: "\(model.rankProgress)",
                countValue: model.rankProgress,
                unit: "名",
                label: "名次"
            )
            .listRowInsets(rowInsets)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            // 榜名已由导航栏标题承担，不再放灰色分节标题。
            rows
        }
        .listStyle(.plain)
        .contentMargins(.top, 0, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationDestination(item: $openedMember) { member in
            MedalsHallView(memberId: member.itemId, seedMember: member)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if model.tabs.count > 1 {
                    RankTabBar(titles: tabTitles, selectedIndex: tabIndex) { index in
                        guard tabTitles.indices.contains(index), model.tabs.indices.contains(index) else { return }
                        let target = model.tabs[index]
                        Task { await model.select(target) }
                    }
                    // 顶到工具栏最右侧（去掉系统默认的尾部留白）。
                    .padding(.trailing, -16)
                }
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .task { await model.load() }
        .refreshable { await model.load() }
    }

    @ViewBuilder
    private var rows: some View {
        if model.items.isEmpty {
            // 还没有任何数据时也复用同一套榜行，只是喂空数据；不再有单独的状态提示页。
            ForEach(0..<(model.loading ? 8 : 0), id: \.self) { _ in
                RankMemberRow(item: RankMember())
                    .listRowBackground(Color.clear)
            }
        } else {
            ForEach(Array(model.items.prefix(model.visibleCount).enumerated()), id: \.offset) { _, item in
                RankMemberRow(item: item)
                    .listRowBackground(Color.clear)
                    .contentShape(Rectangle())
                    .onAppear { model.revealMoreIfNeeded(after: item) }
                    .onTapGesture { openedMember = seedMember(for: item) }
            }
        }
    }

    /// 用榜行数据做成员卡片入参，避免陌生成员落到「用户」占位。
    private func seedMember(for item: RankMember) -> Member? {
        let id = item.itemId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return nil }
        var member = AppServices.shared.member(id)
        if member.title.isEmpty || member.title == "用户" {
            member = Member(itemId: id, title: item.title, pic: item.pic)
        }
        return member
    }
}

/// 榜单行：头像在最左，右侧依次是名次与三行文本；最右是实心爱心与心动数。
struct RankMemberRow: View {
    let item: RankMember

    private var name: String { item.title.isEmpty ? " " : item.title }
    private var wears: [String] { item.wearTexts.filter { !$0.isEmpty } }
    private var honors: [String] { item.honorTexts.filter { !$0.isEmpty } }
    /// 称号胶囊高度：始终等于同排铭牌文字的实际高度（随语义字号自动变化）。
    @State private var plateHeight: CGFloat = 0
    /// 点赞数弹窗：1 万及以上点开显示完整数值。
    @State private var showExactPraise = false
    /// 没有铭牌时的兜底高度：说明（caption）语义字号的行高，随动态字体缩放。
    @ScaledMetric(relativeTo: .caption) private var captionHeight: CGFloat = 15

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // 头像贴最左；行内边距与分隔线缩进全部交给系统默认（系统会避让前导图）。
            AvatarCircle(urlString: item.pic, size: 48, showsRing: false)

            // 名次在头像右侧：与成员名字同一语义字号（subheadline + bold），数字横向居中。
            Text(item.position > 0 ? "\(item.position)" : "–")
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.primary)
                .frame(width: 28)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 3) {
                // 第一行：成员名字（iOS 副标题语义字号 subheadline，字重 bold）。
                Text(name)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)

                // 第二行：称号（WearList 的 Title，caption2 最小说明、默认字重，长条胶囊包裹，
                //         胶囊高度跟随铭牌文字高度）在前，铭牌（限定编号 NO.xxxx，caption 说明语义 + semibold，无底色）在后。
                if !wears.isEmpty || !honors.isEmpty {
                    HStack(alignment: .center, spacing: 6) {
                        ForEach(honors, id: \.self) { honor in
                            Text(honor)
                                .font(.caption2)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .frame(height: plateHeight > 0 ? plateHeight : captionHeight)
                                .background(Color(.tertiarySystemFill), in: Capsule())
                        }
                        ForEach(wears, id: \.self) { wear in
                            Text(wear)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear.preference(key: PlateHeightKey.self, value: geo.size.height)
                                    }
                                )
                        }
                    }
                    .lineLimit(1)
                    .onPreferenceChange(PlateHeightKey.self) { height in
                        if height > 0 { plateHeight = height }
                    }
                }

                // 第三行：原来的副文案（DescList，caption2 最小说明字号）。
                if !item.descTexts.isEmpty {
                    Text(item.descTexts.joined(separator: "  "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            // 心动数：实心爱心在上、数字在下方，数字用 caption（说明）语义字号。
            VStack(spacing: 2) {
                Image(systemName: "heart.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(item.isPraised ? Color.red : Color.secondary)
                    .contentShape(Rectangle())
                    .onTapGesture { revealExactPraise() }

                Text(item.praiseNum > 0 ? RankPraise.short(item.praiseNum) : " ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentShape(Rectangle())
                    .onTapGesture { revealExactPraise() }
                    .popover(isPresented: $showExactPraise, arrowEdge: .top) {
                        Text(RankPraise.exact(item.praiseNum))
                            .font(.footnote.monospacedDigit())
                            .padding(12)
                            .presentationCompactAdaptation(.popover)
                    }
            }
        }
    }

    /// 1 万及以上才弹具体数值；不足 1 万数字本身就是完整值，不弹。
    private func revealExactPraise() {
        if item.praiseNum >= 10000 { showExactPraise = true }
    }
}

#Preview {
    NavigationStack {
        RankDetailView(memberId: "12345", scheme: "https://i2.y.qq.com/x?a=1", title: "周榜", tabName: "周榜")
    }
}

private struct PlateHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
