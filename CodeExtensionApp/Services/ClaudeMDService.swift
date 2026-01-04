import Foundation
import os.log

// MARK: - CLAUDE.md Service

/// Handles reading and writing CLAUDE.md files for both global
/// (~/.claude/CLAUDE.md) and project-specific configurations.
final class ClaudeMDService {
    static let shared = ClaudeMDService()

    // MARK: - Logger

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CodeExtensionApp",
        category: "ClaudeMDService"
    )

    // MARK: - Paths

    private let claudeDir: URL

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        claudeDir = home.appendingPathComponent(".claude")
    }

    // MARK: - Load CLAUDE.md

    /// Loads CLAUDE.md content from the appropriate location
    /// - Parameters:
    ///   - global: If true, loads from ~/.claude/CLAUDE.md
    ///   - project: If provided and global is false, loads from project
    /// - Returns: The content of CLAUDE.md, or nil if not found
    func loadClaudeMD(global: Bool = true, project: DiscoveredProject? = nil) -> String? {
        let path = getClaudeMDPath(global: global, project: project)

        guard let path = path else { return nil }

        return try? String(contentsOf: path, encoding: .utf8)
    }

    // MARK: - Save CLAUDE.md

    /// Saves content to CLAUDE.md at the appropriate location
    /// - Parameters:
    ///   - content: The content to save
    ///   - global: If true, saves to ~/.claude/CLAUDE.md
    ///   - project: If provided and global is false, saves to project root
    /// - Returns: nil on success, error message on failure
    func saveClaudeMD(
        _ content: String,
        global: Bool = true,
        project: DiscoveredProject? = nil
    ) -> String? {
        let path: URL

        if global {
            path = claudeDir.appendingPathComponent("CLAUDE.md")
        } else if let project = project {
            path = URL(fileURLWithPath: project.path).appendingPathComponent("CLAUDE.md")
        } else {
            return "No valid path for saving CLAUDE.md"
        }

        do {
            try content.write(to: path, atomically: true, encoding: .utf8)
            return nil
        } catch {
            logger.error("Failed to save CLAUDE.md: \(error.localizedDescription, privacy: .public)")
            return "Failed to save CLAUDE.md: \(error.localizedDescription)"
        }
    }

    // MARK: - Check Existence

    /// Checks if CLAUDE.md exists at the specified location
    /// - Parameters:
    ///   - global: If true, checks ~/.claude/CLAUDE.md
    ///   - project: If provided and global is false, checks project
    /// - Returns: true if the file exists
    func claudeMDExists(global: Bool = true, project: DiscoveredProject? = nil) -> Bool {
        guard let path = getClaudeMDPath(global: global, project: project) else {
            return false
        }

        return FileManager.default.fileExists(atPath: path.path)
    }

    // MARK: - Get Path

    /// Gets the URL to CLAUDE.md for the specified location
    /// - Parameters:
    ///   - global: If true, returns ~/.claude/CLAUDE.md path
    ///   - project: If provided and global is false, returns project path
    /// - Returns: The URL to CLAUDE.md, or nil if no valid path
    func getClaudeMDPath(global: Bool = true, project: DiscoveredProject? = nil) -> URL? {
        if global {
            return claudeDir.appendingPathComponent("CLAUDE.md")
        } else if let project = project {
            // Try project root first, then .claude directory
            let rootPath = URL(fileURLWithPath: project.path).appendingPathComponent("CLAUDE.md")
            let claudePath = URL(fileURLWithPath: project.path)
                .appendingPathComponent(".claude")
                .appendingPathComponent("CLAUDE.md")

            if FileManager.default.fileExists(atPath: rootPath.path) {
                return rootPath
            } else if FileManager.default.fileExists(atPath: claudePath.path) {
                return claudePath
            } else {
                // Default to root path for new files
                return rootPath
            }
        }

        return nil
    }

    // MARK: - Create Default CLAUDE.md

    /// Creates a default CLAUDE.md file with template content
    /// - Parameters:
    ///   - global: If true, creates in ~/.claude/
    ///   - project: If provided and global is false, creates in project root
    /// - Returns: nil on success, error message on failure
    func createDefaultClaudeMD(global: Bool = true, project: DiscoveredProject? = nil) -> String? {
        let content: String

        if global {
            content = """
            # Global Claude Instructions

            These instructions apply to all Claude Code sessions.

            ## Preferences

            - Prefer concise responses
            - Use TypeScript when possible
            - Follow existing code style

            ## Project Defaults

            Add any default instructions for new projects here.
            """
        } else if let project = project {
            content = """
            # \(project.name)

            Project-specific instructions for Claude Code.

            ## Overview

            Describe your project here.

            ## Code Style

            Add project-specific coding guidelines.

            ## Important Files

            - List important files and their purposes
            """
        } else {
            return "No valid location specified"
        }

        return saveClaudeMD(content, global: global, project: project)
    }
}
