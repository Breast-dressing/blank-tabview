import Charts
import SwiftUI

/// 卡片下方的原生内容：近 7 天荣誉柱状图 + 乐迷值进度 + 荣誉记录列表。
struct ProfileDetailSection: View {
    let metrics: MemberMetrics
    let honorGroups: [HonorDayGroup]
    let dayLabels: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            honorChartCard
            if let fan = metrics.fan, fan.hasProgress {
                fanCard(fan)
            }
            recordCard
        }
    }

    // MARK: - 近 7 天

    private var honorChartCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("近 7 天荣誉")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Text("共 \(Fmt.thousands(metrics.dailyHonor.reduce(0, +))) 荣誉值")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                if metrics.hasHonorData {
                    Chart(Array(0..<metrics.dailyHonor.count), id: \.self) { index in
                        BarMark(
                            x: .value("日期", label(at: index)),
                            y: .value("荣誉值", metrics.dailyHonor[index])
                        )
                        .foregroundStyle(Color.accentColor)
                        .cornerRadius(4)
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel().font(.system(size: 10))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine()
                            AxisValueLabel().font(.system(size: 10))
                        }
                    }
                    .frame(height: 140)
                } else {
                    Text("还没有导入荣誉记录，导入后这里会按天汇总。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                }
            }
        }
    }

    private func label(at index: Int) -> String {
        index < dayLabels.count ? dayLabels[index] : "\(index)"
    }

    // MARK: - 乐迷值

    private func fanCard(_ fan: FanMedal) -> some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(fan.name.isEmpty ? "乐迷值" : fan.name)
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Text("\(Fmt.thousands(fan.current))/\(Fmt.thousands(fan.upper))")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: fan.percent)
                    .tint(Color.accentColor)
                if !fan.rankTitle.isEmpty {
                    Text(fan.rankDesc.isEmpty ? fan.rankTitle : "\(fan.rankTitle)·\(fan.rankDesc)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - 荣誉记录

    private var recordCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Text("荣誉记录")
                    .font(.system(size: 16, weight: .semibold))

                if honorGroups.isEmpty {
                    Text("还没有荣誉记录")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(honorGroups.prefix(5)) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(Fmt.dayLabel(group.dateKey))
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text("+\(Fmt.thousands(group.total))")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color.orange)
                            }

                            ForEach(group.records) { record in
                                HStack(spacing: 8) {
                                    Text(record.taskName.isEmpty ? "荣誉任务" : record.taskName)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Spacer(minLength: 8)
                                    Text(Fmt.timeOf(record.date))
                                        .font(.system(size: 11))
                                        .foregroundStyle(.tertiary)
                                    Text(Fmt.thousands(record.value))
                                        .font(.system(size: 12, weight: .medium))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            }
    }
}
