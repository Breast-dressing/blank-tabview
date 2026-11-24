import SwiftUI

/// 勋章详情（sheet）：同一勖章的各级别大图，可左右翻页。
struct MedalDetailSheet: View {
    let memberId: String
    let target: MedalSheetTarget

    @Environment(\.dismiss) private var dismiss
    @State private var levels: [MedalLevel] = []
    @State private var page = 0
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        NavigationStack {
            DetailScroll {
                if loading {
                    StateNotice(title: "正在读取勋章详情…", progress: true)
                } else if levels.isEmpty {
                    fallback
                } else {
                    TabView(selection: $page) {
                        ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                            levelView(level)
                                .tag(index)
                                .padding(.horizontal, 6)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: levels.count > 1 ? .automatic : .never))
                    .frame(height: 360)

                    if levels.count > 1 {
                        Text("\(page + 1) / \(levels.count) · 左右滑动查看其他等级")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle(target.medalName.isEmpty ? "勋章详情" : target.medalName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task { await load() }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
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
            levels = filtered.sorted { $0.level < $1.level }
        } catch {
            self.error = error.localizedDescription
            levels = []
        }
    }

    private func levelView(_ level: MedalLevel) -> some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                if let url = URL(string: level.picUrl) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit()
                        } else {
                            ProgressView()
                        }
                    }
                    .padding(14)
                }
            }
            .frame(maxHeight: .infinity)

            Text(Fmt.compact(level.createTime).isEmpty ? "--" : Fmt.compact(level.createTime))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            if !level.name.isEmpty {
                Text(level.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fallback: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                if let url = URL(string: target.imageUrl), !target.imageUrl.isEmpty {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit()
                        } else {
                            ProgressView()
                        }
                    }
                    .padding(14)
                } else {
                    Image(systemName: "medal").font(.system(size: 32)).foregroundStyle(.secondary)
                }
            }
            .frame(height: 260)

            Text(Fmt.compact(target.date).isEmpty ? "--" : Fmt.compact(target.date))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            if let error {
                StateNotice(title: "详情加载失败", message: error, actionTitle: "重试") {
                    Task { await load() }
                }
            }
        }
    }
}
