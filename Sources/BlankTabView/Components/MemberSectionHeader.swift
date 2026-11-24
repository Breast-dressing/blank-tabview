import SwiftUI

/// 详情页顶部的成员信息：头像 + 名字 / 副标题 + 右侧数量。左右与下方卡片内容对齐。
struct MemberSectionHeader: View {
    let title: String
    let pic: String
    let subtitle: String
    let count: String
    var unit: String = ""
    var label: String = "已获得"

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            AvatarCircle(urlString: pic, size: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(title.isEmpty ? "未知成员" : title)
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(count)
                        .font(.system(size: 20, weight: .bold))
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.footnote)
                    }
                }
                Text(label)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
