import SwiftUI
import UIKit

/// 勋章详情：和皮肤详情完全同一套弹窗（原生 sheet、禁用玻璃、隐藏抓手、内容不滚动、左上 × / 右上分享）。
struct MedalDetailSheet: View {
    let memberId: String
    let target: MedalSheetTarget
    var zoomNamespace: Namespace.ID? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var levelName = ""
    @State private var dateText = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 8) {
                imageView

                VStack(alignment: .leading, spacing: 4) {
                    Text(levelName.isEmpty ? target.medalName : levelName)
                        .font(.system(size: 19, weight: .bold))
                        .lineLimit(1)

                    Text(dateText.isEmpty ? "--" : dateText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(uiColor: .systemGroupedBackground))
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
        // 内容高度就是弹窗高度，底部不留空白。
        .presentationSizing(.fitted)
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color(uiColor: .systemGroupedBackground))
        .presentationCornerRadius(36)
        .zoomNavigationTransitionIfAvailable(id: target.medalId, in: zoomNamespace)
        .task { await load() }
    }

    private var picURL: String { target.imageUrl }

    private var imageView: some View {
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
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .task(id: picURL) {
            guard !picURL.isEmpty else { return }
            image = await RemoteImageLoader.image(for: picURL)
        }
    }

    private func load() async {
        dateText = Fmt.compact(target.date)
        guard target.imageUrl.isEmpty else { return }
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
            if let first = filtered.sorted(by: { $0.level < $1.level }).last {
                levelName = first.name
                if dateText.isEmpty { dateText = Fmt.compact(first.createTime) }
                if let loaded = await RemoteImageLoader.image(for: first.picUrl) {
                    image = loaded
                }
            }
        } catch {
            // 图片取不到就显示占位，不额外提示。
        }
    }
}
