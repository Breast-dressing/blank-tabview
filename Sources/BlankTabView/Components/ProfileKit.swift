import SwiftUI

/// 通用卡片容器。
struct InfoCard<Content: View>: View {
    var padding: CGFloat = 16
    let content: Content

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

/// 胶囊 Tab：用于榜单区间切换。
struct PillTabsView: View {
    let items: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items.indices, id: \.self) { index in
                Button {
                    selection = index
                } label: {
                    Text(items[index])
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selection == index ? Color.white : Color.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background {
                            Capsule()
                                .fill(selection == index ? Color.accentColor : Color(uiColor: .tertiarySystemFill))
                        }
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }
}

/// 详情页顶部的人物条。
struct MemberHeaderBar: View {
    let name: String
    let pic: String
    var subtitle: String = ""
    var trailing: String = ""

    var body: some View {
        HStack(spacing: 12) {
            AvatarCircle(urlString: pic, size: 46)
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
    let medal: MedalItem

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemFill))
                if medal.pic.isEmpty {
                    Image(systemName: "medal")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                } else {
                    AsyncImage(url: URL(string: medal.pic)) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit()
                        } else {
                            ProgressView()
                        }
                    }
                    .padding(6)
                }
            }
            .frame(height: 72)

            Text(medal.name)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

/// 勋章三列格。
struct MedalTileGrid: View {
    let medals: [MedalItem]
    let onTap: (MedalItem) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(medals) { medal in
                Button {
                    onTap(medal)
                } label: {
                    MedalTileCell(medal: medal)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// 近 N 天柱状图（无外部图表库）。
struct DailyBars: View {
    let values: [Double]
    var labels: [String] = []
    var height: CGFloat = 92

    private var maxValue: Double { max(values.max() ?? 0, 1) }

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(values.indices, id: \.self) { index in
                    VStack(spacing: 4) {
                        Text(Fmt.shortNumber(values[index]))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.accentColor.opacity(values[index] > 0 ? 0.85 : 0.15))
                            .frame(height: max(3, height * values[index] / maxValue))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: height, alignment: .bottom)

            if labels.count == values.count {
                HStack(spacing: 8) {
                    ForEach(labels.indices, id: \.self) { index in
                        Text(labels[index])
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
            }
        }
    }
}

/// 键值行。
struct LabeledRow: View {
    let label: String
    let value: String
    var highlight: Bool = false
    var small: Bool = false
    var valueColor: Color = .secondary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)
            Text(value)
                .font(.system(size: small ? 11 : 12, weight: highlight ? .semibold : .regular))
                .foregroundStyle(highlight ? Color.primary : valueColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 5)
    }
}

/// 空态 / 加载 / 错误提示。
struct StateNotice: View {
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?
    var progress: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if progress { ProgressView() }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            if let message, !message.isEmpty {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 12, weight: .semibold))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
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
            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        // 根页自绘大标题时隐藏了导航栏，子页面要恢复系统导航栏（含默认返回按钮）
        .toolbar(.visible, for: .navigationBar)
    }
}
