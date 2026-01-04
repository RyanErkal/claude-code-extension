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
        let args = parseShellArguments(command)
        guard let scriptPathRaw = extractScriptPath(from: args) else { return nil }
        let scriptPath = expandHomeEnvironmentVariables(in: scriptPathRaw)

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
        let args = parseShellArguments(command)
        guard let scriptPathRaw = extractScriptPath(from: args) else { return nil }
        let scriptPath = expandHomeEnvironmentVariables(in: scriptPathRaw)

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

    // MARK: - Command Parsing Helpers

    /// Parses a shell-like command string into arguments (supports quotes and backslash escapes).
    private func parseShellArguments(_ command: String) -> [String] {
        var args: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        var isEscaping = false

        for ch in command {
            if isEscaping {
                current.append(ch)
                isEscaping = false
                continue
            }

            if inSingle {
                if ch == "'" {
                    inSingle = false
                } else {
                    current.append(ch)
                }
                continue
            }

            if inDouble {
                if ch == "\"" {
                    inDouble = false
                } else if ch == "\\" {
                    isEscaping = true
                } else {
                    current.append(ch)
                }
                continue
            }

            switch ch {
            case "'":
                inSingle = true
            case "\"":
                inDouble = true
            case "\\":
                isEscaping = true
            default:
                if ch.isWhitespace {
                    if !current.isEmpty {
                        args.append(current)
                        current = ""
                    }
                } else {
                    current.append(ch)
                }
            }
        }

        if !current.isEmpty {
            args.append(current)
        }

        return args
    }

    /// Attempts to extract a script path from a command invocation.
    /// Supports common forms like:
    /// - `bash ~/.claude/hooks/my-hook.sh`
    /// - `~/.claude/hooks/my-hook.sh`
    private func extractScriptPath(from args: [String]) -> String? {
        guard let first = args.first else { return nil }
        if args.count == 1 { return first }

        let interpreter = URL(fileURLWithPath: first).lastPathComponent.lowercased()
        let knownInterpreters: Set<String> = [
            "bash", "sh", "zsh", "fish",
            "python", "python3",
            "node", "ruby", "perl"
        ]

        if knownInterpreters.contains(interpreter) {
            // If the interpreter is executing inline code, we can't map to a file path reliably.
            if args.contains("-c") || args.contains("-lc") {
                return nil
            }

            // Find the first non-flag argument after the interpreter.
            for arg in args.dropFirst() {
                if arg.hasPrefix("-") { continue }
                return arg
            }
            return nil
        }

        // Otherwise assume the first argument itself is a script/executable path.
        return first
    }

    /// Expands a small subset of common environment variables in paths.
    /// (Security validation is still applied after expansion.)
    private func expandHomeEnvironmentVariables(in path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path
            .replacingOccurrences(of: "${HOME}", with: home)
            .replacingOccurrences(of: "$HOME", with: home)
    }
}
