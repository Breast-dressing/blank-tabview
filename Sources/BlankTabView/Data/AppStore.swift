import Foundation

/// 本地持久化：键名与 Flutter / Node 版保持一致，便于旧数据迁移与排查。
final class AppStore: @unchecked Sendable {
    static let medalUrlTemplate =
        "https://i2.y.qq.com/n3/client/pages/medal_collection_new/index.html"
        + "?_hidehd=1&_fontscale=1&_miniplayer=1&enc_uin={ENC_UIN}"
        + "&entry=profile&_button=1&max_age=1782752162"

    private enum Key {
        static let families = "families"
        static let legacyFamilyData = "family_data"
        static let legacyFamilyUrl = "family_url_raw"
        static let medalUrl = "medal_url"
        static let honorRecords = "member_honor_records_v1"
        static let memberInfoPrefix = "member_info_"
        static let familyMembersPrefix = "family_members_v2_"
        static let familyArtist = "family_artist_name"
        static let familyArtistPrefix = "family_artist_"
        static let medalDataPrefix = "medal_data_"
        static let medalSkinsPrefix = "medal_skins_"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    static func open() -> AppStore { AppStore() }

    // MARK: - 家族

    func loadFamilies() -> [Family] {
        if let data = defaults.data(forKey: Key.families),
           let list = try? JSONDecoder().decode([Family].self, from: data) {
            return list.filter { !$0.id.isEmpty }
        }
        // 旧版单家族数据自动迁移
        if let data = defaults.data(forKey: Key.legacyFamilyData),
           var family = try? JSONDecoder().decode(Family.self, from: data) {
            family.rawUrl = defaults.string(forKey: Key.legacyFamilyUrl) ?? ""
            if !family.id.isEmpty {
                saveFamilies([family])
                return [family]
            }
        }
        return []
    }

    func saveFamilies(_ families: [Family]) {
        if let data = try? JSONEncoder().encode(families) {
            defaults.set(data, forKey: Key.families)
        }
        if let first = families.first, let data = try? JSONEncoder().encode(first) {
            defaults.set(data, forKey: Key.legacyFamilyData)
            defaults.set(first.rawUrl, forKey: Key.legacyFamilyUrl)
        } else {
            defaults.removeObject(forKey: Key.legacyFamilyData)
            defaults.removeObject(forKey: Key.legacyFamilyUrl)
        }
    }

    // MARK: - 成员

    var selectedMemberId: String? {
        let url = defaults.string(forKey: Key.medalUrl) ?? ""
        guard let range = url.range(of: "enc_uin=\\S*", options: .regularExpression) else { return nil }
        let value = url[range].replacingOccurrences(of: "enc_uin=", with: "")
        return value.removingPercentEncoding ?? value
    }

    var medalUrl: String { defaults.string(forKey: Key.medalUrl) ?? "" }

    func setSelectedMember(_ itemId: String) {
        let url = Self.medalUrlTemplate.replacingOccurrences(of: "{ENC_UIN}", with: itemId)
        defaults.set(url, forKey: Key.medalUrl)
    }

    func memberInfo(_ itemId: String) -> Member? {
        guard let data = defaults.data(forKey: Key.memberInfoPrefix + itemId),
              var member = try? JSONDecoder().decode(Member.self, from: data) else { return nil }
        member.itemId = itemId
        return member
    }

    func saveMemberInfo(_ member: Member, familyId: String? = nil) {
        if member.itemId.isEmpty { return }
        let merged = member.with(familyId: familyId ?? member.familyId)
        if let data = try? JSONEncoder().encode(merged) {
            defaults.set(data, forKey: Key.memberInfoPrefix + member.itemId)
        }
    }

    func familyMembers(_ familyId: String) -> [Member] {
        guard let data = defaults.data(forKey: Key.familyMembersPrefix + familyId),
              let list = try? JSONDecoder().decode([Member].self, from: data) else { return [] }
        return list.filter { !$0.itemId.isEmpty }
    }

    func saveFamilyMembers(_ familyId: String, members: [Member]) {
        if let data = try? JSONEncoder().encode(members) {
            defaults.set(data, forKey: Key.familyMembersPrefix + familyId)
        }
    }

    func clearFamilyMembers(_ familyId: String) {
        defaults.removeObject(forKey: Key.familyMembersPrefix + familyId)
    }

    // MARK: - 艺人名

    func saveFamilyArtist(_ artistName: String, familyId: String) {
        if artistName.isEmpty { return }
        defaults.set(artistName, forKey: Key.familyArtist)
        if !familyId.isEmpty {
            defaults.set(artistName, forKey: Key.familyArtistPrefix + familyId)
        }
    }

    func familyArtist(_ familyId: String) -> String {
        defaults.string(forKey: Key.familyArtistPrefix + familyId)
            ?? defaults.string(forKey: Key.familyArtist)
            ?? ""
    }

    // MARK: - 荣誉记录

    func loadHonorMembers() -> [HonorMember] {
        guard let data = defaults.data(forKey: Key.honorRecords),
              let list = try? JSONDecoder().decode([HonorMember].self, from: data) else { return [] }
        return list.filter { !$0.name.isEmpty }
    }

    func saveHonorMembers(_ members: [HonorMember]) {
        if let data = try? JSONEncoder().encode(members) {
            defaults.set(data, forKey: Key.honorRecords)
        }
    }

    // MARK: - 勋章缓存

    func medalData(_ medalId: String) -> [String: Any]? {
        guard let data = defaults.data(forKey: Key.medalDataPrefix + medalId),
              let json = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return json as? [String: Any]
    }

    func saveMedalData(_ medalId: String, data: [String: Any]) {
        guard let raw = try? JSONSerialization.data(withJSONObject: data) else { return }
        defaults.set(raw, forKey: Key.medalDataPrefix + medalId)
    }

    // MARK: - 皮肤缓存

    func skinCache(_ medalId: String) -> [SkinItem] {
        guard let data = defaults.data(forKey: Key.medalSkinsPrefix + medalId),
              let list = try? JSONDecoder().decode([SkinItem].self, from: data) else { return [] }
        return list.filter { !$0.pic.isEmpty }.sorted { $0.seq < $1.seq }
    }

    func saveSkinCache(_ medalId: String, skins: [SkinItem]) {
        guard let data = try? JSONEncoder().encode(skins) else { return }
        defaults.set(data, forKey: Key.medalSkinsPrefix + medalId)
    }
}
