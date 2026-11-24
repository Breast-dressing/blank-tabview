import SwiftUI

/// 原生设置页：用 Form 组织家族与成员，交互与 Flutter 版一致（增删、排序、选成员后刷新）。
struct SettingsView: View {
    @StateObject private var model = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("粘贴家族页链接", text: $model.urlText, axis: .vertical)
                        .lineLimit(1...3)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .font(.system(size: 14))

                    Button {
                        Task { await model.addFamily() }
                    } label: {
                        HStack(spacing: 8) {
                            if model.adding { ProgressView() }
                            Text(model.adding ? "正在解析家族页…" : "添加家族")
                        }
                    }
                    .disabled(model.adding)

                    if let message = model.message {
                        Text(message).font(.caption).foregroundStyle(.secondary)
                    }
                    if let error = model.errorMessage {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                } header: {
                    Text("家族链接")
                } footer: {
                    Text("支持家族主页链接、c6 短链或 family_id。重复添加会提示已存在。")
                }

                Section("家族") {
                    if model.families.isEmpty {
                        Text("还没有家族").font(.footnote).foregroundStyle(.secondary)
                    } else {
                        ForEach(model.families) { family in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(family.name.isEmpty ? "未命名家族" : family.name)
                                    .font(.system(size: 15, weight: .medium))
                                Text(family.rawUrl.isEmpty ? "family_id=\(family.id)" : family.rawUrl)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .onDelete { offsets in model.remove(at: offsets) }
                        .onMove { source, destination in model.move(from: source, to: destination) }
                    }
                }

                Section("当前归属成员") {
                    if model.loadingMembers {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("正在读取成员…").font(.footnote).foregroundStyle(.secondary)
                        }
                    } else if model.members.isEmpty {
                        Text("请先添加家族，或家族暂无成员")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("成员", selection: $model.selectedId) {
                            Text("选择成员").tag(Optional<String>.none)
                            ForEach(model.members) { entry in
                                Text(entry.displayName).tag(Optional(entry.member.itemId))
                            }
                        }
                    }
                }

                Section {
                    Button("保存并刷新") {
                        model.saveMember()
                        dismiss()
                    }
                    .disabled(model.selectedId == nil)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
            }
            .task { await model.load() }
        }
    }
}

#Preview {
    SettingsView()
}
