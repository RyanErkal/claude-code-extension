import SwiftUI

// MARK: - Activity Heatmap

struct ActivityHeatmap: View {
    let hourlyStats: [AnalyticsData.HourlyStat]

    var maxCount: Int {
        hourlyStats.map(\.count).max() ?? 1
    }

    var sortedStats: [AnalyticsData.HourlyStat] {
        var allHours: [AnalyticsData.HourlyStat] = []
        let existingHours = Dictionary(uniqueKeysWithValues: hourlyStats.map { ($0.hour, $0) })

        for hour in 0..<24 {
            if let existing = existingHours[hour] {
                allHours.append(existing)
            } else {
                allHours.append(AnalyticsData.HourlyStat(hour: hour, count: 0))
            }
        }
        return allHours
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Activity by Hour")
                .font(.subheadline)
                .fontWeight(.semibold)

            VStack(spacing: 4) {
                HStack(spacing: 2) {
                    ForEach(sortedStats) { stat in
                        let intensity = maxCount > 0
                            ? Double(stat.count) / Double(maxCount)
                            : 0

                        Rectangle()
                            .fill(Color.green.opacity(0.1 + intensity * 0.9))
                            .frame(height: 24)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                            .help("\(stat.hourLabel): \(stat.count) messages")
                    }
                }

                HStack(spacing: 2) {
                    ForEach(sortedStats) { stat in
                        if stat.hour % 6 == 0 {
                            Text("\(stat.hour)")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview {
    ActivityHeatmap(hourlyStats: AnalyticsData.preview.hourlyActivity)
        .frame(width: 500)
        .padding()
}
