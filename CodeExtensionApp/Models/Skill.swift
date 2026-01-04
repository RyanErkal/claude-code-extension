import Foundation

// MARK: - Skill Model (from SKILL.md files)

struct Skill: Identifiable {
    let id: String
    let name: String
    let description: String
    let allowedTools: String?
    let argumentHint: String?
    let model: String?
    let path: URL
    let content: String
    let source: SkillSource
    let nestedFolders: [SkillFolder]  // For skills with nested content

    enum SkillSource: Equatable {
        case global
        case project(String)

        var description: String {
            switch self {
            case .global:
                return "Global"
            case .project(let name):
                return name
            }
        }
    }

    var isCommand: Bool {
        path.deletingLastPathComponent().lastPathComponent == "commands"
    }

    var typeDescription: String {
        isCommand ? "Command" : "Skill"
    }

    var hasNestedContent: Bool {
        !nestedFolders.isEmpty
    }
}

// MARK: - Skill Folder (nested folders within a skill)

struct SkillFolder: Identifiable {
    let id: String
    let name: String
    let path: URL
    let files: [SkillFile]

    var displayName: String {
        name.capitalized.replacingOccurrences(of: "-", with: " ")
    }
}

// MARK: - Skill File (individual .md files in nested folders)

struct SkillFile: Identifiable {
    let id: String
    let name: String
    let path: URL
    let content: String

    var displayName: String {
        // Remove .md extension and format nicely
        let baseName = path.deletingPathExtension().lastPathComponent
        return baseName.capitalized.replacingOccurrences(of: "-", with: " ")
    }
}

// MARK: - Skill Metadata (YAML frontmatter)

struct SkillMetadata: Codable {
    var name: String?
    var description: String?
    var allowedTools: String?
    var argumentHint: String?
    var model: String?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case allowedTools = "allowed-tools"
        case argumentHint = "argument-hint"
        case model
    }
}

// MARK: - YAML Frontmatter Parser

struct YAMLFrontmatterParser {
    static func parse(content: String) -> (metadata: [String: String], body: String) {
        let lines = content.components(separatedBy: "\n")

        guard lines.first == "---" else {
            return ([:], content)
        }

        var inFrontmatter = true
        var frontmatterLines: [String] = []
        var bodyLines: [String] = []
        var foundEnd = false

        for (index, line) in lines.enumerated() {
            if index == 0 { continue } // Skip first ---

            if inFrontmatter && line == "---" {
                inFrontmatter = false
                foundEnd = true
                continue
            }

            if inFrontmatter {
                frontmatterLines.append(line)
            } else {
                bodyLines.append(line)
            }
        }

        guard foundEnd else {
            return ([:], content)
        }

        // Parse YAML-like frontmatter (simple key: value pairs)
        var metadata: [String: String] = [:]
        for line in frontmatterLines {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                metadata[key] = value
            }
        }

        return (metadata, bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func parseSkill(at url: URL, source: Skill.SkillSource, nestedFolders: [SkillFolder] = []) -> Skill? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        let (metadata, body) = parse(content: content)

        let name = metadata["name"] ?? url.deletingPathExtension().lastPathComponent
        let description = metadata["description"] ?? ""

        return Skill(
            id: url.path,
            name: name,
            description: description,
            allowedTools: metadata["allowed-tools"],
            argumentHint: metadata["argument-hint"],
            model: metadata["model"],
            path: url,
            content: body,
            source: source,
            nestedFolders: nestedFolders
        )
    }

    static func parseSkillFile(at url: URL) -> SkillFile? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        return SkillFile(
            id: url.path,
            name: url.deletingPathExtension().lastPathComponent,
            path: url,
            content: content
        )
    }
}
