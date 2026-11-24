import SwiftUI
import UIKit

extension SkinItem: Identifiable {}

/// 单个皮肤详情（sheet）：大图 + 属性 + 复制链接。
struct SkinDetailSheet: View {
    let skin: SkinItem
    let seriesName: String
    let uin: String

    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    private var link: String {
        let safeId = skin.id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? skin.id
        let safeUin = uin.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? uin
        return "https://i2.y.qq.com/n3/medal_collection/pages/medal_collection_v3/skin_detail.html"
            + "?_hidehd=1&_fontscale=1&skin_id=\(safeId)&enc_uin=\(safeUin)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    image

                    VStack(alignment: .leading, spacing: 3) {
                        Text(skin.name)
                            .font(.system(size: 19, weight: .bold))
                        Text("ID \(skin.id)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        LabeledRow(label: "皮肤序号", value: skin.seq == 0 ? "-" : "\(skin.seq)", highlight: true)
                        LabeledRow(
                            label: "所属分类ID",
                            value: skin.categId.isEmpty ? "其他系列" : "\(skin.categId) · \(seriesName)"
                        )
                        LabeledRow(
                            label: "解锁状态",
                            value: skin.stateText,
                            valueColor: skin.isUnlocked ? .green : .secondary
                        )
                        LabeledRow(label: "限定编号", value: skin.seqNo.isEmpty ? "无" : skin.seqNo, highlight: true)
                        LabeledRow(label: "获取日期", value: skin.unlockedDate)
                        LabeledRow(
                            label: "全服解锁人数",
                            value: skin.userCount > 0 ? "\(Fmt.thousands(skin.userCount)) 人" : "-"
                        )
                        if !skin.isUnlocked && !skin.unlockTask.isEmpty {
                            LabeledRow(label: "解锁条件", value: skin.unlockTask, small: true)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    }

                    Button {
                        UIPasteboard.general.string = link
                        copied = true
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            copied = false
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: copied ? "checkmark" : "link")
                                .font(.system(size: 14, weight: .semibold))
                            Text(copied ? "已复制" : "复制当前皮肤链接")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(copied ? Color.green : Color(uiColor: .label))
                        }
                        .foregroundStyle(copied ? Color.white : Color(uiColor: .systemBackground))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background((Color(hex: skin.bgColor) ?? Color(uiColor: .systemGroupedBackground)).ignoresSafeArea())
            .navigationTitle("皮肤详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var image: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
            if let url = URL(string: skin.pic), !skin.pic.isEmpty {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else {
                        ProgressView()
                    }
                }
                .padding(12)
            }
        }
        .frame(height: 260)
        .frame(maxWidth: .infinity)
    }
}

extension Color {
    /// "#FAFAFA" / "#FFF" → Color。
    init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text.removeFirst() }
        guard !text.isEmpty else { return nil }
        if text.count == 3 {
            text = text.map { "\($0)\($0)" }.joined()
        }
        guard text.count == 6, let value = UInt64(text, radix: 16) else { return nil }
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self = Color(red: red, green: green, blue: blue)
    }
}
