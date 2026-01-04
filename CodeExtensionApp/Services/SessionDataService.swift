import Foundation
import Combine
import os.log

// MARK: - Session Data Service

class SessionDataService: ObservableObject {
    static let shared = SessionDataService()

    // MARK: - Logger

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CodeExtensionApp",
        category: "SessionDataService"
    )

    // MARK: - Published Properties

    @Published var sessionStats: [SessionStats] = []
    @Published var isLoading = false
    @Published var lastError: String?

    // MARK: - Private Properties

    private let claudeDir: URL
    private let projectsDir: URL
    private let dateFormatter: ISO8601DateFormatter

    // MARK: - Init

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        claudeDir = home.appendingPathComponent(".claude")
        projectsDir = claudeDir.appendingPathComponent("projects")

        dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    // MARK: - Load All Sessions

    func loadAllSessions() {
        isLoading = true
        lastError = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var allStats: [SessionStats] = []
            let fm = FileManager.default

            guard fm.fileExists(atPath: self.projectsDir.path) else {
                self.logger.info("Projects directory not found - no session history available yet")
                DispatchQueue.main.async {
                    self.isLoading = false
                    // Not an error - just means no sessions have been created yet
                }
                return
            }

            do {
                let projectDirs = try fm.contentsOfDirectory(
                    at: self.projectsDir,
                    includingPropertiesForKeys: [.isDirectoryKey]
                )

                for projectDir in projectDirs {
                    var isDirectory: ObjCBool = false
                    guard fm.fileExists(atPath: projectDir.path, isDirectory: &isDirectory),
                          isDirectory.boolValue else { continue }

                    let encodedPath = projectDir.lastPathComponent
                    let projectPath = self.decodeProjectPath(encodedPath)
                    let projectName = URL(fileURLWithPath: projectPath).lastPathComponent

                    // Find all .jsonl files in this project directory
                    let contents = try fm.contentsOfDirectory(at: projectDir, includingPropertiesForKeys: nil)
                    let jsonlFiles = contents.filter { $0.pathExtension == "jsonl" }

                    for jsonlFile in jsonlFiles {
                        if let stats = self.parseSessionFile(
                            at: jsonlFile,
                            projectPath: projectPath,
                            projectName: projectName
                        ) {
                            allStats.append(stats)
                        }
                    }
                }

                // Sort by start time, most recent first
                allStats.sort { $0.startTime > $1.startTime }

            } catch {
                self.logger.error("Failed to load sessions: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async {
                    self.lastError = "Failed to load sessions: \(error.localizedDescription)"
                    ErrorHandler.shared.handle(error, context: "Loading Session History")
                }
            }

            DispatchQueue.main.async {
                self.sessionStats = allStats
                self.isLoading = false
            }
        }
    }

    // MARK: - Parse Session File

    func parseSessionFile(at url: URL, projectPath: String, projectName: String) -> SessionStats? {
        guard let data = FileManager.default.contents(atPath: url.path),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }

        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }

        var firstTimestamp: Date?
        var lastTimestamp: Date?
        var messageCount = 0
        var model: String?
        var totalInputTokens = 0
        var totalOutputTokens = 0
        var totalCacheReadTokens = 0
        var totalCacheWriteTokens = 0

        for line in lines {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            // Parse timestamp
            if let timestampStr = json["timestamp"] as? String,
               let timestamp = parseTimestamp(timestampStr) {
                if firstTimestamp == nil {
                    firstTimestamp = timestamp
                }
                lastTimestamp = timestamp
            }

            // Count user and assistant messages
            if let type = json["type"] as? String {
                if type == "user" || type == "assistant" {
                    messageCount += 1
                }
            }

            // Extract model and usage from message object
            if let message = json["message"] as? [String: Any] {
                // Extract model
                if model == nil, let msgModel = message["model"] as? String {
                    model = msgModel
                }

                // Extract usage data
                if let usage = message["usage"] as? [String: Any] {
                    totalInputTokens += usage["input_tokens"] as? Int ?? 0
                    totalOutputTokens += usage["output_tokens"] as? Int ?? 0
                    totalCacheReadTokens += usage["cache_read_input_tokens"] as? Int ?? 0
                    totalCacheWriteTokens += usage["cache_creation_input_tokens"] as? Int ?? 0
                }
            }
        }

        // Calculate duration
        let duration: TimeInterval
        if let start = firstTimestamp, let end = lastTimestamp {
            duration = end.timeIntervalSince(start)
        } else {
            duration = 0
        }

        // Extract session ID from filename
        let sessionId = url.deletingPathExtension().lastPathComponent

        return SessionStats(
            id: sessionId,
            projectPath: projectPath,
            projectName: projectName,
            startTime: firstTimestamp ?? Date(),
            endTime: lastTimestamp,
            duration: duration,
            messageCount: messageCount,
            model: model,
            inputTokens: totalInputTokens,
            outputTokens: totalOutputTokens,
            cacheReadTokens: totalCacheReadTokens,
            cacheWriteTokens: totalCacheWriteTokens
        )
    }

    // MARK: - Load Single Session

    func loadSession(id: String, projectPath: String) -> SessionStats? {
        let encodedPath = encodeProjectPath(projectPath)
        let sessionFile = projectsDir
            .appendingPathComponent(encodedPath)
            .appendingPathComponent("\(id).jsonl")

        let projectName = URL(fileURLWithPath: projectPath).lastPathComponent

        return parseSessionFile(at: sessionFile, projectPath: projectPath, projectName: projectName)
    }

    // MARK: - Path Encoding/Decoding

    /// Converts encoded path like "-Users-foo-bar" to "/Users/foo/bar"
    func decodeProjectPath(_ encoded: String) -> String {
        // Replace leading dash with slash, then all other dashes with slashes
        var result = encoded

        // Handle the leading dash (represents root /)
        if result.hasPrefix("-") {
            result = "/" + result.dropFirst()
        }

        // Replace remaining dashes with slashes
        result = result.replacingOccurrences(of: "-", with: "/")

        return result
    }

    /// Converts path like "/Users/foo/bar" to encoded "-Users-foo-bar"
    func encodeProjectPath(_ path: String) -> String {
        var result = path

        // Replace slashes with dashes
        result = result.replacingOccurrences(of: "/", with: "-")

        return result
    }

    // MARK: - Timestamp Parsing

    private func parseTimestamp(_ timestampStr: String) -> Date? {
        // Try ISO8601 with fractional seconds first
        if let date = dateFormatter.date(from: timestampStr) {
            return date
        }

        // Try without fractional seconds
        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]
        return fallbackFormatter.date(from: timestampStr)
    }

    // MARK: - Aggregated Stats

    var totalTokensUsed: Int {
        sessionStats.reduce(0) { $0 + $1.totalTokens }
    }

    var totalCost: Double {
        sessionStats.reduce(0) { $0 + $1.estimatedCost }
    }

    var totalSessions: Int {
        sessionStats.count
    }

    var uniqueProjects: Int {
        Set(sessionStats.map { $0.projectPath }).count
    }

    /// Get sessions for a specific project
    func sessions(for projectPath: String) -> [SessionStats] {
        sessionStats.filter { $0.projectPath == projectPath }
    }

    /// Get sessions from today
    var todaysSessions: [SessionStats] {
        let calendar = Calendar.current
        return sessionStats.filter { calendar.isDateInToday($0.startTime) }
    }

    /// Get sessions from the last 7 days
    var lastWeekSessions: [SessionStats] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return sessionStats.filter { $0.startTime >= weekAgo }
    }
}
