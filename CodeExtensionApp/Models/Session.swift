import Foundation

// MARK: - Session Model (Running Claude Code sessions)

struct Session: Identifiable {
    let id: String
    let pid: Int?
    let workingDirectory: String
    let startTime: Date?
    let model: String?
    let sessionType: SessionType

    enum SessionType {
        case process   // Running CLI process
        case ide       // IDE lock file

        var description: String {
            switch self {
            case .process: return "CLI"
            case .ide: return "IDE"
            }
        }

        var icon: String {
            switch self {
            case .process: return "terminal"
            case .ide: return "rectangle.on.rectangle"
            }
        }
    }

    var projectName: String {
        URL(fileURLWithPath: workingDirectory).lastPathComponent
    }

    var duration: String? {
        guard let start = startTime else { return nil }

        let elapsed = Date().timeIntervalSince(start)
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "<1m"
        }
    }
}

// MARK: - IDE Lock File
// Actual format: {"pid":84923,"workspaceFolders":["/path/to/project"],"ideName":"Cursor","transport":"ws","runningInWindows":false,"authToken":"..."}

struct IDELockFile: Codable {
    var pid: Int?
    var workspaceFolders: [String]?
    var ideName: String?
    var transport: String?
    var runningInWindows: Bool?
    var authToken: String?
}

// MARK: - Process Info

struct ProcessInfo {
    let pid: Int
    let user: String
    let command: String
    let startTime: Date?
    let workingDirectory: String?

    static func parse(from psLine: String) -> ProcessInfo? {
        // Parse output from `ps aux`
        // Format: USER PID %CPU %MEM VSZ RSS TT STAT STARTED TIME COMMAND
        let components = psLine.split(separator: " ", omittingEmptySubsequences: true)
        guard components.count >= 11 else { return nil }

        guard let pid = Int(components[1]) else { return nil }

        let user = String(components[0])
        let command = components[10...].joined(separator: " ")

        // Extract working directory from command if present
        var workingDir: String?
        if let cwdRange = command.range(of: "--cwd=") {
            let start = cwdRange.upperBound
            if let endRange = command[start...].firstIndex(of: " ") {
                workingDir = String(command[start..<endRange])
            } else {
                workingDir = String(command[start...])
            }
        }

        return ProcessInfo(
            pid: pid,
            user: user,
            command: command,
            startTime: nil,
            workingDirectory: workingDir
        )
    }
}
