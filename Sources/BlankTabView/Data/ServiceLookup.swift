import Foundation

extension AppServices {
    /// 当前成员主页链接（与 AppStore.medalUrlTemplate 一致）。
    func hallURL(_ itemId: String) -> String {
        AppStore.medalUrlTemplate.replacingOccurrences(of: "{ENC_UIN}", with: itemId)
    }

    /// 成员资料：先指标快照，再磁盘缓存，最后占位。
    func member(_ itemId: String) -> Member {
        if let cached = metrics.peek(itemId)?.member { return cached }
        if let cached = metrics.cachedMember(itemId) { return cached }
        return Member(itemId: itemId, title: "用户")
    }
}

extension Fmt {
    /// 计数（点赞数等）直出，不做千分位，保持榜行紧凑。
    static func compact(_ value: Int) -> String { "\(value)" }
}

/// 近 7 天横坐标：11/18 … 11/24
enum DayLabels {
    static var recent7: [String] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return stride(from: 6, through: 0, by: -1).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let parts = calendar.dateComponents([.month, .day], from: day)
            return "\(parts.month ?? 0)/\(parts.day ?? 0)"
        }
    }
}
