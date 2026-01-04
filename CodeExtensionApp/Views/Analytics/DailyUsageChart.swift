import SwiftUI
import Charts

// MARK: - Daily Usage Chart

struct DailyUsageChart: View {
    let stats: [AnalyticsData.DailyStat]
    @State private var hoveredStat: AnalyticsData.DailyStat?

    private var labelInterval: Int {
        let count = stats.count
        if count <= 7 { return 1 }
        if count <= 14 { return 2 }
        if count <= 21 { return 3 }
        return 5
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Daily Usage")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                if let stat = hoveredStat {
                    HoveredStatLabel(stat: stat)
                }
            }

            if stats.isEmpty {
                EmptyStateView(
                    icon: "chart.bar",
                    message: "No usage data available"
                )
                .frame(height: 100)
            } else {
                if #available(macOS 14.0, *) {
                    SwiftChartsView(
                        stats: stats,
                        labelInterval: labelInterval,
                        hoveredStat: $hoveredStat
                    )
                    .frame(height: 140)
                } else {
                    SimpleBarChart(stats: stats)
                        .frame(height: 140)
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Hovered Stat Label

private struct HoveredStatLabel: View {
    let stat: AnalyticsData.DailyStat

    var body: some View {
        HStack(spacing: 8) {
            Text(stat.dateString)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("\(stat.messageCount) msgs")
                .font(.caption2)
                .fontWeight(.medium)
            Text("\(stat.sessionCount) sessions")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Swift Charts View (macOS 14+)

@available(macOS 14.0, *)
private struct SwiftChartsView: View {
    let stats: [AnalyticsData.DailyStat]
    let labelInterval: Int
    @Binding var hoveredStat: AnalyticsData.DailyStat?

    var body: some View {
        Chart(stats) { stat in
            BarMark(
                x: .value("Date", stat.date, unit: .day),
                y: .value("Messages", stat.messageCount)
            )
            .foregroundStyle(
                hoveredStat?.id == stat.id
                    ? Color.blue
                    : Color.blue.opacity(0.7)
            )
            .cornerRadius(3)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: labelInterval)) { value in
                AxisGridLine()
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(formatAxisDate(date))
                            .font(.system(size: 9))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let count = value.as(Int.self) {
                        Text(formatYAxisValue(count))
                            .font(.system(size: 9))
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { _ in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            if let date: Date = proxy.value(atX: location.x) {
                                let calendar = Calendar.current
                                hoveredStat = stats.first { stat in
                                    calendar.isDate(stat.date, inSameDayAs: date)
                                }
                            }
                        case .ended:
                            hoveredStat = nil
                        }
                    }
            }
        }
    }

    private func formatAxisDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private func formatYAxisValue(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.0fK", Double(count) / 1000)
        }
        return "\(count)"
    }
}

// MARK: - Simple Bar Chart (Fallback for macOS < 14)

struct SimpleBarChart: View {
    let stats: [AnalyticsData.DailyStat]

    var maxCount: Int {
        stats.map(\.messageCount).max() ?? 1
    }

    private var labelInterval: Int {
        let count = stats.count
        if count <= 7 { return 1 }
        if count <= 14 { return 2 }
        if count <= 21 { return 3 }
        return 5
    }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(stats) { stat in
                        let height = maxCount > 0
                            ? CGFloat(stat.messageCount) / CGFloat(maxCount) * geometry.size.height
                            : 0

                        Rectangle()
                            .fill(Color.blue.gradient)
                            .frame(height: max(height, 2))
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            HStack(spacing: 2) {
                ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                    if index % labelInterval == 0 {
                        Text(stat.dateString)
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .lineLimit(1)
                    } else {
                        Text("")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    DailyUsageChart(stats: AnalyticsData.preview.dailyStats)
        .frame(width: 500)
        .padding()
}
