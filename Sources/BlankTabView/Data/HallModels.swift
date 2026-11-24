import Foundation

/// 皮肤缓存（与 Dart 版 `medal_skins_<id>` 同构）。
extension SkinItem: Codable {
    enum CodingKeys: String, CodingKey {
        case id, seq, name, pic, categId, seqNo, unlockedDate, userCount, isUnlocked, stateText, unlockTask, bgColor
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        seq = try c.decodeIfPresent(Int.self, forKey: .seq) ?? 0
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        pic = try c.decodeIfPresent(String.self, forKey: .pic) ?? ""
        categId = try c.decodeIfPresent(String.self, forKey: .categId) ?? ""
        seqNo = try c.decodeIfPresent(String.self, forKey: .seqNo) ?? ""
        unlockedDate = try c.decodeIfPresent(String.self, forKey: .unlockedDate) ?? ""
        userCount = try c.decodeIfPresent(Int.self, forKey: .userCount) ?? 0
        isUnlocked = try c.decodeIfPresent(Bool.self, forKey: .isUnlocked) ?? false
        stateText = try c.decodeIfPresent(String.self, forKey: .stateText) ?? "未解锁"
        unlockTask = try c.decodeIfPresent(String.self, forKey: .unlockTask) ?? ""
        bgColor = try c.decodeIfPresent(String.self, forKey: .bgColor) ?? "#FAFAFA"
    }
}

/// 单个模块的一页数据（模块卡 + 是否还有下一页 + 游标）。
struct HallModulePage: Sendable {
    var module: MedalModule
    var hasNext: Bool
    var lastPos: String
}
