import SwiftUI

/// 票据卡：头像压在卡片左上角，卡面被头像咬出缺口（头像与缺口间留页面底色间隙，无白边），
/// 卡内是成员信息 / 四项数据 / 虚线 / 家族四等分。
/// 几何参数对齐 Flutter 原版：头像 80、间隙 6、倒角 8、圆角 28、卡顶留白 20。
struct ProfileTicketCard: View {
    let metrics: MemberMetrics
    let families: [Family]
    let weekHonor: (Family) -> Double
    let onManage: () -> Void
    var onTapWeek: (() -> Void)?
    var onTapMonth: (() -> Void)?
    var onTapSkins: (() -> Void)?
    var onTapMedals: (() -> Void)?
    var onTapFamily: ((Family) -> Void)?

    private var member: Member { metrics.member }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.leading, ProfileCardMetrics.headerLeading)
                .padding(.trailing, 18)
                .padding(.top, 14)

            statsRow
                .padding(.top, 14)
                .padding(.horizontal, 14)

            DashedRule()
                .padding(.horizontal, 18)
                .padding(.vertical, 14)

            familySection
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { ProfileTicketShape().fill(Color(uiColor: .secondarySystemGroupedBackground)) }
        .clipShape(ProfileTicketShape())
        .overlay(alignment: .topLeading) {
            AvatarCircle(
                urlString: member.pic,
                size: ProfileCardMetrics.avatarSize,
                showsRing: false
            )
            .offset(x: ProfileCardMetrics.avatarOffsetX, y: ProfileCardMetrics.avatarOffsetY)
            .accessibilityLabel("头像")
        }
        // 卡片顶部留白：头像上探出卡片的部分、以及缺口处的页面底色都从这里出
        .padding(.top, ProfileCardMetrics.cardTopInset)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("成员资料卡")
    }

    // MARK: - 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(member.title)
                .font(.system(size: 22, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: 8) {
                if !metrics.familyName.isEmpty {
                    Plate(text: metrics.familyName, filled: false)
                }
                if !member.medalText.isEmpty {
                    Plate(text: member.medalText, filled: true)
                }
                if !member.fanBadge.isEmpty {
                    Text(member.fanBadge)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - 四项数据

    private var statsRow: some View {
        HStack(spacing: 0) {
            stat(value: metrics.displayWeekRank, label: tabLabel(metrics.weekTabName, fallback: "周榜"), action: onTapWeek)
            statDivider
            stat(value: metrics.displayMonthRank, label: tabLabel(metrics.monthTabName, fallback: "月榜"), action: onTapMonth)
            statDivider
            stat(value: metrics.displaySkinCount, label: "乐迷皮肤", action: onTapSkins)
            statDivider
            stat(value: metrics.medalDesc, label: "已获得奖章", action: onTapMedals)
        }
    }

    private func stat(value: String, label: String, action: (() -> Void)?) -> some View {
        Button {
            action?()
        } label: {
            VStack(spacing: 6) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                HStack(spacing: 2) {
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if action != nil {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                    }
                }
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .accessibilityHint(action == nil ? "暂无可查看的详情" : "查看\(label)详情")
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.18))
            .frame(width: 1, height: 26)
    }

    private func tabLabel(_ name: String, fallback: String) -> String {
        let cleaned = Fmt.cleanTabName(name)
        return cleaned.isEmpty ? fallback : cleaned
    }

    // MARK: - 家族

    private var familySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("家族")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button(action: onManage) {
                    HStack(spacing: 2) {
                        Text("管理").font(.system(size: 13, weight: .medium))
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if families.isEmpty {
                Button(action: onManage) {
                    Text("还没有家族，点击这里添加")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            } else {
                HStack(alignment: .top, spacing: 4) {
                    ForEach(families.prefix(4)) { family in
                        familyCell(family)
                    }
                    ForEach(0..<max(0, 4 - families.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func familyCell(_ family: Family) -> some View {
        Button {
            onTapFamily?(family)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 2) {
                    Text(family.name.isEmpty ? "家族" : family.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if onTapFamily != nil {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(Fmt.thousands(family.honor))
                        .font(.system(size: 17, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("荣誉值")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }

                Text("本周\(Fmt.thousands(weekHonor(family)))荣誉值")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 小部件

/// 胶囊标签：浅灰底 = 家族 / 勋章铭牌，无底 = 乐迷编号。
struct Plate: View {
    let text: String
    var filled: Bool = true

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(filled ? Color.primary : Color.secondary)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(filled ? Color(uiColor: .tertiarySystemFill) : .clear)
            }
    }
}

/// 虚线分隔线，两端略长、间距均匀。
struct DashedRule: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height / 2))
            path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            context.stroke(
                path,
                with: .color(Color.secondary.opacity(0.35)),
                style: StrokeStyle(lineWidth: 1, dash: [5, 5])
            )
        }
        .frame(height: 1)
    }
}

/// 无数据 / 加载中 / 出错时占位的卡片。
struct ProfileStateCard: View {
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?
    var showsProgress: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if showsProgress { ProgressView() }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            if let message {
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
            RoundedRectangle(cornerRadius: ProfileCardMetrics.cornerRadius, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        }
    }
}
