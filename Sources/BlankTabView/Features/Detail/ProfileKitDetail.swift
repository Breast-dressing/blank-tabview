import Charts
import SwiftUI

/// 逐日（或近 N 日）荣誉折线/柱状展示。
struct DailyBars: View {
    let values: [Double]
    var labels: [String] = []
    var height: CGFloat = 96

    private struct Point: Identifiable {
        let index: Int
        let value: Double
        var id: Int { index }
    }

    private var points: [Point] {
        values.enumerated().map { Point(index: $0.offset, value: $0.element) }
    }

    private var maxValue: Double { max(values.max() ?? 0, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Chart(points) { point in
                BarMark(
                    x: .value("日", point.index),
                    y: .value("荣誉", point.value)
                )
                .foregroundStyle(Color.accentColor.opacity(0.8))
                .cornerRadius(3)
            }
            .chartYScale(domain: 0...maxValue)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: height)

            if !labels.isEmpty {
                HStack(spacing: 0) {
                    ForEach(labels.indices, id: \.self) { index in
                        Text(labels[index])
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
            }
        }
    }
}

/// 键值行。
struct LabeledRow: View {
    let label: String
    let value: String
    var highlight: Bool = false
    var small: Bool = false
    var valueColor: Color = .secondary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)
            Text(value)
                .font(.system(size: small ? 11 : 12, weight: highlight ? .semibold : .regular))
                .foregroundStyle(highlight ? Color.primary : valueColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 5)
    }
}

/// 空态 / 加载 / 错误提示。
struct StateNotice: View {
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?
    var progress: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if progress { ProgressView() }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            if let message, !message.isEmpty {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 12, weight: .semibold))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        }
    }
}

/// “我”标记。
struct MeBadge: View {
    var body: some View {
        Text("我")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background { Capsule().fill(Color.accentColor) }
    }
}

/// 详情页统一滚动容器。
struct DetailScroll<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        // 根页自绘大标题时隐藏了导航栏，子页面要恢复系统导航栏（含默认返回按钮）
        .toolbar(.visible, for: .navigationBar)
    }
}
