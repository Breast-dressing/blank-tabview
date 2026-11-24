import Foundation

/// 全工程唯一的成员 ID 归一化：设置页选中、成员资料缓存键、榜单「我」标记、勋章馆链接都用它。
/// QQ 接口返回的 ItemID / enc_uin 有的带百分号编码，同一个成员会出现两个字符串；
/// 只在读入边界归一化一次，后续全部按归一化后的 ID 比较，不再各自 decode。
enum MemberId {
    static func canonical(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for _ in 0..<3 {
            guard let decoded = text.removingPercentEncoding else { break }
            let next = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
            if next == text { break }
            text = next
        }
        return text
    }

    static func matches(_ lhs: String, _ rhs: String) -> Bool {
        canonical(lhs) == canonical(rhs)
    }
}
