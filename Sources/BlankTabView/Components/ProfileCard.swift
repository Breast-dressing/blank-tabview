import SwiftUI

/// 「我的」页卡片的几何参数：圆角矩形的左上角长出一个圆形凸起，
/// 凸起里放头像，整个轮廓就是图里的“异形圆角矩形”。
enum ProfileCardMetrics {
    static let cornerRadius: CGFloat = 28
    static let avatarSize: CGFloat = 76
    static let ringPadding: CGFloat = 8
    static let lobeOffset: CGFloat = -24

    /// 凸起圆的直径：头像 + 一圈浅色留白。
    static var lobeDiameter: CGFloat { avatarSize + ringPadding * 2 }

    /// 头像相对卡片左上角的偏移。
    static var avatarOffset: CGFloat { lobeOffset + ringPadding }
}

/// 卡面背景：连续圆角矩形 + 左上角圆形凸起，两块同色填充后合成一个轮廓。
/// 按需求不加阴影，只用底色与留白做层次。
struct ProfileCardBackground: View {
    var fill: Color = Color(uiColor: .secondarySystemGroupedBackground)

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: ProfileCardMetrics.cornerRadius, style: .continuous)
                .fill(fill)

            Circle()
                .fill(fill)
                .frame(width: ProfileCardMetrics.lobeDiameter, height: ProfileCardMetrics.lobeDiameter)
                .offset(x: ProfileCardMetrics.lobeOffset, y: ProfileCardMetrics.lobeOffset)
        }
        .compositingGroup()
    }
}

/// 头像：异步加载，失败时回退到占位图标。
struct AvatarCircle: View {
    let urlString: String
    var size: CGFloat = ProfileCardMetrics.avatarSize

    var body: some View {
        ZStack {
            Circle().fill(Color(uiColor: .tertiarySystemFill))
            if let url = URL(string: urlString), !urlString.isEmpty {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color(uiColor: .systemBackground).opacity(0.9), lineWidth: 1))
    }

    private var fallback: some View {
        Image(systemName: "person.fill")
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}

#Preview {
    ProfileCardBackground()
        .frame(height: 220)
        .padding(20)
        .background(Color(uiColor: .systemGroupedBackground))
}
