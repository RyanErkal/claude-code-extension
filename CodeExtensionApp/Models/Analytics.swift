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
