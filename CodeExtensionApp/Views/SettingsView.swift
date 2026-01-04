import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var configManager: ConfigManager
    @EnvironmentObject var navigationState: NavigationState

    var body: some View {
        VStack(spacing: 0) {
            // Header with back button if in sub-page
            HStack {
                if navigationState.settingsSubPage != nil {
                    Button {
                        navigationState.settingsSubPage = nil
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Settings")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.borderless)
                } else {
                    Text("Settings")
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Spacer()

                if let subPage = navigationState.settingsSubPage {
                    Text(subPage.rawValue)
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Content
            if let subPage = navigationState.settingsSubPage {
                switch subPage {
                case .permissions:
                    PermissionsSubView()
                case .claudeMD:
                    ClaudeMDSubView()
                case .mcpServers:
                    MCPServersSubView()
                case .statistics:
                    StatisticsSubView()
                }
            } else {
                SettingsMenuView()
            }
        }
    }
}

// MARK: - Settings Menu

struct SettingsMenuView: View {
    @EnvironmentObject var configManager: ConfigManager
    @EnvironmentObject var navigationState: NavigationState
    @State private var showRetryBanner = false

    var permissionCount: String {
        let allow = configManager.globalSettings?.permissions.allow.count ?? 0
        let deny = configManager.globalSettings?.permissions.deny.count ?? 0
        let ask = configManager.globalSettings?.permissions.ask.count ?? 0
        return "\(allow) allow, \(deny) deny, \(ask) ask"
    }

    var mcpCount: Int {
        configManager.globalMCPServers.count
    }

    var statsInfo: String {
        if let stats = configManager.statsCache {
            return "\(stats.totalSessions ?? 0) sessions, \(stats.totalMessages ?? 0) messages"
        }
        return "No stats available"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Error Banner
            if let error = configManager.lastError, showRetryBanner {
                ErrorBanner(
                    message: error,
                    onDismiss: {
                        showRetryBanner = false
                    },
                    onRetry: {
                        configManager.loadAll()
                        showRetryBanner = false
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            // Loading State
            if configManager.isLoading {
                LoadingView(message: "Loading settings...")
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        SettingsRow(
                            icon: "checkmark.shield",
                            title: "Permissions",
                            subtitle: permissionCount,
                            color: .blue
                        ) {
                            navigationState.settingsSubPage = .permissions
                        }

                        SettingsRow(
                            icon: "doc.text",
                            title: "CLAUDE.md",
                            subtitle: "Global context file",
                            color: .purple
                        ) {
                            navigationState.settingsSubPage = .claudeMD
                        }

                        SettingsRow(
                            icon: "server.rack",
                            title: "MCP Servers",
                            subtitle: "\(mcpCount) servers configured",
                            color: .green
                        ) {
                            navigationState.settingsSubPage = .mcpServers
                        }

                        SettingsRow(
                            icon: "chart.bar",
                            title: "Statistics",
                            subtitle: statsInfo,
                            color: .orange
                        ) {
                            navigationState.settingsSubPage = .statistics
                        }
                    }
                    .padding(16)
                }
            }
        }
        .onChange(of: configManager.lastError) { _, newError in
            if newError != nil {
                showRetryBanner = true
            }
        }
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Permissions Sub-View

struct PermissionsSubView: View {
    @EnvironmentObject var configManager: ConfigManager
    @State private var selectedList: ConfigManager.PermissionList = .allow
    @State private var searchText = ""
    @State private var newPermission = ""

    var permissions: [String] {
        switch selectedList {
        case .allow:
            return configManager.globalSettings?.permissions.allow ?? []
        case .deny:
            return configManager.globalSettings?.permissions.deny ?? []
        case .ask:
            return configManager.globalSettings?.permissions.ask ?? []
        }
    }

    var filteredPermissions: [String] {
        if searchText.isEmpty {
            return permissions
        }
        return permissions.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Picker("", selection: $selectedList) {
                    Text("Allow (\(configManager.globalSettings?.permissions.allow.count ?? 0))")
                        .tag(ConfigManager.PermissionList.allow)
                    Text("Deny (\(configManager.globalSettings?.permissions.deny.count ?? 0))")
                        .tag(ConfigManager.PermissionList.deny)
                    Text("Ask (\(configManager.globalSettings?.permissions.ask.count ?? 0))")
                        .tag(ConfigManager.PermissionList.ask)
                }
                .pickerStyle(.segmented)

                Spacer()

                TextField("Search...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                    .font(.caption)
            }
            .padding(12)

            // Add Permission
            HStack {
                TextField("Add permission (e.g., Bash(npm:*))", text: $newPermission)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)

                Button {
                    if !newPermission.isEmpty {
                        configManager.addPermission(newPermission, to: selectedList)
                        newPermission = ""
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
                .disabled(newPermission.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()

            // List
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredPermissions, id: \.self) { permission in
                        PermissionRow(permission: permission, list: selectedList)
                    }
                }
                .padding(12)
            }
        }
    }
}

struct PermissionRow: View {
    let permission: String
    let list: ConfigManager.PermissionList
    @EnvironmentObject var configManager: ConfigManager

    var icon: String {
        if permission.hasPrefix("Bash") { return "terminal" }
        if permission.hasPrefix("Read") { return "doc" }
        if permission.hasPrefix("Write") || permission.hasPrefix("Edit") { return "pencil" }
        if permission.hasPrefix("mcp__") { return "server.rack" }
        if permission.hasPrefix("Skill") { return "wand.and.stars" }
        if permission.hasPrefix("Web") { return "globe" }
        return "checkmark.circle"
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.accentColor)
                .frame(width: 18)

            Text(permission)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)

            Spacer()

            Menu {
                if list != .allow {
                    Button("Move to Allow") {
                        configManager.movePermission(permission, from: list, to: .allow)
                    }
                }
                if list != .deny {
                    Button("Move to Deny") {
                        configManager.movePermission(permission, from: list, to: .deny)
                    }
                }
                if list != .ask {
                    Button("Move to Ask") {
                        configManager.movePermission(permission, from: list, to: .ask)
                    }
                }
                Divider()
                Button("Remove", role: .destructive) {
                    configManager.removePermission(permission, from: list)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 20)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - CLAUDE.md Sub-View

struct ClaudeMDSubView: View {
    @EnvironmentObject var configManager: ConfigManager
    @State private var content = ""
    @State private var hasChanges = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("~/.claude/CLAUDE.md")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if hasChanges {
                    Button("Save") {
                        configManager.saveClaudeMD(content, global: true)
                        hasChanges = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(12)

            Divider()

            // Editor
            TextEditor(text: $content)
                .font(.system(.caption, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color(NSColor.textBackgroundColor))
                .onChange(of: content) { _, _ in
                    hasChanges = true
                }
        }
        .onAppear {
            content = configManager.loadClaudeMD(global: true) ?? ""
            hasChanges = false
        }
    }
}

// MARK: - MCP Servers Sub-View

struct MCPServersSubView: View {
    @EnvironmentObject var configManager: ConfigManager
    @State private var isRefreshing = false
    @State private var showError = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar with refresh button
            HStack {
                Text("~/.claude.json")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if isRefreshing {
                    ProgressView()
                        .scaleEffect(0.6)
                } else {
                    Button {
                        refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            // Error state
            if let error = configManager.lastError, showError {
                ErrorBanner(
                    message: error,
                    onDismiss: { showError = false },
                    onRetry: { refresh() }
                )
                .padding(16)
            }

            // Content
            if configManager.isLoading {
                LoadingView(message: "Loading MCP servers...")
            } else if !configManager.globalMCPServers.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("MCP Servers (\(configManager.globalMCPServers.count))")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            ForEach(configManager.globalMCPServers) { server in
                                MCPServerRow(server: server)
                            }
                        }
                    }
                    .padding(16)
                }
            } else {
                EmptyStateView(
                    icon: "server.rack",
                    title: "No MCP Servers",
                    subtitle: "Configure servers in Claude Code or add them to ~/.claude.json",
                    action: { refresh() },
                    actionTitle: "Refresh"
                )
            }
        }
        .onChange(of: configManager.lastError) { _, newError in
            if newError != nil {
                showError = true
            }
        }
    }

    private func refresh() {
        isRefreshing = true
        showError = false
        configManager.loadGlobalMCPServers()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isRefreshing = false
        }
    }
}

struct MCPServerRow: View {
    let server: NamedMCPServer
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: server.server.serverType == .http ? "globe" : "terminal")
                        .font(.title3)
                        .foregroundColor(.green)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(server.name)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(server.sourceDescription)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    if let url = server.server.url {
                        Text("URL: \(url)")
                            .font(.system(.caption2, design: .monospaced))
                    }
                    if let command = server.server.command {
                        Text("Command: \(command)")
                            .font(.system(.caption2, design: .monospaced))
                    }
                    if let args = server.server.args, !args.isEmpty {
                        Text("Args: \(args.joined(separator: " "))")
                            .font(.system(.caption2, design: .monospaced))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Statistics Sub-View

struct StatisticsSubView: View {
    @EnvironmentObject var configManager: ConfigManager

    var body: some View {
        ScrollView {
            if let stats = configManager.statsCache {
                VStack(alignment: .leading, spacing: 16) {
                    // Summary cards
                    HStack(spacing: 12) {
                        StatCard(
                            title: "Sessions",
                            value: "\(stats.totalSessions ?? 0)",
                            icon: "rectangle.stack",
                            color: .blue
                        )
                        StatCard(
                            title: "Messages",
                            value: "\(stats.totalMessages ?? 0)",
                            icon: "message",
                            color: .green
                        )
                    }

                    // Additional stats could go here
                }
                .padding(16)
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "chart.bar")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No Stats Available")
                        .font(.headline)
                        .padding(.top, 8)
                    Text("Usage statistics will appear after using Claude Code")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    SettingsView()
        .environmentObject(ConfigManager.shared)
        .environmentObject(NavigationState())
        .frame(width: 550, height: 400)
}
