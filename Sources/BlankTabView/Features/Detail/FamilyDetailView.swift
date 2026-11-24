import SwiftUI

// MARK: - Model

@MainActor
final class FamilyDetailModel: ObservableObject {
    private let services = AppServices.shared
    let family: Family

    @Published private(set) var members: [Member] = []
    @Published private(set) var loading = true
    @Published private(set) var error: String?
    @Published private(set) var weekTotal: Double = 0
    @Published private(set) var lastWeekTotal: Double = 0
    @Published private(set) var dayValues: [Double] = Array(repeating: 0, count: 7)
    @Published private(set) var hasHonorData = false
    @Published var expanded = false

    init(family: Family) {
        self.family = family
    }

    func load() async {
        loading = true
        error = nil
        let serviceRef = services
        let familyRef = family
        do {
            let list = try await AsyncTimeout.run(seconds: 30) {
                try await serviceRef.families.loadMembers(familyRef, force: true)
            }
            members = list
        } catch {
            let cached = services.store.familyMembers(family.id)
            members = cached
            self.error = cached.isEmpty ? error.localizedDescription : nil
        }
        computeHonor()
        loading = false
    }

    func computeHonor() {
        let names = members.map(\.title).filter { !$0.isEmpty }
        guard !names.isEmpty else {
            weekTotal = Fmt.parseNumber(family.weekHonor)
            lastWeekTotal = 0
            dayValues = Array(repeating: 0, count: 7)
            hasHonorData = false
            return
        }
        let totals = services.honors.familyDailyTotals(names, days: 14)
        let values = totals.values
        guard values.count == 14 else { return }
        lastWeekTotal = values.prefix(7).reduce(0, +)
        weekTotal = values.suffix(7).reduce(0, +)
        dayValues = Array(values.suffix(7))
        hasHonorData = totals.hasData
    }

    var topMembers: [Member] { Array(members.prefix(5)) }

    /// 不达标：荣誉值 < 500，按荣誉升序。
    var belowThreshold: [Member] {
        let list = members
            .filter { Fmt.parseNumber($0.honor) < 500 }
            .sorted { Fmt.parseNumber($0.honor) < Fmt.parseNumber($1.honor) }
        return expanded ? list : Array(list.prefix(3))
    }

    var belowCount: Int { members.filter { Fmt.parseNumber($0.honor) < 500 }.count }
}

// MARK: - View

struct FamilyDetailView: View {
    @StateObject private var model: FamilyDetailModel

    init(family: Family) {
        _model = StateObject(wrappedValue: FamilyDetailModel(family: family))
    }

    var body: some View {
        DetailScroll {
            profileCard
            honorCard
            membersCard
            if model.belowCount > 0 { belowCard }

            if model.loading {
                StateNotice(title: "正在读取家族成员…", progress: true)
            } else if let error = model.error {
                StateNotice(title: "成员加载失败", message: error, actionTitle: "重试") {
                    Task { await model.load() }
                }
            }
        }
        .navigationTitle(model.family.name.isEmpty ? "家族详情" : model.family.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }

    private var profileCard: some View {
        InfoCard {
            HStack(spacing: 12) {
                AvatarCircle(urlString: model.family.avatar, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.family.name.isEmpty ? "家族" : model.family.name)
                        .font(.system(size: 19, weight: .bold))
                        .lineLimit(1)
                    if !model.family.sign.isEmpty {
                        Text(model.family.sign)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }

            HStack(alignment: .top, spacing: 0) {
                stat("总荣誉值", Fmt.thousands(model.family.honor))
                stat("周排名", Fmt.rank(model.family.rank))
                stat("PK胜场", model.family.pkWin)
                memberCountStat
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var memberCountStat: some View {
        NavigationLink(value: ProfileDestination.memberList(model.family)) {
            VStack(spacing: 5) {
                Text("\(model.family.memberCount)")
                    .font(.system(size: 18, weight: .bold))
                    .monospacedDigit()
                HStack(spacing: 2) {
                    Text("成员数").font(.system(size: 11))
                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var honorCard: some View {
        InfoCard {
            HStack {
                Text("家族荣誉")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text("本周 \(Fmt.thousands(model.weekTotal))｜上周 \(Fmt.thousands(model.lastWeekTotal))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if model.hasHonorData {
                DailyBars(values: model.dayValues, labels: DayLabels.recent7)
            } else {
                Text("还没有导入荣誉记录，导入后这里会按天汇总。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
        }
    }

    private var membersCard: some View {
        InfoCard {
            HStack {
                Text("成员")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                NavigationLink(value: ProfileDestination.memberList(model.family)) {
                    HStack(spacing: 2) {
                        Text("查看全部")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if model.topMembers.isEmpty {
                Text(model.loading ? "正在读取成员…" : "暂无成员数据")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(model.topMembers) { member in
                        NavigationLink(value: ProfileDestination.member(member.itemId)) {
                            MemberSimpleRow(member: member)
                        }
                        .buttonStyle(.plain)
                        if member.itemId != model.topMembers.last?.itemId {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
            }
        }
    }

    private var belowCard: some View {
        InfoCard {
            HStack {
                Text("待提升成员")
                    .font(.system(size: 16, weight: .semibold))
                Text("\(model.belowCount) 人")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            VStack(spacing: 0) {
                ForEach(model.belowThreshold) { member in
                    HStack(spacing: 10) {
                        AvatarCircle(urlString: member.pic, size: 32)
                        Text(member.title)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Text("荣誉 \(Fmt.thousands(member.honor))")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Plate(text: "未达标", filled: true)
                    }
                    .padding(.vertical, 7)
                }
            }

            if model.belowCount > 3 {
                Button(model.expanded ? "收起" : "展开全部") {
                    model.expanded.toggle()
                }
                .font(.system(size: 12))
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
        }
    }
}

// MARK: - 行

struct MemberSimpleRow: View {
    let member: Member

    var body: some View {
        HStack(spacing: 10) {
            AvatarCircle(urlString: member.pic, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(member.title.isEmpty ? "未知成员" : member.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                if !member.medalText.isEmpty {
                    Text(member.medalText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            Text("荣誉 \(Fmt.thousands(member.honor))")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        FamilyDetailView(family: Family(id: "1", name: "石榴裙"))
    }
}
