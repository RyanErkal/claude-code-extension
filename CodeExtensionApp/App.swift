import SwiftUI

@main
struct CodeExtensionApp: App {
    @StateObject private var configManager = ConfigManager.shared
    @StateObject private var sessionMonitor = SessionMonitor.shared
    @StateObject private var projectScanner = ProjectScanner.shared
    @StateObject private var preferences = AppPreferences.shared
    @StateObject private var navigationState = NavigationState()
    @StateObject private var errorHandler = ErrorHandler.shared

    var body: some Scene {
        MenuBarExtra {
            MainContentView()
                .environmentObject(configManager)
                .environmentObject(sessionMonitor)
                .environmentObject(projectScanner)
                .environmentObject(preferences)
                .environmentObject(navigationState)
                .environmentObject(errorHandler)
                .errorAlert()
        } label: {
            Image(systemName: "terminal.fill")
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Main Content View

struct MainContentView: View {
    @EnvironmentObject var configManager: ConfigManager
    @EnvironmentObject var sessionMonitor: SessionMonitor
    @EnvironmentObject var projectScanner: ProjectScanner
    @EnvironmentObject var preferences: AppPreferences
    @EnvironmentObject var navigationState: NavigationState

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            SidebarView()
                .frame(width: 180)

            Divider()

            // Detail
            DetailView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 750, height: 500)
        .onAppear {
            configManager.loadAll()
            sessionMonitor.startMonitoring(interval: preferences.refreshInterval)
            projectScanner.scan()
        }
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @EnvironmentObject var navigationState: NavigationState
    @EnvironmentObject var configManager: ConfigManager
    @EnvironmentObject var sessionMonitor: SessionMonitor
    @EnvironmentObject var projectScanner: ProjectScanner

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Code Extension")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Menu {
                    Button("Refresh") {
                        ConfigManager.shared.loadAll()
                        SessionMonitor.shared.refresh()
                    }
                    Divider()
                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Navigation Items
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(NavigationState.SidebarTab.allCases) { tab in
                        SidebarButton(
                            tab: tab,
                            isSelected: navigationState.selectedTab == tab,
                            badgeCount: badgeCount(for: tab)
                        ) {
                            navigationState.selectedTab = tab
                            navigationState.settingsSubPage = nil
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }

            Spacer()

            // Status
            HStack(spacing: 6) {
                Circle()
                    .fill(sessionMonitor.sessions.isEmpty ? Color.gray : Color.green)
                    .frame(width: 8, height: 8)
                Text(sessionMonitor.sessions.isEmpty ? "No sessions" : "\(sessionMonitor.sessions.count) active")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func badgeCount(for tab: NavigationState.SidebarTab) -> Int {
        switch tab {
        case .sessions: return sessionMonitor.sessions.count
        case .history: return 0
        case .analytics: return 0
        case .skills: return configManager.globalSkills.count
        case .commands: return configManager.globalCommands.count
        case .hooks: return configManager.globalSettings?.hooks?.values.flatMap { $0 }.count ?? 0
        case .agents: return 0
        case .projects: return projectScanner.projects.count
        case .settings: return 0
        }
    }
}

// MARK: - Sidebar Button

struct SidebarButton: View {
    let tab: NavigationState.SidebarTab
    let isSelected: Bool
    let badgeCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.caption)
                    .frame(width: 16)

                Text(tab.rawValue)
                    .font(.caption)
                    .lineLimit(1)

                Spacer()

                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.system(size: 9))
                        .fontWeight(.medium)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.8))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? .accentColor : .primary)
    }
}

// MARK: - Detail View Router

struct DetailView: View {
    @EnvironmentObject var navigationState: NavigationState

    var body: some View {
        Group {
            switch navigationState.selectedTab {
            case .sessions:
                SessionsView()
            case .history:
                SessionHistoryView()
            case .analytics:
                AnalyticsDashboardView()
            case .skills:
                SkillsView()
            case .commands:
                CommandsView()
            case .hooks:
                HooksView()
            case .agents:
                AgentsView()
            case .projects:
                ProjectsView()
            case .settings:
                SettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Sessions View

struct SessionsView: View {
    @EnvironmentObject var sessionMonitor: SessionMonitor

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Running Sessions")
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                if sessionMonitor.isRefreshing {
                    ProgressView()
                        .scaleEffect(0.6)
                }

                Button {
                    sessionMonitor.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Content
            if sessionMonitor.sessions.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "terminal")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No Active Sessions")
                        .font(.headline)
                        .padding(.top, 8)
                    Text("Claude Code sessions will appear here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(sessionMonitor.sessions) { session in
                            SessionCard(session: session)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
}

struct SessionCard: View {
    let session: Session
    @EnvironmentObject var sessionMonitor: SessionMonitor
    @State private var showingKillConfirm = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.sessionType.icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(session.projectName)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(session.sessionType.description)
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(Capsule())
                }

                Text(session.workingDirectory)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 10) {
                    if let pid = session.pid {
                        Label("PID: \(pid)", systemImage: "number")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if let duration = session.duration {
                        Label(duration, systemImage: "clock")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if session.pid != nil, session.sessionType == .process {
                Button {
                    showingKillConfirm = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.borderless)
                .confirmationDialog("Stop Session?", isPresented: $showingKillConfirm) {
                    Button("Stop", role: .destructive) {
                        sessionMonitor.killSession(session)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview {
    MainContentView()
        .environmentObject(ConfigManager.shared)
        .environmentObject(SessionMonitor.shared)
        .environmentObject(NavigationState())
}
