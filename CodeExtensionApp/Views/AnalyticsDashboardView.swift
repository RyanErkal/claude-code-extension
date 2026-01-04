import SwiftUI
import Charts

// MARK: - Analytics Dashboard View

struct AnalyticsDashboardView: View {
    @StateObject private var analyticsService = AnalyticsService.shared
    @State private var selectedPeriod: TimePeriod = .week

    var body: some View {
        VStack(spacing: 0) {
            AnalyticsHeader(
                selectedPeriod: $selectedPeriod,
                isLoading: analyticsService.isLoading,
                onRefresh: { analyticsService.loadAnalytics() }
            )

            Divider()

            if analyticsService.isLoading {
                AnalyticsLoadingView()
            } else {
                AnalyticsContentView(data: analyticsService.analyticsData)
            }
        }
        .onAppear {
            analyticsService.loadAnalytics()
        }
        .onChange(of: selectedPeriod) { _, newValue in
            analyticsService.setPeriod(newValue)
        }
    }
}

// MARK: - Analytics Header

private struct AnalyticsHeader: View {
    @Binding var selectedPeriod: TimePeriod
    let isLoading: Bool
    let onRefresh: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("Analytics")
                .font(.title3)
                .fontWeight(.semibold)

            Spacer()

            Picker("Period", selection: $selectedPeriod) {
                ForEach(TimePeriod.allCases) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            Button {
                onRefresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Analytics Loading View

private struct AnalyticsLoadingView: View {
    var body: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading analytics...")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Analytics Content View

private struct AnalyticsContentView: View {
    let data: AnalyticsData

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SummaryCardsRow(data: data)

                DailyUsageChart(stats: data.dailyStats)

                HStack(spacing: 16) {
                    ModelBreakdownChart(models: data.modelBreakdown)
                    CacheEfficiencyCard(
                        efficiency: data.cacheEfficiency,
                        savings: data.cacheSavings
                    )
                }

                ActivityHeatmap(hourlyStats: data.hourlyActivity)
            }
            .padding(16)
        }
    }
}

// MARK: - Preview

#Preview {
    AnalyticsDashboardView()
        .frame(width: 600, height: 500)
}
