import Foundation
import os.log

// MARK: - Skill Service Error

/// Error type for skill service operations
struct SkillServiceError: Error, LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

// MARK: - Skill Service

/// Handles loading, parsing, creating, and deleting skills and commands.
/// Skills are stored in ~/.claude/skills/ and commands in ~/.claude/commands/
final class SkillService {
    static let shared = SkillService()

    // MARK: - Logger

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CodeExtensionApp",
        category: "SkillService"
    )

    // MARK: - Paths

    private let skillsDir: URL
    private let commandsDir: URL

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let claudeDir = home.appendingPathComponent(".claude")
        skillsDir = claudeDir.appendingPathComponent("skills")
        commandsDir = claudeDir.appendingPathComponent("commands")
    }

    // MARK: - Load Global Skills & Commands

    /// Loads all global skills from ~/.claude/skills/
    func loadGlobalSkills() -> [Skill] {
        loadSkills(from: skillsDir, source: .global)
    }

    /// Loads all global commands from ~/.claude/commands/
    func loadGlobalCommands() -> [Skill] {
        loadSkills(from: commandsDir, source: .global)
    }

    // MARK: - Load Project Skills & Commands

    /// Loads skills for a specific project from {project}/.claude/skills/
    func loadProjectSkills(for project: DiscoveredProject) -> [Skill] {
        let skillsPath = URL(fileURLWithPath: project.path)
            .appendingPathComponent(".claude")
            .appendingPathComponent("skills")

        return loadSkills(from: skillsPath, source: .project(project.name))
    }

    /// Loads commands for a specific project from {project}/.claude/commands/
    func loadProjectCommands(for project: DiscoveredProject) -> [Skill] {
        let commandsPath = URL(fileURLWithPath: project.path)
            .appendingPathComponent(".claude")
            .appendingPathComponent("commands")

        return loadSkills(from: commandsPath, source: .project(project.name))
    }

    // MARK: - Load Agents

    /// Loads agents for a specific project from {project}/.claude/agents/
    func loadAgents(for project: DiscoveredProject) -> [Agent] {
        let agentsPath = URL(fileURLWithPath: project.path)
            .appendingPathComponent(".claude")
            .appendingPathComponent("agents")

        let fm = FileManager.default
        var agents: [Agent] = []

        guard fm.fileExists(atPath: agentsPath.path) else { return [] }

        do {
            let contents = try fm.contentsOfDirectory(at: agentsPath, includingPropertiesForKeys: nil)

            for item in contents where item.pathExtension == "md" {
                if let agent = YAMLFrontmatterParser.parseAgent(at: item, projectPath: project.path) {
                    agents.append(agent)
                }
            }
        } catch {
            logger.error("Error loading agents: \(error.localizedDescription, privacy: .public)")
        }

        return agents.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    // MARK: - Create Skill

    /// Creates a new skill with the given parameters
    /// - Returns: .success if successful, .failure with error message if failed
    func createSkill(
        name: String,
        description: String,
        allowedTools: String?,
        model: String?
    ) -> Result<Void, SkillServiceError> {
        let fm = FileManager.default

        // Create skill directory
        let skillDir = skillsDir.appendingPathComponent(name)
        do {
            try fm.createDirectory(at: skillDir, withIntermediateDirectories: true)
        } catch {
            return .failure(SkillServiceError(message: "Failed to create skill directory: \(error.localizedDescription)"))
        }

        // Create SKILL.md with YAML frontmatter
        var content = "---\n"
        content += "name: \(name)\n"
        if !description.isEmpty {
            content += "description: \(description)\n"
        }
        if let tools = allowedTools, !tools.isEmpty {
            content += "allowed-tools: \(tools)\n"
        }
        if let model = model, !model.isEmpty {
            content += "model: \(model)\n"
        }
        content += "---\n\n"
        content += "# \(name)\n\n"
        content += "Add your skill content here.\n"

        let skillFile = skillDir.appendingPathComponent("SKILL.md")
        do {
            try content.write(to: skillFile, atomically: true, encoding: .utf8)
            return .success(())
        } catch {
            return .failure(SkillServiceError(message: "Failed to create SKILL.md: \(error.localizedDescription)"))
        }
    }

    // MARK: - Delete Skill

    /// Deletes a skill and its directory
    /// - Returns: .success if successful, .failure with error if failed
    func deleteSkill(_ skill: Skill) -> Result<Void, SkillServiceError> {
        let fm = FileManager.default
        let skillDir = skill.path.deletingLastPathComponent()

        do {
            try fm.removeItem(at: skillDir)
            return .success(())
        } catch {
            return .failure(SkillServiceError(message: "Failed to delete skill: \(error.localizedDescription)"))
        }
    }

    // MARK: - Create Command

    /// Creates a new command with the given parameters
    /// - Returns: .success if successful, .failure with error if failed
    func createCommand(name: String, description: String) -> Result<Void, SkillServiceError> {
        let fm = FileManager.default

        // Ensure commands directory exists
        if !fm.fileExists(atPath: commandsDir.path) {
            do {
                try fm.createDirectory(at: commandsDir, withIntermediateDirectories: true)
            } catch {
                return .failure(SkillServiceError(message: "Failed to create commands directory: \(error.localizedDescription)"))
            }
        }

        // Create command .md file with YAML frontmatter
        var content = "---\n"
        content += "name: \(name)\n"
        if !description.isEmpty {
            content += "description: \(description)\n"
        }
        content += "---\n\n"
        content += "# \(name)\n\n"
        content += "Add your command content here.\n"

        let commandFile = commandsDir.appendingPathComponent("\(name).md")
        do {
            try content.write(to: commandFile, atomically: true, encoding: .utf8)
            return .success(())
        } catch {
            return .failure(SkillServiceError(message: "Failed to create command: \(error.localizedDescription)"))
        }
    }

    // MARK: - Delete Command

    /// Deletes a command file
    /// - Returns: .success if successful, .failure with error if failed
    func deleteCommand(_ command: Skill) -> Result<Void, SkillServiceError> {
        let fm = FileManager.default

        do {
            try fm.removeItem(at: command.path)
            return .success(())
        } catch {
            return .failure(SkillServiceError(message: "Failed to delete command: \(error.localizedDescription)"))
        }
    }

    // MARK: - Private Helpers

    private func loadSkills(from directory: URL, source: Skill.SkillSource) -> [Skill] {
        var skills: [Skill] = []
        let fm = FileManager.default

        guard fm.fileExists(atPath: directory.path) else { return [] }

        do {
            let contents = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)

            for item in contents {
                var isDirectory: ObjCBool = false
                fm.fileExists(atPath: item.path, isDirectory: &isDirectory)

                if isDirectory.boolValue {
                    // Skill directory - look for SKILL.md and nested folders
                    let skillFile = item.appendingPathComponent("SKILL.md")
                    let nestedFolders = loadNestedFolders(from: item)

                    if let skill = YAMLFrontmatterParser.parseSkill(
                        at: skillFile,
                        source: source,
                        nestedFolders: nestedFolders
                    ) {
                        skills.append(skill)
                    }
                } else if item.pathExtension == "md" {
                    // Direct .md file (command)
                    if let skill = YAMLFrontmatterParser.parseSkill(at: item, source: source) {
                        skills.append(skill)
                    }
                }
            }
        } catch {
            logger.error("Error loading skills from \(directory.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }

        return skills.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func loadNestedFolders(from skillDirectory: URL) -> [SkillFolder] {
        var folders: [SkillFolder] = []
        let fm = FileManager.default

        do {
            let contents = try fm.contentsOfDirectory(at: skillDirectory, includingPropertiesForKeys: nil)

            for item in contents {
                var isDirectory: ObjCBool = false
                fm.fileExists(atPath: item.path, isDirectory: &isDirectory)

                // Skip SKILL.md and only process directories
                if isDirectory.boolValue {
                    let folderName = item.lastPathComponent
                    let files = loadFilesInFolder(at: item)

                    if !files.isEmpty {
                        let folder = SkillFolder(
                            id: item.path,
                            name: folderName,
                            path: item,
                            files: files
                        )
                        folders.append(folder)
                    }
                }
            }
        } catch {
            logger.error("Error loading nested folders: \(error.localizedDescription, privacy: .public)")
        }

        return folders.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func loadFilesInFolder(at folderURL: URL) -> [SkillFile] {
        var files: [SkillFile] = []
        let fm = FileManager.default

        do {
            let contents = try fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)

            for item in contents where item.pathExtension == "md" {
                if let file = YAMLFrontmatterParser.parseSkillFile(at: item) {
                    files.append(file)
                }
            }
        } catch {
            logger.error("Error loading files in folder: \(error.localizedDescription, privacy: .public)")
        }

        return files.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}
