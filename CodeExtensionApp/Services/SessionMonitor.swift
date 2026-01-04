import Foundation
import Combine
import os.log

// MARK: - Session Monitor

class SessionMonitor: ObservableObject {
    static let shared = SessionMonitor()

    // MARK: - Logger

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CodeExtensionApp",
        category: "SessionMonitor"
    )

    // MARK: - Published State

    @Published var sessions: [Session] = []
    @Published var isRefreshing = false
    @Published var lastError: String?

    private var timer: Timer?
    private let claudeDir: URL

    private init() {
        claudeDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
    }

    // MARK: - Start/Stop Monitoring

    func startMonitoring(interval: TimeInterval = 5.0) {
        stopMonitoring()
        refresh()

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Refresh

    func refresh() {
        isRefreshing = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let processSessions = self.findClaudeSessions()

            DispatchQueue.main.async {
                self.sessions = processSessions
                self.isRefreshing = false
            }
        }
    }

    // MARK: - Find Claude Sessions

    private func findClaudeSessions() -> [Session] {
        var sessions: [Session] = []

        // 1) Use ps to find running claude CLI processes
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-eo", "pid,comm"]  // Simple format: PID and command name

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }

            for line in output.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                // Look for lines ending with "claude" (the command name)
                guard trimmed.hasSuffix("claude") else { continue }

                // Parse PID from beginning of line
                let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                guard let pidStr = parts.first, let pid = Int(pidStr) else { continue }

                // Get working directory via lsof
                let workingDir = getWorkingDirectory(for: pid) ?? "Unknown"

                // Get start time
                let startTime = getProcessStartTime(pid: pid)

                let session = Session(
                    id: "process-\(pid)",
                    pid: pid,
                    workingDirectory: workingDir,
                    startTime: startTime,
                    model: nil,
                    sessionType: .process
                )
                sessions.append(session)
            }
        } catch {
            logger.error("Error finding claude sessions: \(error.localizedDescription, privacy: .public)")
        }

        // 2) Add IDE sessions from ~/.claude/ide/*.lock
        sessions.append(contentsOf: findIDESessions())

        return sessions
    }

    // MARK: - IDE Sessions (Cursor/IDE lock files)

    private func findIDESessions() -> [Session] {
        let ideDir = claudeDir.appendingPathComponent("ide")
        let fm = FileManager.default
        guard fm.fileExists(atPath: ideDir.path) else { return [] }

        do {
            let lockFiles = try fm.contentsOfDirectory(at: ideDir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "lock" }

            return lockFiles.compactMap { lockURL in
                guard let data = SecurityValidator.loadSecureData(from: lockURL) else { return nil }
                guard let lock = try? JSONDecoder().decode(IDELockFile.self, from: data) else { return nil }

                let workingDir = lock.workspaceFolders?.first ?? "Unknown"
                let attrs = try? fm.attributesOfItem(atPath: lockURL.path)
                let startTime = attrs?[.creationDate] as? Date

                return Session(
                    id: "ide-\(lockURL.lastPathComponent)",
                    pid: lock.pid,
                    workingDirectory: workingDir,
                    startTime: startTime,
                    model: nil,
                    sessionType: .ide
                )
            }
        } catch {
            logger.debug("Error scanning IDE lock files: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    // MARK: - Get Working Directory via lsof

    private func getWorkingDirectory(for pid: Int) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-a", "-p", String(pid), "-d", "cwd", "-Fn"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return nil }

            // lsof -Fn outputs lines starting with field type
            // n = name (path)
            for line in output.components(separatedBy: "\n") {
                if line.hasPrefix("n") && line.count > 1 {
                    return String(line.dropFirst())
                }
            }
        } catch {
            logger.debug("Error getting working directory: \(error.localizedDescription, privacy: .public)")
        }

        return nil
    }

    // MARK: - Get Process Start Time

    private func getProcessStartTime(pid: Int) -> Date? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-p", String(pid), "-o", "lstart="]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !output.isEmpty else { return nil }

            // Format: "Fri Jan  3 15:50:00 2025"
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE MMM d HH:mm:ss yyyy"
            formatter.locale = Locale(identifier: "en_US_POSIX")

            // Handle single-digit days with extra space
            let normalizedOutput = output.replacingOccurrences(of: "  ", with: " ")
            return formatter.date(from: normalizedOutput)
        } catch {
            logger.debug("Error getting process start time: \(error.localizedDescription, privacy: .public)")
        }

        return nil
    }

    // MARK: - Kill Session

    func killSession(_ session: Session) {
        guard let pid = session.pid else { return }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/kill")
        task.arguments = ["-15", String(pid)] // SIGTERM

        do {
            try task.run()
            task.waitUntilExit()

            logger.info("Successfully terminated session with PID \(pid)")

            // Refresh after killing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.refresh()
            }
        } catch {
            let errorMessage = "Failed to terminate session: \(error.localizedDescription)"
            logger.error("\(errorMessage, privacy: .public)")
            DispatchQueue.main.async { [weak self] in
                self?.lastError = errorMessage
            }
            ErrorHandler.shared.handle(error, context: "Terminating Session")
        }
    }
}
