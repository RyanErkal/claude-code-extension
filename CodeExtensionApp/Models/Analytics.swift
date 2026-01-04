//
//  Analytics.swift
//  CodeExtensionApp
//
//  Data models for session statistics and analytics features
//

import Foundation

// MARK: - Model Pricing

struct ModelPricing {
    let inputPerMTok: Double
    let outputPerMTok: Double
    let cacheReadPerMTok: Double
    let cacheWritePerMTok: Double

    // Claude Opus 4.5 pricing (Jan 2025)
    static let opus45 = ModelPricing(
        inputPerMTok: 5.0,
        outputPerMTok: 25.0,
        cacheReadPerMTok: 0.50,
        cacheWritePerMTok: 6.25
    )

    // Claude Sonnet 4/4.5 pricing (Jan 2025)
    static let sonnet45 = ModelPricing(
        inputPerMTok: 3.0,
        outputPerMTok: 15.0,
        cacheReadPerMTok: 0.30,
        cacheWritePerMTok: 3.75
    )

    // Claude Haiku 4.5 pricing (Jan 2025)
    static let haiku45 = ModelPricing(
        inputPerMTok: 1.0,
        outputPerMTok: 5.0,
        cacheReadPerMTok: 0.10,
        cacheWritePerMTok: 1.25
    )

    static func pricing(for model: String) -> ModelPricing {
        let lowercased = model.lowercased()
        if lowercased.contains("opus") { return .opus45 }
        if lowercased.contains("haiku") { return .haiku45 }
        return .sonnet45
    }
}

// MARK: - Session Stats

struct SessionStats: Identifiable {
    let id: String
    let projectPath: String
    let projectName: String
    /// The encoded directory name under `~/.claude/projects/` where this session file lives.
    let encodedProjectPath: String
    /// The exact session file location (e.g. `~/.claude/projects/<encoded>/<id>.jsonl`).
    let fileURL: URL
    let startTime: Date
    let endTime: Date?
    let duration: TimeInterval
    let messageCount: Int
    let model: String?
    let inputTokens: Int
    let outputTokens: Int
    let cacheReadTokens: Int
    let cacheWriteTokens: Int

    var totalTokens: Int {
        inputTokens + outputTokens
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    var estimatedCost: Double {
        let pricing = ModelPricing.pricing(for: model ?? "sonnet")
        let inputCost = Double(inputTokens) / 1_000_000 * pricing.inputPerMTok
        let outputCost = Double(outputTokens) / 1_000_000 * pricing.outputPerMTok
        let cacheReadCost = Double(cacheReadTokens) / 1_000_000 * pricing.cacheReadPerMTok
        let cacheWriteCost = Double(cacheWriteTokens) / 1_000_000 * pricing.cacheWritePerMTok
        return inputCost + outputCost + cacheReadCost + cacheWriteCost
    }

    var formattedCost: String {
        String(format: "$%.4f", estimatedCost)
    }
}

// MARK: - Session Message (JSONL Parsing)

struct SessionMessage: Codable {
    let parentUuid: String?
    let sessionId: String?
    let cwd: String?
    let type: String?
    let timestamp: String?
    let message: MessageContent?

    struct MessageContent: Codable {
        let model: String?
        let role: String?
        let usage: UsageData?
    }

    struct UsageData: Codable {
        let input_tokens: Int?
        let output_tokens: Int?
        let cache_read_input_tokens: Int?
        let cache_creation_input_tokens: Int?
    }
}

// MARK: - Enhanced Stats Cache (matches ~/.claude/stats-cache.json)

struct EnhancedStatsCache: Codable {
    var version: Int
    var lastComputedDate: String
    var dailyActivity: [DailyActivityEntry]
    var dailyModelTokens: [DailyModelTokens]
    var modelUsage: [String: ModelUsageStats]
    var totalSessions: Int
    var totalMessages: Int
    var longestSession: LongestSessionInfo?
    var firstSessionDate: String?
    var hourCounts: [String: Int]

    struct DailyActivityEntry: Codable {
        var date: String
        var messageCount: Int
        var sessionCount: Int
        var toolCallCount: Int
    }

    struct DailyModelTokens: Codable {
        var date: String
        var tokensByModel: [String: Int]
    }

    struct ModelUsageStats: Codable {
        var inputTokens: Int
        var outputTokens: Int
        var cacheReadInputTokens: Int
        var cacheCreationInputTokens: Int
        var webSearchRequests: Int
        var costUSD: Double
        var contextWindow: Int
    }

    struct LongestSessionInfo: Codable {
        var sessionId: String
        var duration: Int
        var messageCount: Int
        var timestamp: String
    }
}

// MARK: - Analytics Data

struct AnalyticsData {
    var dailyStats: [DailyStat] = []
    var modelBreakdown: [ModelStat] = []
    var hourlyActivity: [HourlyStat] = []
    var totalCost: Double = 0
    var totalTokens: Int = 0
    var totalSessions: Int = 0
    var totalMessages: Int = 0
    var cacheEfficiency: Double = 0
    var cacheSavings: Double = 0

    struct DailyStat: Identifiable {
        let id = UUID()
        let date: Date
        let messageCount: Int
        let sessionCount: Int
        let tokens: Int

        var dateString: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }

    struct ModelStat: Identifiable {
        let id = UUID()
        let model: String
        let displayName: String
        let inputTokens: Int
        let outputTokens: Int
        let cacheReadTokens: Int
        let cacheWriteTokens: Int
        let cost: Double
        let percentage: Double

        var totalTokens: Int {
            inputTokens + outputTokens + cacheReadTokens + cacheWriteTokens
        }
    }

    struct HourlyStat: Identifiable {
        let id = UUID()
        let hour: Int
        let count: Int

        var hourLabel: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "ha"
            var components = DateComponents()
            components.hour = hour
            let date = Calendar.current.date(from: components) ?? Date()
            return formatter.string(from: date).lowercased()
        }
    }
}

// MARK: - Time Period

enum TimePeriod: String, CaseIterable, Identifiable {
    case day = "24h"
    case week = "7d"
    case month = "30d"
    case all = "All"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .day: return "Today"
        case .week: return "Week"
        case .month: return "Month"
        case .all: return "All Time"
        }
    }
}

// MARK: - Preview Data

extension AnalyticsData {
    static var preview: AnalyticsData {
        var data = AnalyticsData()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Daily stats (last 7 days)
        data.dailyStats = (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -(6 - offset), to: today) else { return nil }
            return AnalyticsData.DailyStat(
                date: date,
                messageCount: [12, 28, 6, 40, 18, 33, 22][offset],
                sessionCount: [1, 2, 1, 3, 2, 2, 1][offset],
                tokens: [24_000, 62_000, 11_000, 95_000, 45_000, 71_000, 38_000][offset]
            )
        }

        // Model breakdown (sample)
        let modelStats: [AnalyticsData.ModelStat] = [
            .init(
                model: "claude-opus-4.5",
                displayName: "Opus 4.5",
                inputTokens: 120_000,
                outputTokens: 45_000,
                cacheReadTokens: 60_000,
                cacheWriteTokens: 20_000,
                cost: 1.92,
                percentage: 62.0
            ),
            .init(
                model: "claude-sonnet-4.5",
                displayName: "Sonnet 4.5",
                inputTokens: 85_000,
                outputTokens: 30_000,
                cacheReadTokens: 40_000,
                cacheWriteTokens: 12_000,
                cost: 0.94,
                percentage: 30.0
            ),
            .init(
                model: "claude-haiku-4.5",
                displayName: "Haiku 4.5",
                inputTokens: 18_000,
                outputTokens: 6_000,
                cacheReadTokens: 8_000,
                cacheWriteTokens: 2_000,
                cost: 0.25,
                percentage: 8.0
            )
        ]
        data.modelBreakdown = modelStats

        // Hourly activity (simple bell-ish curve)
        data.hourlyActivity = (0..<24).map { hour in
            let peak = 15 // 3pm
            let distance = abs(hour - peak)
            let count = max(0, 20 - (distance * 2))
            return AnalyticsData.HourlyStat(hour: hour, count: count)
        }

        data.totalSessions = data.dailyStats.reduce(0) { $0 + $1.sessionCount }
        data.totalMessages = data.dailyStats.reduce(0) { $0 + $1.messageCount }
        data.totalTokens = data.dailyStats.reduce(0) { $0 + $1.tokens }
        data.totalCost = data.modelBreakdown.reduce(0) { $0 + $1.cost }

        // Cache metrics (sample)
        data.cacheSavings = 0.67
        data.cacheEfficiency = 38.0

        return data
    }
}
