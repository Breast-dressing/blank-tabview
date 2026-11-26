import SwiftUI

/// 详情页统一骨架：分组灰底 + 成员信息平铺 + 间距 20 的白卡片流。
/// 乐迷皮肤页、「乐迷皮肤」的系列详情、「已获得奖章」及奖章系列页全部复用它。
struct DetailPageScaffold<Content: View>: View {
    let header: MemberSectionHeader
    let content: Content

    init(header: MemberSectionHeader, @ViewBuilder content: () -> Content) {
        self.header = header
        self.content = content()
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                // 成员信息直接平铺，左右与下方卡片边缘对齐。
                header
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)

                content
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

/// 详情页里的白卡片：标题（可空）+ 右侧箭头文字（可空）+ 自定义内容。
struct DetailSeriesCard<Content: View>: View {
    let title: String
    let trailing: String?
    let onTrailingTap: (() -> Void)?
    let content: Content

    init(
        title: String,
        trailing: String? = nil,
        onTrailingTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.trailing = trailing
        self.onTrailingTap = onTrailingTap
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !title.isEmpty || trailing != nil {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if let trailing {
                        Button {
                            onTrailingTap?()
                        } label: {
                            HStack(spacing: 2) {
                                Text(trailing)
                                    .font(.system(size: 14))
                                    .monospacedDigit()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(.secondary)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(onTrailingTap == nil)
                    }
                }
            }

            content
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 16)
    }
}

/// 详情页的状态提示（加载中 / 失败 / 空），与卡片左对齐。
struct DetailPageNotice: View {
    let notice: StateNotice

    init(_ notice: StateNotice) {
        self.notice = notice
    }

    var body: some View {
        notice.padding(.horizontal, 16)
    }
}
