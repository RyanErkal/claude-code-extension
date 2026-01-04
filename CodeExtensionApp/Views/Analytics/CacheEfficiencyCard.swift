import SwiftUI

// MARK: - Cache Efficiency Card

struct CacheEfficiencyCard: View {
    let efficiency: Double
    let savings: Double

    private var formattedSavings: String {
        if savings >= 1000 {
            return String(format: "$%.1fK", savings / 1000)
        } else if savings >= 100 {
            return String(format: "$%.0f", savings)
        } else {
            return String(format: "$%.2f", savings)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cache Stats")
                .font(.subheadline)
                .fontWeight(.semibold)

            Spacer()

            HStack {
                Spacer()
                EfficiencyRing(efficiency: efficiency)
                Spacer()
            }

            Spacer()

            HStack {
                Spacer()
                SavingsLabel(formattedSavings: formattedSavings)
                Spacer()
            }

            Spacer()
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Efficiency Ring

private struct EfficiencyRing: View {
    let efficiency: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 6)
                .frame(width: 70, height: 70)

            Circle()
                .trim(from: 0, to: efficiency / 100)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 70, height: 70)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text(String(format: "%.0f%%", efficiency))
                    .font(.caption)
                    .fontWeight(.bold)
                Text("hit rate")
                    .font(.system(size: 7))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Savings Label

private struct SavingsLabel: View {
    let formattedSavings: String

    var body: some View {
        VStack(spacing: 2) {
            Text(formattedSavings)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.green)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("saved")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    CacheEfficiencyCard(efficiency: 75.5, savings: 45.30)
        .frame(width: 180, height: 200)
        .padding()
}
