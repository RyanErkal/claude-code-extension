import Foundation
import os.log

// MARK: - MCP Server Service

/// Handles loading and managing MCP (Model Context Protocol) servers
/// from both global (~/.claude.json) and project-specific configurations.
final class MCPServerService {
    static let shared = MCPServerService()

    // MARK: - Logger

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CodeExtensionApp",
        category: "MCPServerService"
    )

    // MARK: - Paths

    private let claudeJsonPath: URL

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        claudeJsonPath = home.appendingPathComponent(".claude.json")
    }

    // MARK: - Load Global MCP Servers

    /// Loads all MCP servers from ~/.claude.json (both global and per-project)
    /// - Returns: A tuple containing the servers and any error message
    func loadGlobalMCPServers() -> (servers: [NamedMCPServer], error: String?) {
        guard FileManager.default.fileExists(atPath: claudeJsonPath.path) else {
            return ([], nil)
        }

        // SECURITY: Validate file permissions before loading MCP server config
        var errorMessage: String?
        guard let data = SecurityValidator.loadSecureData(from: claudeJsonPath, errorHandler: { error in
            errorMessage = error
        }) else {
            return ([], errorMessage)
        }

        do {
            let config = try JSONDecoder().decode(ClaudeJsonConfig.self, from: data)

            var servers: [NamedMCPServer] = []

            // Global MCP servers (root level)
            if let globalServers = config.mcpServers {
                for (name, server) in globalServers {
                    let namedServer = NamedMCPServer(
                        id: "global:\(name)",
                        name: name,
                        server: server,
                        isEnabled: true,
                        source: .global
                    )
                    servers.append(namedServer)
                }
            }

            // Per-project MCP servers
            if let projects = config.projects {
                for (projectPath, projectConfig) in projects {
                    if let mcpServers = projectConfig.mcpServers {
                        for (name, server) in mcpServers {
                            let namedServer = NamedMCPServer(
                                id: "\(projectPath):\(name)",
                                name: name,
                                server: server,
                                isEnabled: true,
                                source: .project(projectPath)
                            )
                            servers.append(namedServer)
                        }
                    }
                }
            }

            let sortedServers = servers.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

            return (sortedServers, nil)
        } catch {
            logger.error("Error loading ~/.claude.json: \(error.localizedDescription, privacy: .public)")
            ErrorHandler.shared.handle(error, context: "Loading MCP Servers")
            return ([], "Failed to load MCP servers: \(error.localizedDescription)")
        }
    }

    // MARK: - Load Project MCP Servers

    /// Loads MCP servers for a specific project from ~/.claude.json
    func loadMCPServers(for project: DiscoveredProject) -> [NamedMCPServer] {
        guard FileManager.default.fileExists(atPath: claudeJsonPath.path) else {
            return []
        }

        // SECURITY: Validate file permissions before loading MCP server config
        guard let data = SecurityValidator.loadSecureData(from: claudeJsonPath) else {
            return []
        }

        do {
            let config = try JSONDecoder().decode(ClaudeJsonConfig.self, from: data)

            // Look for this project's MCP servers in ~/.claude.json
            if let projectConfig = config.projects?[project.path],
               let mcpServers = projectConfig.mcpServers {
                return mcpServers.map { name, server in
                    NamedMCPServer(
                        id: "\(project.path):\(name)",
                        name: name,
                        server: server,
                        isEnabled: true,
                        source: .project(project.path)
                    )
                }.sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
            }

            return []
        } catch {
            logger.error("Error loading MCP config for \(project.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    // MARK: - Load Claude JSON Config

    /// Loads the raw ClaudeJsonConfig for advanced operations
    func loadClaudeJsonConfig() -> ClaudeJsonConfig? {
        guard FileManager.default.fileExists(atPath: claudeJsonPath.path) else {
            return nil
        }

        guard let data = SecurityValidator.loadSecureData(from: claudeJsonPath) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(ClaudeJsonConfig.self, from: data)
        } catch {
            logger.error("Error loading ~/.claude.json: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Save Claude JSON Config

    /// Saves the ClaudeJsonConfig back to ~/.claude.json
    func saveClaudeJsonConfig(_ config: ClaudeJsonConfig) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: claudeJsonPath)
    }
}
