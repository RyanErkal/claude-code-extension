import Foundation

// MARK: - MCP Configuration (.mcp.json) - Legacy, rarely used

struct MCPConfig: Codable {
    var mcpServers: [String: MCPServer]?

    init(mcpServers: [String: MCPServer]? = nil) {
        self.mcpServers = mcpServers
    }
}

// MARK: - Claude.json Configuration (main config file)

struct ClaudeJsonConfig: Codable {
    var mcpServers: [String: MCPServer]?  // Global MCP servers
    var projects: [String: ClaudeProjectConfig]?  // Per-project configs

    init(mcpServers: [String: MCPServer]? = nil, projects: [String: ClaudeProjectConfig]? = nil) {
        self.mcpServers = mcpServers
        self.projects = projects
    }
}

struct ClaudeProjectConfig: Codable {
    var mcpServers: [String: MCPServer]?
    var enabledMcpjsonServers: [String]?
    var disabledMcpjsonServers: [String]?
    var allowedTools: [String]?

    init(mcpServers: [String: MCPServer]? = nil) {
        self.mcpServers = mcpServers
    }
}

struct MCPServer: Codable, Identifiable {
    var id: String = UUID().uuidString
    var type: String?           // "http" or "command"
    var command: String?        // For command-based servers
    var args: [String]?         // Arguments for command
    var url: String?            // For http-based servers
    var env: [String: String]?  // Environment variables
    var headers: [String: String]? // HTTP headers

    enum CodingKeys: String, CodingKey {
        case type
        case command
        case args
        case url
        case env
        case headers
    }

    var displayName: String {
        if let command = command {
            return command.components(separatedBy: "/").last ?? command
        }
        if let url = url {
            return URL(string: url)?.host ?? url
        }
        return "Unknown"
    }

    var serverType: ServerType {
        if type == "http" || type == "sse" || url != nil {
            return .http
        }
        // stdio, command, or anything with a command field
        return .stdio
    }

    enum ServerType: String {
        case http = "HTTP"
        case stdio = "stdio"
    }
}

// MARK: - MCP Server with Name (for display)

struct NamedMCPServer: Identifiable {
    let id: String
    let name: String
    var server: MCPServer
    var isEnabled: Bool
    var source: MCPSource

    enum MCPSource {
        case global
        case project(String) // project path
    }

    var sourceDescription: String {
        switch source {
        case .global:
            return "Global"
        case .project(let path):
            return URL(fileURLWithPath: path).lastPathComponent
        }
    }
}
