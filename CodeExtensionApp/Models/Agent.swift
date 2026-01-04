import Foundation
import SwiftUI

// MARK: - Agent Model (from agents/*.md files)

struct Agent: Identifiable {
    let id: String
    let name: String
    let description: String
    let model: String?
    let color: String?
    let voiceId: String?
    let permissions: AgentPermissions?
    let path: URL
    let content: String
    let projectPath: String

    var projectName: String {
        URL(fileURLWithPath: projectPath).lastPathComponent
    }

    var displayColor: Color {
        guard let colorName = color?.lowercased() else { return .blue }

        switch colorName {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "cyan": return .cyan
        case "brown": return .brown
        default: return .blue
        }
    }

    var modelShortName: String {
        guard let model = model else { return "default" }

        if model.contains("opus") { return "Opus" }
        if model.contains("sonnet") { return "Sonnet" }
        if model.contains("haiku") { return "Haiku" }
        return model
    }
}

// MARK: - Agent Permissions

struct AgentPermissions: Codable {
    var allow: [String]?
    var deny: [String]?
    var ask: [String]?
}

// MARK: - Agent Metadata (YAML frontmatter)

struct AgentMetadata: Codable {
    var name: String?
    var description: String?
    var model: String?
    var color: String?
    var voiceId: String?
    var permissions: AgentPermissions?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case model
        case color
        case voiceId
        case permissions
    }
}

// MARK: - Agent Parser

extension YAMLFrontmatterParser {
    static func parseAgent(at url: URL, projectPath: String) -> Agent? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        let (metadata, body) = parse(content: content)

        let name = metadata["name"] ?? url.deletingPathExtension().lastPathComponent

        // Parse permissions if present
        var permissions: AgentPermissions?
        if let permissionsString = metadata["permissions"] {
            // Simple parsing - in real app would need proper YAML parser
            permissions = AgentPermissions(allow: nil, deny: nil, ask: nil)
        }

        return Agent(
            id: url.path,
            name: name,
            description: metadata["description"] ?? "",
            model: metadata["model"],
            color: metadata["color"],
            voiceId: metadata["voiceId"],
            permissions: permissions,
            path: url,
            content: body,
            projectPath: projectPath
        )
    }
}
