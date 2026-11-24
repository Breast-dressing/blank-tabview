import CryptoKit
import Foundation

/// QQ 音乐 `musics.fcg` 的签名算法：SHA1 → 三段拼接 → 20 字节异或 → base64。
enum QqSign {
    private static let part1Indexes = [23, 14, 6, 36, 16, 7, 19]
    private static let part2Indexes = [16, 1, 32, 12, 19, 27, 8, 5]
    private static let scramble: [UInt8] = [
        89, 39, 179, 150, 218, 82, 58, 252, 177, 52,
        186, 123, 120, 64, 242, 133, 143, 161, 121, 179
    ]

    static func sign(_ payload: String) -> String {
        let digest = Insecure.SHA1.hash(data: Data(payload.utf8))
        let hash = digest.map { String(format: "%02X", $0) }.joined()
        let chars = Array(hash)

        let part1 = part1Indexes.map { String(chars[$0]) }.joined()
        let part2 = part2Indexes.map { String(chars[$0]) }.joined()

        var bytes = [UInt8]()
        bytes.reserveCapacity(20)
        for index in 0..<20 {
            let start = hash.index(hash.startIndex, offsetBy: index * 2)
            let end = hash.index(start, offsetBy: 2)
            let pair = UInt8(hash[start..<end], radix: 16) ?? 0
            bytes.append(scramble[index] ^ pair)
        }

        let base64 = Data(bytes).base64EncodedString()
            .filter { $0 != "\\" && $0 != "/" && $0 != "+" && $0 != "=" }

        return ("zzc" + part1 + base64 + part2).lowercased()
    }
}
