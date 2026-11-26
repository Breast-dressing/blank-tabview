import SwiftUI

struct MemberSectionHeader: View {
    let title: String
    let pic: String
    let subtitle: String
    let count: String
    var unit: String = ""
    var label: String = "已获得"

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // 不要白边：关掉 AvatarCircle 默认的白色描边。
            AvatarCircle(urlString: pic, size: 48, showsRing: false)

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
