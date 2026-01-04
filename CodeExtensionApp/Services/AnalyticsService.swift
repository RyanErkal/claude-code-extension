import Foundation
import Combine
import os.log

// MARK: - Analytics Service

class AnalyticsService: ObservableObject {
    static let shared = AnalyticsService()

    @Published var analyticsData = AnalyticsData()
    @Published var selectedPeriod: TimePeriod = .week
    @Published var isLoading = false

    private let statsFileURL: URL
    private let dateFormatter: DateFormatter

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CodeExtensionApp",
        category: "AnalyticsService"
    )

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.statsFileURL = home
            .appendingPathComponent(".claude")
            .appendingPathComponent("stats-cache.json")

        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd"
        self.dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    }

    // MARK: - Load Analytics

    func loadAnalytics() {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let data = self.loadStatsCache()
            let analytics = self.computeAnalytics(from: data, period: self.selectedPeriod)

            DispatchQueue.main.async {
                self.analyticsData = analytics
                self.isLoading = false
            }
        }
    }

    // MARK: - Load Stats Cache

    private func loadStatsCache() -> EnhancedStatsCache? {
        guard FileManager.default.fileExists(atPath: statsFileURL.path) else {
            logger.info("Stats cache file not found at: \(self.statsFileURL.path, privacy: .public)")
            return nil
        }

        guard let data = SecurityValidator.loadSecureData(from: statsFileURL) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(EnhancedStatsCache.self, from: data)
        } catch {
            logger.error("Error loading stats cache: \(error.localizedDescription, privacy: .public)")
            ErrorHandler.shared.handle(error, context: "Loading Analytics")
            return nil
        }
    }

    // MARK: - Compute Analytics

    func computeAnalytics(from cache: EnhancedStatsCache?, period: TimePeriod) -> AnalyticsData {
        guard let cache = cache else {
            return AnalyticsData()
        }

        var analytics = AnalyticsData()
        let cutoff = cutoffDate(for: period)

        // Filter daily activity by period
        let filteredActivity = cache.dailyActivity.filter { entry in
            guard let date = dateFormatter.date(from: entry.date) else { return false }
            return date >= cutoff
        }

        // Filter dailyModelTokens by period and aggregate tokens per model
        var filteredTokensByModel: [String: Int] = [:]
        var tokensByDate: [String: Int] = [:]

        for dailyTokens in cache.dailyModelTokens {
            guard let date = dateFormatter.date(from: dailyTokens.date),
                  date >= cutoff else { continue }

            // Aggregate for daily stats
            let total = dailyTokens.tokensByModel.values.reduce(0, +)
            tokensByDate[dailyTokens.date] = total

            // Aggregate per model for cost calculation
            for (model, tokens) in dailyTokens.tokensByModel {
                filteredTokensByModel[model, default: 0] += tokens
            }
        }

        // Compute daily stats
        analytics.dailyStats = filteredActivity.compactMap { entry in
            guard let date = dateFormatter.date(from: entry.date) else { return nil }
            let tokens = tokensByDate[entry.date] ?? 0

            return AnalyticsData.DailyStat(
                date: date,
                messageCount: entry.messageCount,
                sessionCount: entry.sessionCount,
                tokens: tokens
            )
        }.sorted { $0.date < $1.date }

        // Compute model breakdown using filtered token data
        // Use ratios from all-time modelUsage to estimate input/output/cache breakdown
        var totalCostFiltered: Double = 0
        var modelStats: [AnalyticsData.ModelStat] = []

        for (model, usage) in cache.modelUsage {
            let pricing = ModelPricing.pricing(for: model)

            // Get filtered tokens for this model (from dailyModelTokens)
            // Note: dailyModelTokens only tracks input+output, not cache tokens
            let filteredTokens = filteredTokensByModel[model] ?? 0

            // Calculate all-time input+output (what dailyModelTokens tracks)
            let allTimeInputOutput = usage.inputTokens + usage.outputTokens

            // Calculate scaling factor based on input+output only
            let scale: Double = allTimeInputOutput > 0 ? Double(filteredTokens) / Double(allTimeInputOutput) : 0

            // Estimate period token breakdown using the scale
            let periodInputTokens = Int(Double(usage.inputTokens) * scale)
            let periodOutputTokens = Int(Double(usage.outputTokens) * scale)
            let periodCacheReadTokens = Int(Double(usage.cacheReadInputTokens) * scale)
            let periodCacheWriteTokens = Int(Double(usage.cacheCreationInputTokens) * scale)

            // Calculate cost for the filtered period
            let cost = (Double(periodInputTokens) / 1_000_000 * pricing.inputPerMTok) +
                       (Double(periodOutputTokens) / 1_000_000 * pricing.outputPerMTok) +
                       (Double(periodCacheReadTokens) / 1_000_000 * pricing.cacheReadPerMTok) +
                       (Double(periodCacheWriteTokens) / 1_000_000 * pricing.cacheWritePerMTok)

            totalCostFiltered += cost

            let stat = AnalyticsData.ModelStat(
                model: model,
                displayName: formatModelName(model),
                inputTokens: periodInputTokens,
                outputTokens: periodOutputTokens,
                cacheReadTokens: periodCacheReadTokens,
                cacheWriteTokens: periodCacheWriteTokens,
                cost: cost,
                percentage: 0 // Will be calculated after
            )
            modelStats.append(stat)
        }

        // Calculate percentages
        analytics.modelBreakdown = modelStats.map { stat in
            let percentage = totalCostFiltered > 0 ? (stat.cost / totalCostFiltered) * 100 : 0
            return AnalyticsData.ModelStat(
                model: stat.model,
                displayName: stat.displayName,
                inputTokens: stat.inputTokens,
                outputTokens: stat.outputTokens,
                cacheReadTokens: stat.cacheReadTokens,
                cacheWriteTokens: stat.cacheWriteTokens,
                cost: stat.cost,
                percentage: percentage
            )
        }.sorted { $0.cost > $1.cost }

        // Compute hourly activity
        analytics.hourlyActivity = cache.hourCounts.compactMap { hourStr, count in
            guard let hour = Int(hourStr) else { return nil }
            return AnalyticsData.HourlyStat(hour: hour, count: count)
        }.sorted { $0.hour < $1.hour }

        // Calculate totals (all now using filtered data)
        analytics.totalCost = totalCostFiltered
        analytics.totalSessions = filteredActivity.reduce(0) { $0 + $1.sessionCount }
        analytics.totalMessages = filteredActivity.reduce(0) { $0 + $1.messageCount }
        analytics.totalTokens = analytics.dailyStats.reduce(0) { $0 + $1.tokens }

        // Calculate cache efficiency and savings (also using filtered estimates)
        var totalInput: Int = 0
        var totalCacheRead: Int = 0
        var cacheSavings: Double = 0

        for stat in modelStats {
            let pricing = ModelPricing.pricing(for: stat.model)

            totalInput += stat.inputTokens
            totalCacheRead += stat.cacheReadTokens

            // Cache savings = what cached tokens would have cost at full input price
            let fullCost = Double(stat.cacheReadTokens) / 1_000_000 * pricing.inputPerMTok
            let cachedCost = Double(stat.cacheReadTokens) / 1_000_000 * pricing.cacheReadPerMTok
            cacheSavings += (fullCost - cachedCost)
        }

        let totalInputTokens = totalInput + totalCacheRead
        analytics.cacheEfficiency = totalInputTokens > 0
            ? (Double(totalCacheRead) / Double(totalInputTokens)) * 100
            : 0
        analytics.cacheSavings = cacheSavings

        return analytics
    }

    // MARK: - Cutoff Date

    func cutoffDate(for period: TimePeriod) -> Date {
        let calendar = Calendar.current
        let now = Date()

        switch period {
        case .day:
            // Show last 2 days to handle stale cache data
            return calendar.date(byAdding: .day, value: -2, to: now) ?? now
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            return calendar.date(byAdding: .day, value: -30, to: now) ?? now
        case .all:
            return Date.distantPast
        }
    }

    // MARK: - Format Model Name

    func formatModelName(_ model: String) -> String {
        if model.contains("opus") {
            return "Opus 4.5"
        } else if model.contains("sonnet") {
            return "Sonnet 4.5"
        } else if model.contains("haiku") {
            return "Haiku 4.5"
        } else {
            // Fallback: Clean up the model ID
            return model
                .replacingOccurrences(of: "claude-", with: "")
                .replacingOccurrences(of: "-", with: " ")
                .capitalized
        }
    }

    // MARK: - Refresh on Period Change

    func setPeriod(_ period: TimePeriod) {
        selectedPeriod = period
        loadAnalytics()
    }
}
