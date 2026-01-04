import SwiftUI

// MARK: - Model Breakdown Chart

struct ModelBreakdownChart: View {
    let models: [AnalyticsData.ModelStat]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model Breakdown")
                .font(.subheadline)
                .fontWeight(.semibold)

            if models.isEmpty {
                EmptyStateView(
                    icon: "chart.bar",
                    message: "No model data available"
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(models) { model in
                        ModelBreakdownRow(model: model)
                    }
                }
            }

            Spacer()
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Model Breakdown Row

struct ModelBreakdownRow: View {
    let model: AnalyticsData.ModelStat

    var modelColor: Color {
        if model.model.contains("opus") {
            return .purple
        } else if model.model.contains("haiku") {
            return .green
        } else {
            return .blue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Circle()
                    .fill(modelColor)
                    .frame(width: 8, height: 8)

                Text(model.displayName)
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                Text(String(format: "%.1f%%", model.percentage))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(String(format: "$%.2f", model.cost))
                    .font(.caption)
                    .fontWeight(.medium)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)
                        .clipShape(RoundedRectangle(cornerRadius: 3))

                    Rectangle()
                        .fill(modelColor)
                        .frame(width: geometry.size.width * (model.percentage / 100), height: 6)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Preview

#Preview {
    ModelBreakdownChart(models: AnalyticsData.preview.modelBreakdown)
        .frame(width: 300, height: 200)
        .padding()
}
