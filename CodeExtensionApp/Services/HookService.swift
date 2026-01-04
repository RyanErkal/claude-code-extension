import Foundation
import AppKit
import os.log

// MARK: - Hook Service

/// Handles hook configuration management including adding, removing,
/// and loading hook script content.
final class HookService {
    static let shared = HookService()

    // MARK: - Logger

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CodeExtensionApp",
        category: "HookService"
    )

    // MARK: - Paths

    private let claudeDir: URL

    private init() {
        claudeDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
    }

    // MARK: - Add Hook

    /// Adds a new hook to the settings
    /// - Parameters:
    ///   - event: The event type (e.g., "PreToolUse", "PostToolUse")
    ///   - matcher: The matcher pattern for the hook
    ///   - command: The command to execute
    ///   - settings: The current settings (will be modified)
    /// - Returns: Updated settings with the new hook
    func addHook(
        event: String,
        matcher: String,
        command: String,
        to settings: ClaudeSettings
    ) -> ClaudeSettings {
        var updatedSettings = settings

        let hookAction = HookAction(type: "command", command: command)
        let hookConfig = HookConfig(matcher: matcher, hooks: [hookAction])

        if updatedSettings.hooks == nil {
            updatedSettings.hooks = [:]
        }

        if updatedSettings.hooks?[event] == nil {
            updatedSettings.hooks?[event] = []
        }

        updatedSettings.hooks?[event]?.append(hookConfig)

        return updatedSettings
    }

    // MARK: - Remove Hook

    /// Removes a hook at the specified index from the event
    /// - Parameters:
    ///   - event: The event type
    ///   - index: The index of the hook to remove
    ///   - settings: The current settings (will be modified)
    /// - Returns: Updated settings with the hook removed
    func removeHook(
        event: String,
        at index: Int,
        from settings: ClaudeSettings
    ) -> ClaudeSettings {
        var updatedSettings = settings

        guard var hooks = updatedSettings.hooks?[event],
              index < hooks.count else {
            return updatedSettings
        }

        hooks.remove(at: index)
        updatedSettings.hooks?[event] = hooks

        // Remove empty event arrays
        if hooks.isEmpty {
            updatedSettings.hooks?.removeValue(forKey: event)
        }

        return updatedSettings
    }

    // MARK: - Load Hook Script Content

    /// Loads the content of a hook script from its command
    /// - Parameter command: The full command (e.g., "bash ~/.claude/hooks/auto-format.sh")
    /// - Returns: The script content, or nil if not found or security validation fails
    func loadHookScriptContent(from command: String) -> String? {
        // Parse script path from command like "bash ~/.claude/hooks/auto-format.sh"
        let components = command.components(separatedBy: " ")
        guard components.count >= 2 else { return nil }

        let scriptPath = components.dropFirst().joined(separator: " ")

        // SECURITY: Only allow loading scripts from ~/.claude directory
        let allowedDirectories = [claudeDir]

        guard let validatedURL = SecurityValidator.expandAndValidatePath(
            scriptPath,
            allowedDirectories: allowedDirectories
        ) else {
            logger.warning("Security: Refusing to load script from untrusted path: \(scriptPath, privacy: .public)")
            return nil
        }

        return try? String(contentsOf: validatedURL, encoding: .utf8)
    }

    // MARK: - Get Script URL

    /// Parses a command string and returns the URL to the script file
    /// - Parameter command: The full command
    /// - Returns: URL to the script file, or nil if not parseable or security validation fails
    func getScriptURL(from command: String) -> URL? {
        let components = command.components(separatedBy: " ")
        guard components.count >= 2 else { return nil }

        let scriptPath = components.dropFirst().joined(separator: " ")

        // SECURITY: Only allow scripts from ~/.claude directory
        let allowedDirectories = [claudeDir]

        return SecurityValidator.expandAndValidatePath(scriptPath, allowedDirectories: allowedDirectories)
    }

    // MARK: - Open Script in Editor

    /// Opens a hook script in the default editor
    /// - Parameter command: The full command containing the script path
    func openScriptInEditor(from command: String) {
        guard let url = getScriptURL(from: command) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Get All Hook Events

    /// Returns all available hook event types
    static var availableEvents: [String] {
        [
            "PreToolUse",
            "PostToolUse",
            "Notification",
            "Stop"
        ]
    }

    // MARK: - Validate Hook

    /// Validates a hook configuration
    /// - Parameters:
    ///   - event: The event type
    ///   - matcher: The matcher pattern
    ///   - command: The command to execute
    /// - Returns: nil if valid, error message if invalid
    func validateHook(event: String, matcher: String, command: String) -> String? {
        if event.isEmpty {
            return "Event type is required"
        }

        if command.isEmpty {
            return "Command is required"
        }

        // Check if the script file exists (if it's a script-based command)
        // Uses security validation to ensure path is within allowed directories
        if let url = getScriptURL(from: command) {
            if !FileManager.default.fileExists(atPath: url.path) {
                return "Script file does not exist: \(url.path)"
            }
        }

        return nil
    }
}
