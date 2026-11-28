import SwiftUI

/// 榜单详情：成员信息 + 排行列表。
struct RankDetailView: View {
    let artist: ArtistItem?

    @StateObject private var model = RankDetailModel()
    @State private var tabIndex = 0
    @State private var member: RankMember?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                list
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .contentMargins(.top, 0, for: .scrollContent)
        .navigationTitle(member?.artistName ?? artist?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if model.tabs.count > 1 {
                    // 靠右显示：放在工具栏右侧位（标题位会被系统居中，无法靠右）。
                    RankTabBar(titles: tabTitles, selectedIndex: tabIndex) { index in
                        guard tabTitles.indices.contains(index), model.tabs.indices.contains(index) else { return }
                        let target = model.tabs[index]
                        Task { await model.select(target) }
                    }
                }
            }
        }
        .task { await model.load() }
        .refreshable { await model.load() }
    }

    @ViewBuilder
    private var header: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(.tertiary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("用户")
                        .font(.headline)
                    Text("周榜")
                        .font(.headline)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("3")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("名")
                            .font(.footnote)
                    }
                    Text("名次")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var list: some View {
        LazyVStack(spacing: 0) {
            if model.loading {
                ForEach(0..<8, id: \.self) { _ in
                    RankMemberRow(rank: 0, member: .placeholder, showsBadges: false)
                    Divider().padding(.leading, 16)
                }
            } else {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, item in
                    Button {
                        member = item
                    } label: {
                        RankMemberRow(
                            rank: index + 1,
                            member: item,
                            showsBadges: item.tags.isEmpty == false
                        )
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 16)
                }
            }
        }
    }

    private var rows: [RankMember] {
        model.members
    }
}
