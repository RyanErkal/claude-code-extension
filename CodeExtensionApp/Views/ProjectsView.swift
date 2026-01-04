import SwiftUI

struct ProjectsView: View {
    @EnvironmentObject var projectScanner: ProjectScanner
    @EnvironmentObject var configManager: ConfigManager
    @EnvironmentObject var preferences: AppPreferences
    @EnvironmentObject var navigationState: NavigationState

    @State private var selectedProject: DiscoveredProject?
    @State private var selectedSection: Section = .overview
    @State private var searchText = ""

    @State private var isLoadingDetails = false
    @State private var localSettings: LocalSettings?
    @State private var projectMCPServers: [NamedMCPServer] = []
    @State private var projectSkills: [Skill] = []
    @State private var projectCommands: [Skill] = []
    @State private var projectAgents: [Agent] = []
    @State private var selectedAgent: Agent?

    enum Section: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case localSettings = "Local Settings"
        case mcp = "MCP"
        case skills = "Skills"
        case commands = "Commands"
        case agents = "Agents"

        var id: String { rawValue }
    }

    private var filteredProjects: [DiscoveredProject] {
        if searchText.isEmpty { return projectScanner.projects }
        return projectScanner.projects.filter { project in
            project.name.localizedCaseInsensitiveContains(searchText) ||
                project.path.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Text("Projects")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("\(projectScanner.projects.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                TextField("Search...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                    .font(.caption)

                if projectScanner.isScanning {
                    ProgressView()
                        .scaleEffect(0.7)
                }

                Button {
                    projectScanner.scan()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)

                Button("Scan Paths") {
                    navigationState.selectedTab = .settings
                    navigationState.settingsSubPage = .scanPaths
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if filteredProjects.isEmpty {
                EmptyStateView(
                    icon: "folder",
                    title: "No Projects Found",
                    subtitle: "Add scan paths or create a project with a .claude folder.",
                    action: {
                        navigationState.selectedTab = .settings
                        navigationState.settingsSubPage = .scanPaths
                    },
                    actionTitle: "Manage Scan Paths"
                )
            } else {
                HSplitView {
                    // Project list
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(filteredProjects) { project in
                                ProjectRow(project: project, isSelected: selectedProject?.id == project.id)
                                    .onTapGesture {
                                        selectedProject = project
                                        selectedSection = .overview
                                    }
                            }
                        }
                        .padding(12)
                    }
                    .frame(minWidth: 280, idealWidth: 280, maxWidth: 340)
                    .background(Color(NSColor.controlBackgroundColor))

                    // Detail panel
                    if let project = selectedProject {
                        ProjectDetailPanel(
                            project: project,
                            selectedSection: $selectedSection,
                            isLoadingDetails: isLoadingDetails,
                            localSettings: localSettings,
                            projectMCPServers: projectMCPServers,
                            projectSkills: projectSkills,
                            projectCommands: projectCommands,
                            projectAgents: projectAgents,
                            selectedAgent: $selectedAgent
                        )
                    } else {
                        EmptyStateView(
                            icon: "doc.text.magnifyingglass",
                            message: "Select a project to view details"
                        )
                    }
                }
            }
        }
        .onAppear {
            if projectScanner.projects.isEmpty {
                projectScanner.scan()
            }
        }
        .onChange(of: selectedProject) { _, newProject in
            guard let project = newProject else { return }
            loadDetails(for: project)
        }
    }

    private func loadDetails(for project: DiscoveredProject) {
        isLoadingDetails = true
        selectedAgent = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let local = configManager.loadLocalSettings(for: project)
            let mcp = configManager.loadMCPServers(for: project)
            let skills = configManager.loadProjectSkills(for: project)
            let commands = configManager.loadProjectCommands(for: project)
            let agents = configManager.loadAgents(for: project)

            DispatchQueue.main.async {
                self.localSettings = local
                self.projectMCPServers = mcp
                self.projectSkills = skills
                self.projectCommands = commands
                self.projectAgents = agents
                self.isLoadingDetails = false
            }
        }
    }
}

// MARK: - Project Row

private struct ProjectRow: View {
    let project: DiscoveredProject
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .foregroundColor(.accentColor)
                    .frame(width: 16)

                Text(project.name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .lineLimit(1)

                Spacer()

                // Capability badges
                CapabilityBadge(icon: "gearshape", isOn: project.hasLocalSettings)
                CapabilityBadge(icon: "server.rack", isOn: project.hasMCPConfig)
                CapabilityBadge(icon: "person.2", isOn: project.hasAgents)
                CapabilityBadge(icon: "wand.and.stars", isOn: project.hasSkills)
            }

            Text(project.path)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(10)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
        )
    }
}

private struct CapabilityBadge: View {
    let icon: String
    let isOn: Bool

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 10))
            .foregroundColor(isOn ? .secondary : .secondary.opacity(0.25))
            .frame(width: 14)
            .help(isOn ? "Available" : "Not found")
    }
}

// MARK: - Project Detail Panel

private struct ProjectDetailPanel: View {
    let project: DiscoveredProject
    @Binding var selectedSection: ProjectsView.Section

    let isLoadingDetails: Bool
    let localSettings: LocalSettings?
    let projectMCPServers: [NamedMCPServer]
    let projectSkills: [Skill]
    let projectCommands: [Skill]
    let projectAgents: [Agent]
    @Binding var selectedAgent: Agent?

    var body: some View {
        VStack(spacing: 0) {
            // Title + actions
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Text(project.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                ProjectActionsMenu(project: project)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Section selector
            HStack {
                Picker("Section", selection: $selectedSection) {
                    ForEach(ProjectsView.Section.allCases) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 520)

                Spacer()

                if isLoadingDetails {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch selectedSection {
                    case .overview:
                        OverviewSection(project: project)
                    case .localSettings:
                        LocalSettingsSection(settings: localSettings)
                    case .mcp:
                        MCPSection(servers: projectMCPServers)
                    case .skills:
                        SkillsSection(skills: projectSkills)
                    case .commands:
                        CommandsSection(commands: projectCommands)
                    case .agents:
                        AgentsSection(agents: projectAgents, selectedAgent: $selectedAgent)
                    }
                }
                .padding(16)
            }
        }
    }
}

private struct ProjectActionsMenu: View {
    let project: DiscoveredProject

    var body: some View {
        Menu {
            Button("Show in Finder") { ProjectScanner.shared.openInFinder(project) }
            Button("Open in VS Code") { ProjectScanner.shared.openInVSCode(project) }
            Button("Open in Terminal") { ProjectScanner.shared.openInTerminal(project) }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .help("Project actions")
    }
}

// MARK: - Sections

private struct OverviewSection: View {
    let project: DiscoveredProject

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Overview")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                OverviewRow(label: ".claude/settings.local.json", value: project.hasLocalSettings ? "Found" : "Not found")
                OverviewRow(label: ".claude/.mcp.json", value: project.hasMCPConfig ? "Found" : "Not found")
                OverviewRow(label: ".claude/agents/", value: project.hasAgents ? "Found" : "Not found")
                OverviewRow(label: ".claude/skills/", value: project.hasSkills ? "Found" : "Not found")
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct OverviewRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

private struct LocalSettingsSection: View {
    let settings: LocalSettings?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Local Settings")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            if let permissions = settings?.permissions {
                PermissionsBlock(permissions: permissions)
            } else {
                EmptyStateView(
                    icon: "gearshape",
                    message: "No project settings.local.json permissions found"
                )
                .frame(height: 140)
            }
        }
    }
}

private struct PermissionsBlock: View {
    let permissions: Permissions

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PermissionListBlock(title: "Allow", items: permissions.allow)
            PermissionListBlock(title: "Deny", items: permissions.deny)
            PermissionListBlock(title: "Ask", items: permissions.ask)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct PermissionListBlock: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(items.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if items.isEmpty {
                Text("—")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                ForEach(items.prefix(30), id: \.self) { item in
                    Text(item)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                if items.count > 30 {
                    Text("… \(items.count - 30) more")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

private struct MCPSection: View {
    let servers: [NamedMCPServer]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MCP Servers")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            if servers.isEmpty {
                EmptyStateView(icon: "server.rack", message: "No project MCP servers found")
                    .frame(height: 140)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(servers) { server in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(server.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(server.server.serverType.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            if let url = server.server.url {
                                Text("url: \(url)")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            if let command = server.server.command {
                                Text("cmd: \(command)")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
}

private struct SkillsSection: View {
    let skills: [Skill]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Project Skills")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            if skills.isEmpty {
                EmptyStateView(icon: "wand.and.stars", message: "No project skills found")
                    .frame(height: 140)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(skills) { skill in
                        HStack {
                            Text(skill.name)
                                .font(.subheadline)
                            Spacer()
                            if let model = skill.model, !model.isEmpty {
                                Text(model)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
}

private struct CommandsSection: View {
    let commands: [Skill]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Project Commands")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            if commands.isEmpty {
                EmptyStateView(icon: "command", message: "No project commands found")
                    .frame(height: 140)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(commands) { command in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("/\(command.name)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if !command.description.isEmpty {
                                Text(command.description)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
}

private struct AgentsSection: View {
    let agents: [Agent]
    @Binding var selectedAgent: Agent?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Project Agents")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            if agents.isEmpty {
                EmptyStateView(icon: "person.2", message: "No agents found in this project")
                    .frame(height: 140)
            } else {
                HSplitView {
                    VStack(spacing: 6) {
                        ForEach(agents) { agent in
                            AgentRow(agent: agent, isSelected: selectedAgent?.id == agent.id)
                                .onTapGesture {
                                    selectedAgent = agent
                                }
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(minWidth: 240, idealWidth: 260, maxWidth: 300)

                    if let agent = selectedAgent {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(agent.displayColor)
                                    .frame(width: 10, height: 10)
                                Text(agent.name)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                Spacer()
                                Button {
                                    NSWorkspace.shared.open(agent.path)
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.borderless)
                                .help("Open in Editor")
                            }

                            if !agent.description.isEmpty {
                                Text(agent.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            HStack(spacing: 12) {
                                Label(agent.modelShortName, systemImage: "cpu")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Label(agent.projectName, systemImage: "folder")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Divider()

                            Text(agent.content)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(Color(NSColor.controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Spacer(minLength: 0)
                        }
                        .padding(.leading, 8)
                    } else {
                        EmptyStateView(icon: "doc.text.magnifyingglass", message: "Select an agent to view details")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(minHeight: 260)
            }
        }
    }
}

private struct AgentRow: View {
    let agent: Agent
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(agent.displayColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(agent.name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .lineLimit(1)
                if !agent.description.isEmpty {
                    Text(agent.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(10)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    ProjectsView()
        .environmentObject(ProjectScanner.shared)
        .environmentObject(ConfigManager.shared)
        .environmentObject(AppPreferences.shared)
        .environmentObject(NavigationState())
        .frame(width: 900, height: 600)
}
