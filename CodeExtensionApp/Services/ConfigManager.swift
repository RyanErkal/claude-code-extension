import Foundation
import Combine
import AppKit
import os.log

// MARK: - Config Manager

/// Facade that coordinates all configuration-related services.
/// Delegates to specialized services for MCP servers, skills, hooks, and CLAUDE.md.
class ConfigManager: ObservableObject {
    static let shared = ConfigManager()

    // MARK: - Services

    private let mcpService = MCPServerService.shared
    private let skillService = SkillService.shared
    private let hookService = HookService.shared
    private let claudeMDService = ClaudeMDService.shared

    // MARK: - Logger

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CodeExtensionApp",
        category: "ConfigManager"
    )

    // MARK: - Published State

    @Published var globalSettings: ClaudeSettings?
    @Published var globalMCPServers: [NamedMCPServer] = []
    @Published var globalSkills: [Skill] = []
    @Published var globalCommands: [Skill] = []
    @Published var statsCache: StatsCache?
    @Published var isLoading = false
    @Published var lastError: String?

    // MARK: - Paths

    private let claudeDir: URL
    private let settingsPath: URL
    private let statsCachePath: URL

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        claudeDir = home.appendingPathComponent(".claude")
        settingsPath = claudeDir.appendingPathComponent("settings.json")
        statsCachePath = claudeDir.appendingPathComponent("stats-cache.json")
    }

    // MARK: - Load All

    func loadAll() {
        isLoading = true
        lastError = nil
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let (settings, settingsError) = self.readGlobalSettings()
            let mcpResult = self.mcpService.loadGlobalMCPServers()
            let skills = self.skillService.loadGlobalSkills()
            let commands = self.skillService.loadGlobalCommands()
            let stats = self.readStatsCache()

            DispatchQueue.main.async {
                self.globalSettings = settings
                self.globalMCPServers = mcpResult.servers
                self.globalSkills = skills
                self.globalCommands = commands
                self.statsCache = stats

                self.lastError = settingsError ?? mcpResult.error
                self.isLoading = false
            }
        }
    }

    // MARK: - Global MCP Servers

    func loadGlobalMCPServers() {
        let result = mcpService.loadGlobalMCPServers()
        globalMCPServers = result.servers

        if let error = result.error {
            lastError = error
        }
    }

    // MARK: - Global Settings

    func loadGlobalSettings() {
        let (settings, error) = readGlobalSettings()
        globalSettings = settings
        if let error {
            lastError = error
        }
    }

    func saveGlobalSettings() {
        guard let settings = globalSettings else { return }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)
            try data.write(to: settingsPath)
        } catch {
            lastError = "Failed to save settings: \(error.localizedDescription)"
            logger.error("Error saving settings: \(error.localizedDescription, privacy: .public)")
            ErrorHandler.shared.handle(error, context: "Saving Settings")
        }
    }

    // MARK: - Permissions Management

    func addPermission(_ permission: String, to list: PermissionList) {
        guard var settings = globalSettings else { return }

        switch list {
        case .allow:
            if !settings.permissions.allow.contains(permission) {
                settings.permissions.allow.append(permission)
            }
        case .deny:
            if !settings.permissions.deny.contains(permission) {
                settings.permissions.deny.append(permission)
            }
        case .ask:
            if !settings.permissions.ask.contains(permission) {
                settings.permissions.ask.append(permission)
            }
        }

        globalSettings = settings
        saveGlobalSettings()
    }

    func removePermission(_ permission: String, from list: PermissionList) {
        guard var settings = globalSettings else { return }

        switch list {
        case .allow:
            settings.permissions.allow.removeAll { $0 == permission }
        case .deny:
            settings.permissions.deny.removeAll { $0 == permission }
        case .ask:
            settings.permissions.ask.removeAll { $0 == permission }
        }

        globalSettings = settings
        saveGlobalSettings()
    }

    func movePermission(_ permission: String, from: PermissionList, to: PermissionList) {
        removePermission(permission, from: from)
        addPermission(permission, to: to)
    }

    enum PermissionList {
        case allow, deny, ask
    }

    // MARK: - Skills

    func loadGlobalSkills() {
        globalSkills = skillService.loadGlobalSkills()
    }

    func loadGlobalCommands() {
        globalCommands = skillService.loadGlobalCommands()
    }

    // MARK: - Stats Cache

    func loadStatsCache() {
        statsCache = readStatsCache()
    }

    // MARK: - Internal Reads (Background-safe)

    private func readGlobalSettings() -> (ClaudeSettings?, String?) {
        guard FileManager.default.fileExists(atPath: settingsPath.path) else {
            return (
                ClaudeSettings(permissions: Permissions(allow: [], deny: [], ask: [])),
                nil
            )
        }

        var errorMessage: String?
        guard let data = SecurityValidator.loadSecureData(from: settingsPath, errorHandler: { error in
            errorMessage = error
        }) else {
            return (nil, errorMessage)
        }

        do {
            return (try JSONDecoder().decode(ClaudeSettings.self, from: data), errorMessage)
        } catch {
            let message = "Failed to load settings: \(error.localizedDescription)"
            logger.error("Error loading settings: \(error.localizedDescription, privacy: .public)")
            ErrorHandler.shared.handle(error, context: "Loading Settings")
            return (nil, message)
        }
    }

    private func readStatsCache() -> StatsCache? {
        guard FileManager.default.fileExists(atPath: statsCachePath.path) else { return nil }
        guard let data = SecurityValidator.loadSecureData(from: statsCachePath) else { return nil }

        // Try the newer enhanced schema first, then fall back to the older minimal schema.
        if let enhanced = try? JSONDecoder().decode(EnhancedStatsCache.self, from: data) {
            let daily: [String: StatsCache.DailyMetric] = Dictionary(
                uniqueKeysWithValues: enhanced.dailyActivity.map { entry in
                    (
                        entry.date,
                        StatsCache.DailyMetric(
                            messageCount: entry.messageCount,
                            sessionCount: entry.sessionCount,
                            toolCalls: entry.toolCallCount
                        )
                    )
                }
            )

            return StatsCache(
                dailyMetrics: daily,
                totalSessions: enhanced.totalSessions,
                totalMessages: enhanced.totalMessages
            )
        }

        do {
            return try JSONDecoder().decode(StatsCache.self, from: data)
        } catch {
            logger.error("Error loading stats cache: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Project Settings

    func loadLocalSettings(for project: DiscoveredProject) -> LocalSettings? {
        let settingsPath = URL(fileURLWithPath: project.path)
            .appendingPathComponent(".claude")
            .appendingPathComponent("settings.local.json")

        guard FileManager.default.fileExists(atPath: settingsPath.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: settingsPath)
            return try JSONDecoder().decode(LocalSettings.self, from: data)
        } catch {
            logger.error("Error loading local settings: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func saveLocalSettings(_ settings: LocalSettings, for project: DiscoveredProject) {
        let settingsPath = URL(fileURLWithPath: project.path)
            .appendingPathComponent(".claude")
            .appendingPathComponent("settings.local.json")

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)
            try data.write(to: settingsPath)
        } catch {
            lastError = "Failed to save local settings: \(error.localizedDescription)"
        }
    }

    // MARK: - MCP Servers (per project)

    func loadMCPServers(for project: DiscoveredProject) -> [NamedMCPServer] {
        mcpService.loadMCPServers(for: project)
    }

    // MARK: - Project Skills & Commands

    func loadProjectSkills(for project: DiscoveredProject) -> [Skill] {
        skillService.loadProjectSkills(for: project)
    }

    func loadProjectCommands(for project: DiscoveredProject) -> [Skill] {
        skillService.loadProjectCommands(for: project)
    }

    func loadAgents(for project: DiscoveredProject) -> [Agent] {
        skillService.loadAgents(for: project)
    }

    // MARK: - CLAUDE.md

    func loadClaudeMD(global: Bool = true, project: DiscoveredProject? = nil) -> String? {
        claudeMDService.loadClaudeMD(global: global, project: project)
    }

    func saveClaudeMD(_ content: String, global: Bool = true, project: DiscoveredProject? = nil) {
        if let error = claudeMDService.saveClaudeMD(content, global: global, project: project) {
            lastError = error
        }
    }

    // MARK: - Create/Delete Skills

    func createSkill(name: String, description: String, allowedTools: String?, model: String?) -> Bool {
        switch skillService.createSkill(
            name: name,
            description: description,
            allowedTools: allowedTools,
            model: model
        ) {
        case .success:
            loadGlobalSkills()
            return true
        case .failure(let error):
            lastError = error.message
            return false
        }
    }

    func deleteSkill(_ skill: Skill) -> Bool {
        switch skillService.deleteSkill(skill) {
        case .success:
            loadGlobalSkills()
            return true
        case .failure(let error):
            lastError = error.message
            return false
        }
    }

    // MARK: - Create/Delete Commands

    func createCommand(name: String, description: String) -> Bool {
        switch skillService.createCommand(name: name, description: description) {
        case .success:
            loadGlobalCommands()
            return true
        case .failure(let error):
            lastError = error.message
            return false
        }
    }

    func deleteCommand(_ command: Skill) -> Bool {
        switch skillService.deleteCommand(command) {
        case .success:
            loadGlobalCommands()
            return true
        case .failure(let error):
            lastError = error.message
            return false
        }
    }

    // MARK: - Hooks Management

    func addHook(event: String, matcher: String, command: String) {
        guard let settings = globalSettings else { return }

        globalSettings = hookService.addHook(
            event: event,
            matcher: matcher,
            command: command,
            to: settings
        )
        saveGlobalSettings()
    }

    func removeHook(event: String, at index: Int) {
        guard let settings = globalSettings else { return }

        globalSettings = hookService.removeHook(
            event: event,
            at: index,
            from: settings
        )
        saveGlobalSettings()
    }

    // MARK: - Open in Editor

    func openInEditor(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    // MARK: - Load Hook Script Content

    func loadHookScriptContent(from command: String) -> String? {
        hookService.loadHookScriptContent(from: command)
    }

    func getScriptURL(from command: String) -> URL? {
        hookService.getScriptURL(from: command)
    }
}
