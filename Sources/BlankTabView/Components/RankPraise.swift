import Foundation

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
