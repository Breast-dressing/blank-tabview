import SwiftUI
import UIKit

/// 点赞数展示规则：1 万及以上折算成 1.2W 这类短样式；弹窗里给完整数值。
enum RankPraise {
    static func short(_ value: Int) -> String {
        guard value >= 10000 else { return "\(value)" }
        let wan = Double(value) / 10000
        var text = String(format: "%.1f", wan)
        if text.hasSuffix(".0") { text.removeLast(2) }
        return text + "W"
    }

    static func exact(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

/// 分享图内容：离屏渲染（ImageRenderer）用，全部同步绘制，不放异步图片。
struct RankShareCard: View {
    let title: String
    let subtitle: String
    let members: [RankMember]
    let ownerName: String

    private var top: [RankMember] { Array(members.prefix(5)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 26, weight: .heavy))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(top.enumerated()), id: \.offset) { _, member in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(member.position)")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 22, alignment: .leading)
                            .monospacedDigit()

                        VStack(alignment: .leading, spacing: 3) {
                            Text(member.title)
                                .font(.system(size: 15, weight: .bold))
                                .lineLimit(1)
                            if !plateText(member).isEmpty {
                                Text(plateText(member))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            if !member.descTexts.isEmpty {
                                Text(member.descTexts.joined(separator: "  "))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 8)

                        Text(RankPraise.short(member.praiseNum))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }

            Divider()

            HStack {
                Text(ownerName.isEmpty ? "乐迷勋章榜" : ownerName)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text("点点")
                    .font(.system(size: 12, weight: .semibold))
            }
        }
        .padding(24)
        .frame(width: 360, alignment: .leading)
        .background(Color(uiColor: .systemBackground))
    }

    /// 第二行：称号在前、铭牌在后。
    private func plateText(_ member: RankMember) -> String {
        let honor = member.honorTexts.joined(separator: " ")
        let wear = member.wearTexts.joined(separator: " ")
        return [honor, wear].filter { !$0.isEmpty }.joined(separator: "  ")
    }
}

/// 系统分享面板（UIActivityViewController）。
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// 分享图 payload：sheet(item:) 需要 Identifiable。
struct ShareImage: Identifiable {
    let id = UUID()
    let image: UIImage
}
