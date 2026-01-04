import Foundation

// MARK: - Global Settings (~/.claude/settings.json)

struct ClaudeSettings: Codable {
    var permissions: Permissions
    var statusLine: StatusLine?
    var hooks: [String: [HookConfig]]?

    enum CodingKeys: String, CodingKey {
        case permissions
        case statusLine
        case hooks
    }
}

struct Permissions: Codable {
    var allow: [String]
    var deny: [String]
    var ask: [String]
    var defaultMode: String?

    init(allow: [String] = [], deny: [String] = [], ask: [String] = [], defaultMode: String? = nil) {
        self.allow = allow
        self.deny = deny
        self.ask = ask
        self.defaultMode = defaultMode
    }
}

struct StatusLine: Codable {
    var type: String?
    var command: String?
}

struct HookConfig: Codable, Identifiable {
    var id: UUID = UUID()
    var matcher: String?
    var hooks: [HookAction]?

    enum CodingKeys: String, CodingKey {
        case matcher
        case hooks
    }
}

struct HookAction: Codable, Identifiable {
    var id: UUID = UUID()
    var type: String
    var command: String?

    enum CodingKeys: String, CodingKey {
        case type
        case command
    }
}

// MARK: - Local Settings (project/.claude/settings.local.json)

struct LocalSettings: Codable {
    var permissions: Permissions?
    var hooks: [String: [HookConfig]]?
}

// MARK: - Stats Cache (~/.claude/stats-cache.json)

struct StatsCache: Codable {
    var dailyMetrics: [String: DailyMetric]?
    var totalSessions: Int?
    var totalMessages: Int?

    struct DailyMetric: Codable {
        var messageCount: Int?
        var sessionCount: Int?
        var toolCalls: Int?
    }
}
