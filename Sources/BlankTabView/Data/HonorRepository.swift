import Foundation

struct DailyTotals: Sendable {
    var values: [Double]
    var hasData: Bool
}

struct HarException: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// 荣誉记录：按成员存储，按日分组，供卡片 / 图表 / 记录列表使用。
final class HonorRepository: @unchecked Sendable {
    static let harHonorURL = "https://y.qq.com/music/honor"

    private let store: AppStore

    init(store: AppStore) {
        self.store = store
    }

    // MARK: - 读取

    func members() -> [HonorMember] { store.loadHonorMembers() }

    func member(_ name: String) -> HonorMember? {
        store.loadHonorMembers().first { $0.name == name }
    }

    func recordsOf(_ memberName: String) -> [HonorRecord] {
        member(memberName)?.records ?? []
    }

    func groupsOf(_ memberName: String) -> [HonorDayGroup] {
        group(recordsOf(memberName))
    }

    func group(_ records: [HonorRecord]) -> [HonorDayGroup] {
        var buckets: [String: [HonorRecord]] = [:]
        for record in records {
            buckets[Fmt.dateKey(record.date), default: []].append(record)
        }

        let groups = buckets.map { key, list -> HonorDayGroup in
            let sorted = list.sorted { lhs, rhs in
                let left = Fmt.parseHonorDate(lhs.date) ?? Date.distantPast
                let right = Fmt.parseHonorDate(rhs.date) ?? Date.distantPast
                return left > right
            }
            let total = sorted.reduce(0) { $0 + $1.valueNumber }
            let timestamp = sorted.first.flatMap { Fmt.parseHonorDate($0.date) }
            return HonorDayGroup(dateKey: key, records: sorted, total: total, timestamp: timestamp)
        }

        return groups.sorted { lhs, rhs in
            let left = lhs.timestamp ?? Date.distantPast
            let right = rhs.timestamp ?? Date.distantPast
            if left == right { return lhs.dateKey > rhs.dateKey }
            return left > right
        }
    }

    /// 近 N 天每日荣誉合计（从旧到新，最后一位是今天）。
    func dailyTotals(_ memberName: String, days: Int = 7, now: Date = Date()) -> DailyTotals {
        let groups = group(recordsOf(memberName))
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        var values: [Double] = []
        var hasData = false

        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else {
                values.append(0)
                continue
            }
            let total = groups
                .filter { group in
                    guard let date = group.timestamp else { return false }
                    return calendar.isDate(date, inSameDayAs: day)
                }
                .reduce(0) { $0 + $1.total }
            if total > 0 { hasData = true }
            values.append(total)
        }

        return DailyTotals(values: values, hasData: hasData)
    }

    func familyDailyTotals(_ names: [String], days: Int = 7, now: Date = Date()) -> DailyTotals {
        var values = Array(repeating: 0.0, count: days)
        var hasData = false
        for name in names {
            let totals = dailyTotals(name, days: days, now: now)
            hasData = hasData || totals.hasData
            for (index, value) in totals.values.enumerated() where index < values.count {
                values[index] += value
            }
        }
        return DailyTotals(values: values, hasData: hasData)
    }

    // MARK: - 写入

    func ensureIds(_ records: [HonorRecord]) -> [HonorRecord] {
        records.map { record in
            var item = record
            if item.id.isEmpty { item.id = "hr_\(UUID().uuidString.prefix(8).lowercased())" }
            return item
        }
    }

    /// 按成员合并保存：同名 + 同时间 + 同任务 + 同数值视为重复。
    func save(_ records: [HonorRecord], memberName: String) {
        var members = store.loadHonorMembers()
        let prepared = ensureIds(records)

        if let index = members.firstIndex(where: { $0.name == memberName }) {
            var existing = members[index].records
            let existingKeys = Set(existing.map(Self.key))
            for record in prepared where !existingKeys.contains(Self.key(record)) {
                existing.append(record)
            }
            existing.sort { lhs, rhs in
                (Fmt.parseHonorDate(lhs.date) ?? Date.distantPast) > (Fmt.parseHonorDate(rhs.date) ?? Date.distantPast)
            }
            members[index].records = existing
        } else {
            members.append(HonorMember(name: memberName, records: prepared))
        }

        store.saveHonorMembers(members)
    }

    private static func key(_ record: HonorRecord) -> String {
        "\(record.date)|\(record.taskName)|\(record.value)"
    }

    func delete(memberName: String, recordId: String) {
        var members = store.loadHonorMembers()
        guard let index = members.firstIndex(where: { $0.name == memberName }) else { return }
        members[index].records.removeAll { $0.id == recordId }
        store.saveHonorMembers(members)
    }

    // MARK: - HAR 导入

    /// 从浏览器导出的 HAR 里提取荣誉记录（只认荣誉接口）。
    func importHar(_ text: String) throws -> [HonorRecord] {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let log = json["log"] as? [String: Any],
              let entries = log["entries"] as? [[String: Any]] else {
            throw HarException(message: "HAR 文件格式不正确")
        }

        var records: [HonorRecord] = []
        for entry in entries {
            let url = QqApi.str(QqApi.map(entry["request"])["url"])
            guard url.contains(Self.harHonorURL) || url.contains("honor") else { continue }
            let content = QqApi.str(QqApi.map(QqApi.map(entry["response"])["content"])["text"])
            guard let listStart = content.firstIndex(of: "["), let listEnd = content.lastIndex(of: "]") else { continue }
            let listText = String(content[listStart...listEnd])
            guard let listData = listText.data(using: .utf8),
                  let list = try? JSONSerialization.jsonObject(with: listData) as? [[String: Any]] else { continue }

            for block in list {
                let rawTitle = QqApi.str(block["Title"])
                let parts = rawTitle.split(separator: "@", maxSplits: 1).map(String.init)
                let taskName = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                var memberName = parts.count > 1 ? parts[1] : ""
                while let last = memberName.last, "，。,.;；:： ".contains(last) {
                    memberName.removeLast()
                }
                let value = QqApi.str(block["Value"])
                let date = QqApi.str(block["Time"])
                guard !memberName.isEmpty, !date.isEmpty else { continue }
                records.append(HonorRecord(id: "", taskName: taskName, date: date, value: value))
            }
        }

        if records.isEmpty { throw HarException(message: "HAR 里没有找到荣誉记录") }
        return ensureIds(records)
    }
}
