import Charts
import SwiftUI

/// 详情页通用卡面：统一圆角、无阴影。
struct InfoCard<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        }
    }
}

/// 榜 / 分类切换胶囊。
struct PillTabsView: View {
    let titles: [String]
    let selected: Int
    var errorIndexes: Set<Int> = []
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(titles.indices, id: \.self) { index in
                    let isSelected = index == selected
                    let isError = errorIndexes.contains(index)
                    Button {
                        onSelect(index)
                    } label: {
                        Text(titles[index])
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(isSelected ? Color.white : (isError ? Color.red : Color.primary))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background {
                                Capsule().fill(
                                    isSelected
                                    ? Color.accentColor
                                    : Color(uiColor: .tertiarySystemFill)
                                )
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
        }
    }
}

/// 详情页顶部人物条。
struct MemberHeaderBar: View {
    let name: String
    let pic: String
    var subtitle: String = ""
    var trailing: String = ""

    var body: some View {
        HStack(spacing: 12) {
            AvatarCircle(urlString: pic, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(name.isEmpty ? "未知成员" : name)
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            if !trailing.isEmpty {
                Text(trailing)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        }
    }
}

/// 勋章小格。
struct MedalTileCell: View {
    let item: MedalItem

    private var height: CGFloat = 74

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemFill))
                if let url = URL(string: item.picUrl), !item.picUrl.isEmpty {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit()
                                .opacity(item.unlocked ? 1 : 0.55)
                        } else {
                            ProgressView()
                        }
                    }
                    .padding(6)
                } else {
                    placeholder
                }
                if !item.unlocked {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.32))
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(height: height)

            Text(item.name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if !item.subtitle.isEmpty {
                Text(item.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    private var placeholder: some View {
        Image(systemName: "medal.fill")
            .font(.system(size: 18))
            .foregroundStyle(.secondary)
    }
}

/// 勋章三列格。
struct MedalTileGrid: View {
    let items: [MedalItem]
    let onTap: (MedalItem) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(items, id: \.self) { item in
                Button {
                    onTap(item)
                } label: {
                    MedalTileCell(item: item)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
