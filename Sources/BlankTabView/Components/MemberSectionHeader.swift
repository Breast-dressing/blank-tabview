import SwiftUI

struct MemberSectionHeader: View {
    let title: String
    let pic: String
    let subtitle: String
    let count: String
    /// 需要数字滚动动画时传数值：走系统 `contentTransition(.numericText)`。
    var countValue: Int? = nil
    var unit: String = ""
    var label: String = "已获得"

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // 不要白边：关掉 AvatarCircle 默认的白色描边。
            AvatarCircle(urlString: pic, size: 48, showsRing: false)

            VStack(alignment: .leading, spacing: 2) {
                // 成员名字与名字下方那行：iOS 标题行（headline）语义字号，字重保持 bold。
                Text(title.isEmpty ? "未知成员" : title)
                    .font(.headline.weight(.bold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.headline.weight(.bold))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    // 上榜人数：iOS 三级标题（title3）语义字号，字重保持 bold。
                    if let countValue {
                        Text("\(countValue)")
                            .font(.title3.weight(.bold))
                            .contentTransition(.numericText(value: Double(countValue)))
                            .animation(.snappy(duration: 0.25), value: countValue)
                    } else {
                        Text(count)
                            .font(.title3.weight(.bold))
                    }
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
