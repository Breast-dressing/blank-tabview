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
        VStack(alignment: .leading, spacing: 12, content: { content })
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

/// 成员条：头像 + 名字 + 副标题 + 右侧计数。
struct MemberHeaderBar: View {
    let name: String
    let pic: String
    var subtitle: String = ""
    var trailing: String = ""

    var body: some View {
        HStack(spacing: 12) {
            AvatarCircle(urlString: pic, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(name.isEmpty ? "用户" : name)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if !trailing.isEmpty {
                Text(trailing)
                    .font(.system(size: 15, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
    }
}

/// 勋章小格：图 + 名称 + 副标题，未解锁蒙层 + 锁。
struct MedalTileCell: View {
    let item: MedalItem
    var height: CGFloat = 64

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemFill))
                if let url = URL(string: item.picUrl), !item.picUrl.isEmpty {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit()
                        } else {
                            placeholder
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

/// 三列勋章格。
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

/// 逐日柱状图。
struct DailyBars: View {
    let values: [Double]
    let labels: [String]

    var body: some View {
        Chart(Array(values.indices), id: \.self) { index in
            BarMark(
                x: .value("日期", index < labels.count ? labels[index] : "\(index + 1)"),
                y: .value("荣誉值", values[index])
            )
            .foregroundStyle(Color.accentColor)
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks { _ in AxisValueLabel().font(.system(size: 10)) }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
                AxisValueLabel().font(.system(size: 10))
            }
        }
        .frame(height: 132)
    }
}

/// 描边行：左标签右值。
struct LabeledRow: View {
    let label: String
    let value: String
    var highlight: Bool = false
    var valueColor: Color = .primary
    var small: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)
            Text(value.isEmpty ? "-" : value)
                .font(.system(size: small ? 12 : 13.5, weight: highlight ? .semibold : .regular))
                .foregroundStyle(valueColor)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
    }
}

/// 加载 / 错误 / 空状态。
struct StateNotice: View {
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?
    var progress: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if progress { ProgressView() }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            if let message, !message.isEmpty {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        }
    }
}

/// “我”标记。
struct MeBadge: View {
    var body: some View {
        Text("我")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background { Capsule().fill(Color.accentColor) }
    }
}

/// 详情页统一滚动容器。
struct DetailScroll<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14, content: { content })
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
    }
}
