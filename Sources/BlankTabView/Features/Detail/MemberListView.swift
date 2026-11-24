import SwiftUI

@MainActor
final class MemberListModel: ObservableObject {
    private let services = AppServices.shared
    let family: Family

    @Published private(set) var members: [Member] = []
    @Published private(set) var loading = false

    init(family: Family) {
        self.family = family
        self.members = AppServices.shared.store.familyMembers(family.id)
    }

    func load() async {
        guard members.isEmpty else { return }
        loading = true
        let list = (try? await services.families.loadMembers(family)) ?? []
        members = list
        loading = false
    }
}

struct MemberListView: View {
    @StateObject private var model: MemberListModel

    init(family: Family) {
        _model = StateObject(wrappedValue: MemberListModel(family: family))
    }

    var body: some View {
        DetailScroll {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.family.name.isEmpty ? "家族" : model.family.name)
                    .font(.system(size: 17, weight: .semibold))
                Text("成员列表 · 共 \(model.members.count) 人")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            if model.members.isEmpty {
                if model.loading {
                    StateNotice(title: "正在读取成员…", progress: true)
                } else {
                    StateNotice(title: "暂无成员数据")
                }
            } else {
                InfoCard(padding: 6) {
                    VStack(spacing: 0) {
                        ForEach(Array(model.members.enumerated()), id: \.offset) { index, member in
                            NavigationLink(value: ProfileDestination.member(member.itemId)) {
                                MemberFullRow(member: member, familyName: model.family.name)
                            }
                            .buttonStyle(.plain)
                            if index < model.members.count - 1 {
                                Divider().padding(.leading, 54)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("成员列表")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }
}

struct MemberFullRow: View {
    let member: Member
    let familyName: String

    var body: some View {
        HStack(spacing: 10) {
            AvatarCircle(urlString: member.pic, size: 38)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(member.title.isEmpty ? "未知成员" : member.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    if !member.fanBadge.isEmpty {
                        Plate(text: member.fanBadge, filled: true)
                    }
                }
                Text(
                    "\(member.medalText.isEmpty ? "勋章馆 · \(familyName)" : member.medalText)"
                    + " · 荣誉 \(Fmt.thousands(member.honor)) · ID \(Fmt.decodeId(member.itemId))"
                )
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer(minLength: 6)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }
}
