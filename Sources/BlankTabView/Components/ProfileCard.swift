import SwiftUI

/// 「我的」页卡片的几何参数：圆角矩形的左上角长出一个圆形凸起，
/// 凸起里放头像，整个轮廓就是图里的“异形圆角矩形”。
enum ProfileCardMetrics {
    static let cornerRadius: CGFloat = 40
    static let avatarSize: CGFloat = 76
    static let ringPadding: CGFloat = 10
    static let lobeOffset: CGFloat = -24
    static let height: CGFloat = 190

    /// 凸起圆的直径：头像 + 一圈浅色留白。
    static var lobeDiameter: CGFloat { avatarSize + ringPadding * 2 }
}

struct ProfileCard: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            cardShape
            avatar
        }
        .frame(maxWidth: .infinity)
        .frame(height: ProfileCardMetrics.height)
        .compositingGroup()
        .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 6)
    }

    /// 圆角矩形 + 左上角圆形凸起，两块同色填充后合成一个轮廓。
    private var cardShape: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: ProfileCardMetrics.cornerRadius, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Circle()
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .frame(width: ProfileCardMetrics.lobeDiameter, height: ProfileCardMetrics.lobeDiameter)
                .offset(x: ProfileCardMetrics.lobeOffset, y: ProfileCardMetrics.lobeOffset)
        }
    }

    private var avatar: some View {
        Circle()
            .fill(Color(uiColor: .tertiarySystemFill))
            .frame(width: ProfileCardMetrics.avatarSize, height: ProfileCardMetrics.avatarSize)
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .offset(
                x: ProfileCardMetrics.lobeOffset + ProfileCardMetrics.ringPadding,
                y: ProfileCardMetrics.lobeOffset + ProfileCardMetrics.ringPadding
            )
            .accessibilityLabel("头像")
    }
}

#Preview {
    ProfileCard()
        .padding(20)
        .background(Color(uiColor: .systemGroupedBackground))
}
