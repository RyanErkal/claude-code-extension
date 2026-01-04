import Foundation
import os.log

// MARK: - Security Validator

/// Provides security validation for file operations to prevent
/// symlink attacks, unauthorized access, and path traversal.
enum SecurityValidator {

    // MARK: - Logger

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CodeExtensionApp",
        category: "SecurityValidator"
    )

    // MARK: - File Permission Validation

    /// Validates file permissions for sensitive config files
    /// Returns an error message if validation fails, nil if valid
    static func validateFilePermissions(at path: URL) -> String? {
        let fm = FileManager.default

        // Check if file exists
        guard fm.fileExists(atPath: path.path) else {
            return nil  // Non-existent files are OK (will be created with proper perms)
        }

        do {
            let attributes = try fm.attributesOfItem(atPath: path.path)

            // SECURITY: Check for symlinks - could point to sensitive files
            if let fileType = attributes[.type] as? FileAttributeType,
               fileType == .typeSymbolicLink {
                return "Security: '\(path.lastPathComponent)' is a symlink, refusing to load"
            }

            // SECURITY: Check file ownership matches current user
            if let ownerAccountID = attributes[.ownerAccountID] as? UInt32 {
                let currentUID = getuid()
                if ownerAccountID != currentUID && ownerAccountID != 0 {
                    return "Security: '\(path.lastPathComponent)' is owned by another user (UID: \(ownerAccountID))"
                }
            }

            // SECURITY: Check file permissions - reject world-writable config files
            if let posixPermissions = attributes[.posixPermissions] as? Int {
                let worldReadable = (posixPermissions & 0o004) != 0
                let worldWritable = (posixPermissions & 0o002) != 0

                if worldWritable {
                    return "Security: '\(path.lastPathComponent)' is world-writable (permissions: \(String(posixPermissions, radix: 8))). Please run: chmod 600 '\(path.path)'"
                }

                if worldReadable {
                    // Warning but don't block - many users may have default 644 permissions
                    logger.warning("Security Warning: '\(path.lastPathComponent, privacy: .public)' is world-readable. Consider: chmod 600 '\(path.path, privacy: .public)'")
                }
            }

            return nil  // Validation passed
        } catch {
            return "Security: Cannot read attributes of '\(path.lastPathComponent)': \(error.localizedDescription)"
        }
    }

    // MARK: - Secure Data Loading

    /// Validates a file is safe to load and returns its data, or nil if validation fails
    /// - Parameters:
    ///   - path: The URL to the file
    ///   - errorHandler: Optional closure to handle errors
    /// - Returns: The file data if validation passes, nil otherwise
    static func loadSecureData(
        from path: URL,
        errorHandler: ((String) -> Void)? = nil
    ) -> Data? {
        // Validate permissions first
        if let securityError = validateFilePermissions(at: path) {
            logger.error("\(securityError, privacy: .public)")
            errorHandler?(securityError)
            ErrorHandler.shared.handle(message: securityError, context: "Loading Configuration")
            return nil
        }

        // Resolve symlinks and validate it's still the expected file
        guard let resolvedPath = try? path.resolvingSymlinksInPath(),
              resolvedPath.path == path.standardized.path else {
            let error = "Security: '\(path.lastPathComponent)' appears to be a symlink"
            errorHandler?(error)
            return nil
        }

        return try? Data(contentsOf: path)
    }

    // MARK: - Path Expansion and Validation

    /// Securely expands tilde and validates the path stays within allowed directories
    /// Returns nil if path is invalid or attempts directory traversal
    static func expandAndValidatePath(
        _ path: String,
        allowedDirectories: [URL]
    ) -> URL? {
        let fm = FileManager.default

        // SECURITY: Use NSString's expandingTildeInPath for proper tilde expansion
        let expandedPath = (path as NSString).expandingTildeInPath

        // Create URL and standardize to resolve ".." and symlinks
        let url = URL(fileURLWithPath: expandedPath).standardized

        // Resolve symlinks to get the real path
        guard let realPath = try? url.resolvingSymlinksInPath() else {
            return nil
        }

        // SECURITY: Validate the resolved path is within allowed directories
        let realPathString = realPath.path
        let isWithinAllowed = allowedDirectories.contains { allowedDir in
            let allowedPath = allowedDir.path
            return realPathString.hasPrefix(allowedPath + "/") || realPathString == allowedPath
        }

        guard isWithinAllowed else {
            logger.warning("Security: Path '\(path, privacy: .public)' resolves outside allowed directories")
            return nil
        }

        // Verify the file exists
        guard fm.fileExists(atPath: realPath.path) else {
            return nil
        }

        return realPath
    }

    // MARK: - Claude Directory

    /// Returns the ~/.claude directory URL
    static var claudeDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
    }
}
