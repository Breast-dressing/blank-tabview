import Foundation
import SwiftUI

/// 设置页逻辑：家族增删 / 排序、成员下拉、保存并刷新。
/// 成员 ID 一律经 `MemberId.canonical` 归一化，落盘后才能被「我的」页命中。
@MainActor
final class SettingsViewModel: ObservableObject {
    private let services = AppServices.shared

    @Published private(set) var families: [Family] = []
    @Published private(set) var members: [FamilyMemberEntry] = []
    @Published var selectedId: String?
    @Published var urlText = ""
    @Published private(set) var adding = false
    @Published private(set) var loadingMembers = false
    @Published private(set) var message: String?
    @Published private(set) var errorMessage: String?

    func load() async {
        families = services.families.families
        selectedId = services.store.selectedMemberId.flatMap { raw -> String? in
            let canonical = MemberId.canonical(raw)
            return canonical.isEmpty ? nil : canonical
        }
        await refreshMembers()
    }

    func refreshMembers() async {
        loadingMembers = true
        members = await services.families.allMembers()
        loadingMembers = false
        if let selected = selectedId,
           !members.contains(where: { MemberId.matches($0.member.itemId, selected) }) {
            selectedId = nil
        }
        if selectedId == nil, let first = members.first {
            let canonical = MemberId.canonical(first.member.itemId)
            if !canonical.isEmpty { selectedId = canonical }
        }
    }

    func addFamily() async {
        let text = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            message = nil
            errorMessage = "请先粘贴家族链接"
            return
        }

        adding = true
        message = nil
        errorMessage = nil
        do {
            families = try await services.families.add(text)
            urlText = ""
            message = "已添加：\(families.last?.name ?? "")"
            services.metrics.invalidate()
            await refreshMembers()
        } catch {
            errorMessage = error.localizedDescription
        }
        adding = false
    }

    func remove(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            families = services.families.removeAt(index)
        }
        services.metrics.invalidate()
        Task { await refreshMembers() }
    }

    func move(from source: IndexSet, to destination: Int) {
        guard let from = source.first else { return }
        families = services.families.reorder(from: from, to: destination)
    }

    func saveMember() {
        guard let selectedId, !selectedId.isEmpty else { return }
        services.store.setSelectedMember(MemberId.canonical(selectedId))
        services.metrics.invalidate()
    }
}
