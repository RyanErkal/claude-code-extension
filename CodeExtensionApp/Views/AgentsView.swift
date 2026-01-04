import SwiftUI

struct AgentsView: View {
    @EnvironmentObject var projectScanner: ProjectScanner
    @EnvironmentObject var configManager: ConfigManager
    @EnvironmentObject var navigationState: NavigationState

    @State private var isLoading = false
    @State private var searchText = ""
    @State private var agents: [Agent] = []
    @State private var selectedAgent: Agent?

    private var filteredAgents: [Agent] {
        if searchText.isEmpty { return agents }
        return agents.filter { agent in
            agent.name.localizedCaseInsensitiveContains(searchText) ||
                agent.description.localizedCaseInsensitiveContains(searchText) ||
                agent.projectName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Text("Agents")
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                TextField("Search...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                    .font(.caption)

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }

                Button {
                    refresh()
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

            if filteredAgents.isEmpty {
                EmptyStateView(
                    icon: "person.2",
                    title: "No Agents Found",
                    subtitle: "Create agents in your project's .claude/agents/*.md folder."
                )
            } else {
                HSplitView {
                    // List
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(filteredAgents) { agent in
                                AgentListRow(agent: agent, isSelected: selectedAgent?.id == agent.id)
                                    .onTapGesture { selectedAgent = agent }
                            }
                        }
                        .padding(12)
                    }
                    .frame(minWidth: 300, idealWidth: 320, maxWidth: 360)
                    .background(Color(NSColor.controlBackgroundColor))

                    // Detail
                    if let agent = selectedAgent {
                        AgentDetailPanel(agent: agent)
                    } else {
                        EmptyStateView(icon: "doc.text.magnifyingglass", message: "Select an agent to view details")
                    }
                }
            }
        }
        .onAppear {
            refresh()
        }
        .onChange(of: projectScanner.projects) { _, _ in
            refresh()
        }
    }
}

#Preview {
    AgentsView()
        .environmentObject(ProjectScanner.shared)
        .environmentObject(ConfigManager.shared)
        .environmentObject(NavigationState())
        .frame(width: 850, height: 500)
}

// MARK: - List Row

private struct AgentListRow: View {
    let agent: Agent
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(agent.displayColor)
                    .frame(width: 8, height: 8)

                Text(agent.name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .lineLimit(1)

                Spacer()

                Text(agent.projectName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            if !agent.description.isEmpty {
                Text(agent.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
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

// MARK: - Detail Panel

private struct AgentDetailPanel: View {
    let agent: Agent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(agent.displayColor)
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(agent.name)
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text(agent.projectPath)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }

                    Spacer()

                    Button {
                        NSWorkspace.shared.open(agent.path)
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .help("Open in Editor")

                    Button {
                        NSWorkspace.shared.selectFile(agent.path.path, inFileViewerRootedAtPath: agent.path.deletingLastPathComponent().path)
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                    .help("Show in Finder")
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
                    if let voice = agent.voiceId, !voice.isEmpty {
                        Label(voice, systemImage: "waveform")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                Text(agent.content)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(16)
        }
    }
}

// MARK: - Loading

extension AgentsView {
    private func refresh() {
        isLoading = true
        selectedAgent = nil

        // Snapshot on main thread to avoid cross-thread access to @Published state.
        let projectsSnapshot = projectScanner.projects

        DispatchQueue.global(qos: .userInitiated).async {
            let projectsWithAgents = projectsSnapshot.filter { $0.hasAgents }
            let loadedAgents = projectsWithAgents.flatMap { project in
                configManager.loadAgents(for: project)
            }.sorted { a, b in
                let projectCompare = a.projectName.localizedCaseInsensitiveCompare(b.projectName)
                if projectCompare != .orderedSame { return projectCompare == .orderedAscending }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }

            DispatchQueue.main.async {
                self.agents = loadedAgents
                self.isLoading = false
            }
        }
    }
}
