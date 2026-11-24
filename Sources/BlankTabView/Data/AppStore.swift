import Foundation

/// 本地持久化：键名与 Flutter / Node 版保持一致，便于旧数据迁移与排查。
/// 成员 ID 统一经 `MemberId.canonical` 归一化后作为 key，旧版本落盘的编码形式会自动迁移。
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
        guard let range = url.range(of: "enc_uin=[^&\\s]*", options: .regularExpression) else { return nil }
        let value = String(url[range]).replacingOccurrences(of: "enc_uin=", with: "")
        let canonical = MemberId.canonical(value)
        return canonical.isEmpty ? nil : canonical
    }

    var medalUrl: String { defaults.string(forKey: Key.medalUrl) ?? "" }

    func setSelectedMember(_ itemId: String) {
        let canonical = MemberId.canonical(itemId)
        guard !canonical.isEmpty else {
            defaults.removeObject(forKey: Key.medalUrl)
            return
        }
        let url = Self.medalUrlTemplate.replacingOccurrences(of: "{ENC_UIN}", with: canonical)
        defaults.set(url, forKey: Key.medalUrl)
    }

    func memberInfo(_ itemId: String) -> Member? {
        let canonical = MemberId.canonical(itemId)
        guard !canonical.isEmpty else { return nil }

        if let data = defaults.data(forKey: Key.memberInfoPrefix + canonical),
           var member = try? JSONDecoder().decode(Member.self, from: data) {
            member.itemId = canonical
            return member
        }

        // 旧版本可能把编码形式的 ID 作为 key 落盘：扫一遍前缀，命中后迁移到规范 key
        for storedKey in defaults.dictionaryRepresentation().keys
        where storedKey.hasPrefix(Key.memberInfoPrefix) {
            let storedId = String(storedKey.dropFirst(Key.memberInfoPrefix.count))
            guard MemberId.matches(storedId, canonical),
                  let data = defaults.data(forKey: storedKey),
                  var member = try? JSONDecoder().decode(Member.self, from: data) else { continue }
            member.itemId = canonical
            saveMemberInfo(member)
            defaults.removeObject(forKey: storedKey)
            return member
        }
        return nil
    }

    func saveMemberInfo(_ member: Member, familyId: String? = nil) {
        let canonical = MemberId.canonical(member.itemId)
        guard !canonical.isEmpty else { return }
        var merged = member.with(familyId: familyId ?? member.familyId)
        merged.itemId = canonical
        if let data = try? JSONEncoder().encode(merged) {
            defaults.set(data, forKey: Key.memberInfoPrefix + canonical)
        }
    }

    func familyMembers(_ familyId: String) -> [Member] {
        guard let data = defaults.data(forKey: Key.familyMembersPrefix + familyId),
              let list = try? JSONDecoder().decode([Member].self, from: data) else { return [] }
        return list
            .filter { !$0.itemId.isEmpty }
            .map { member in
                var fixed = member
                fixed.itemId = MemberId.canonical(member.itemId)
                return fixed
            }
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
