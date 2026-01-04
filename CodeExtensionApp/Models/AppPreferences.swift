import Foundation
import SwiftUI

// MARK: - App Preferences

class AppPreferences: ObservableObject {
    static let shared = AppPreferences()

    @AppStorage("scanPaths") private var scanPathsData: Data = Data()
    @AppStorage("refreshInterval") var refreshInterval: Double = 5.0
    @AppStorage("showNotifications") var showNotifications: Bool = true

    @Published var scanPaths: [String] = [] {
        didSet {
            saveScanPaths()
        }
    }

    private init() {
        loadScanPaths()
        if scanPaths.isEmpty {
            // Default scan path
            let devPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Dev").path
            scanPaths = [devPath]
        }
    }

    private func loadScanPaths() {
        if let paths = try? JSONDecoder().decode([String].self, from: scanPathsData) {
            scanPaths = paths
        }
    }

    private func saveScanPaths() {
        if let data = try? JSONEncoder().encode(scanPaths) {
            scanPathsData = data
        }
    }

    func addScanPath(_ path: String) {
        guard !scanPaths.contains(path) else { return }
        scanPaths.append(path)
    }

    func removeScanPath(_ path: String) {
        scanPaths.removeAll { $0 == path }
    }
}

// MARK: - Navigation State

class NavigationState: ObservableObject {
    @Published var selectedTab: SidebarTab = .sessions
    @Published var settingsSubPage: SettingsPage?

    enum SidebarTab: String, CaseIterable, Identifiable {
        case sessions = "Sessions"
        case history = "History"
        case analytics = "Analytics"
        case skills = "Skills"
        case commands = "Commands"
        case hooks = "Hooks"
        case agents = "Agents"
        case settings = "Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .sessions: return "terminal"
            case .history: return "clock.arrow.circlepath"
            case .analytics: return "chart.bar.xaxis"
            case .skills: return "wand.and.stars"
            case .commands: return "command"
            case .hooks: return "arrow.triangle.branch"
            case .agents: return "person.2"
            case .settings: return "gearshape"
            }
        }
    }

    enum SettingsPage: String, Identifiable {
        case permissions = "Permissions"
        case claudeMD = "CLAUDE.md"
        case mcpServers = "MCP Servers"
        case statistics = "Statistics"

        var id: String { rawValue }
    }
}

// MARK: - Discovered Project

struct DiscoveredProject: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    let hasLocalSettings: Bool
    let hasMCPConfig: Bool
    let hasAgents: Bool
    let hasSkills: Bool

    init(path: String) {
        self.id = path
        self.path = path
        self.name = URL(fileURLWithPath: path).lastPathComponent

        let claudeDir = URL(fileURLWithPath: path).appendingPathComponent(".claude")
        let fm = FileManager.default

        self.hasLocalSettings = fm.fileExists(atPath: claudeDir.appendingPathComponent("settings.local.json").path)
        self.hasMCPConfig = fm.fileExists(atPath: claudeDir.appendingPathComponent(".mcp.json").path)
        self.hasAgents = fm.fileExists(atPath: claudeDir.appendingPathComponent("agents").path)
        self.hasSkills = fm.fileExists(atPath: claudeDir.appendingPathComponent("skills").path)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DiscoveredProject, rhs: DiscoveredProject) -> Bool {
        lhs.id == rhs.id
    }
}
