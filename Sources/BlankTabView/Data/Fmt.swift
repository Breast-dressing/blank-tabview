import Foundation

/// 数字 / 日期 / 文本格式化的统一入口（对应 Flutter 的 Fmt）。
enum Fmt {
    /// 把 '1,234'、'1234人'、'-12' 之类的字符串取出数值。
    static func parseNumber(_ value: String?) -> Double {
        guard let value else { return 0 }
        let cleaned = value.filter { $0.isNumber || $0 == "." || $0 == "-" }
        return Double(cleaned) ?? 0
    }

    static func parseNumber(_ value: Double) -> Double { value }

    /// 千分位。空值统一显示 '--'。
    static func thousands(_ value: String?) -> String {
        guard let value else { return "--" }
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return "--" }
        let number = parseNumber(text)
        let looksNumeric = text.allSatisfy { $0.isNumber || "-.,".contains($0) }
        if number == 0 && !looksNumeric { return text }
        return grouped(number)
    }

    static func thousands(_ value: Double) -> String { grouped(value) }

    static func thousands(_ value: Int) -> String { grouped(Double(value)) }

    private static func grouped(_ number: Double) -> String {
        let isInt = number == number.rounded()
        let raw = isInt ? String(Int(number)) : String(number)
        let negative = raw.hasPrefix("-")
        let digits = negative ? String(raw.dropFirst()) : raw
        var out = ""
        for (index, char) in digits.enumerated() {
            if index > 0 && (digits.count - index) % 3 == 0 { out.append(",") }
            out.append(char)
        }
        return negative ? "-" + out : out
    }

    static func rank(_ value: String?) -> String {
        guard let value else { return "--" }
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "--" : text
    }

    static func date(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    static func chineseDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年MM月dd日"
        return f.string(from: date)
    }

    /// 荣誉记录的时间：中文格式优先，其次常见 ISO / 短横线格式。
    static func parseHonorDate(_ raw: String) -> Date? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let pattern = "(\\d{4})年(\\d{1,2})月(\\d{1,2})日(?:[\\sT]+(\\d{1,2}):(\\d{2}))?"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            let ns = text as NSString
            let year = Int(ns.substring(with: match.range(at: 1))) ?? 0
            let month = Int(ns.substring(with: match.range(at: 2))) ?? 1
            let day = Int(ns.substring(with: match.range(at: 3))) ?? 1
            var hour = 0
            var minute = 0
            if match.range(at: 4).location != NSNotFound {
                hour = Int(ns.substring(with: match.range(at: 4))) ?? 0
                minute = Int(ns.substring(with: match.range(at: 5))) ?? 0
            }
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            components.hour = hour
            components.minute = minute
            if let date = Calendar.current.date(from: components) { return date }
        }

        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: text) { return date }

        let patterns = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd",
            "yyyy/MM/dd HH:mm:ss",
            "yyyy/MM/dd HH:mm",
            "yyyy/MM/dd"
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        for format in patterns {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    /// 记录所属日期 key：2025年11月20日 / 2025-11-20
    static func dateKey(_ raw: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = "(\\d{4}年\\d{1,2}月\\d{1,2}日|\\d{4}-\\d{2}-\\d{2})"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            return (text as NSString).substring(with: match.range(at: 1))
        }
        let head = text.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? text
        return head
    }

    /// 记录里的时间：2025年11月20日 12:34 -> 12:34
    static func timeOf(_ raw: String) -> String {
        if let regex = try? NSRegularExpression(pattern: "\\d{1,2}:\\d{2}"),
           let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) {
            return (raw as NSString).substring(with: match.range)
        }
        return raw
    }

    static func dayLabel(_ dateKey: String, now: Date = Date()) -> String {
        guard let date = parseHonorDate(dateKey) else { return dateKey }
        let cal = Calendar.current
        let diff = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: now)).day ?? 0
        if diff == 0 { return "今天" }
        if diff == 1 { return "昨天" }
        let weekday = cal.component(.weekday, from: date) // 1 = 周日
        let names = ["日", "一", "二", "三", "四", "五", "六"]
        let index = (weekday - 1) % 7
        return "\(cal.component(.month, from: date))月\(cal.component(.day, from: date))日 · 周\(names[index])"
    }

    static func shortDate(_ raw: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let regex = try? NSRegularExpression(pattern: "^\\d{4}-\\d{2}-\\d{2}"),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            return (text as NSString).substring(with: match.range)
        }
        return ""
    }

    static func compact(_ raw: String?) -> String {
        let text = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return "" }
        let short = shortDate(text)
        return short.isEmpty ? text : short
    }

    /// 去掉 tab 名里带的数量后缀：周榜(12) / 月榜 3
    static func cleanTabName(_ raw: String?) -> String {
        var text = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return text }
        let pattern = "\\s*(?:[（(]\\s*[0-9,，]+\\s*[)）]|[0-9,，]+)\\s*$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        for _ in 0..<3 {
            let range = NSRange(text.startIndex..., in: text)
            guard let match = regex.firstMatch(in: text, range: range) else { break }
            let next = (text as NSString).replacingCharacters(in: match.range, with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if next.isEmpty || next == text { break }
            text = next
        }
        return text
    }

    static func decodeId(_ id: String) -> String {
        id.removingPercentEncoding ?? id
    }
}
