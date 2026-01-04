import SwiftUI

// MARK: - Summary Cards Row

struct SummaryCardsRow: View {
    let data: AnalyticsData

    private func formatCost(_ cost: Double) -> String {
        if cost >= 1000 {
            return String(format: "$%.1fK", cost / 1000)
        } else if cost >= 100 {
            return String(format: "$%.0f", cost)
        } else {
            return String(format: "$%.2f", cost)
        }
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        }
        return "\(count)"
    }

    var body: some View {
        HStack(spacing: 8) {
            SummaryCard(
                icon: "dollarsign.circle",
                title: "Cost",
                value: formatCost(data.totalCost),
                color: .blue
            )

            SummaryCard(
                icon: "rectangle.stack",
                title: "Sessions",
                value: formatCount(data.totalSessions),
                color: .purple
            )

            SummaryCard(
                icon: "message",
                title: "Messages",
                value: formatCount(data.totalMessages),
                color: .green
            )

            SummaryCard(
                icon: "arrow.down.circle",
                title: "Saved",
                value: formatCost(data.cacheSavings),
                color: .orange
            )
        }
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                    .frame(width: 24, height: 24)
                    .background(color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview("Summary Card") {
    SummaryCard(
        icon: "dollarsign.circle",
        title: "Cost",
        value: "$12.50",
        color: .blue
    )
    .frame(width: 120)
    .padding()
}

#Preview("Summary Cards Row") {
    SummaryCardsRow(data: AnalyticsData.preview)
        .padding()
}
