import SwiftUI

struct HooksView: View {
    @EnvironmentObject var configManager: ConfigManager
    @State private var selectedHookType: String?
    @State private var showingCreateSheet = false

    var hookTypes: [String] {
        configManager.globalSettings?.hooks?.keys.sorted() ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Hooks")
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    showingCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)

                if !hookTypes.isEmpty {
                    Picker("", selection: $selectedHookType) {
                        Text("All").tag(nil as String?)
                        ForEach(hookTypes, id: \.self) { hookType in
                            Text(hookType).tag(hookType as String?)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 160)
                    .font(.caption)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .sheet(isPresented: $showingCreateSheet) {
                CreateHookSheet()
            }

            Divider()

            // Content
            if hookTypes.isEmpty {
                EmptyHooksView()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(filteredHookTypes, id: \.self) { hookType in
                            HookSection(
                                hookType: hookType,
                                configs: configManager.globalSettings?.hooks?[hookType] ?? []
                            )
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    var filteredHookTypes: [String] {
        if let selected = selectedHookType {
            return [selected]
        }
        return hookTypes
    }
}

// MARK: - Hook Section

struct HookSection: View {
    let hookType: String
    let configs: [HookConfig]

    var hookColor: Color {
        switch hookType {
        case "PreToolUse": return .blue
        case "PostToolUse": return .green
        case "PreCompact": return .orange
        case "SessionStart": return .purple
        case "SessionEnd": return .red
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(hookColor)
                    .frame(width: 8, height: 8)

                Text(hookType)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Text("(\(configs.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(Array(configs.enumerated()), id: \.offset) { index, config in
                ExpandableHookCard(
                    config: config,
                    color: hookColor,
                    hookType: hookType,
                    index: index
                )
            }
        }
    }
}

// MARK: - Expandable Hook Card

struct ExpandableHookCard: View {
    let config: HookConfig
    let color: Color
    let hookType: String
    let index: Int
    @EnvironmentObject var configManager: ConfigManager
    @State private var isExpanded = false
    @State private var scriptContents: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (clickable to expand)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                    if isExpanded {
                        loadScriptContents()
                    }
                }
            } label: {
                HStack(spacing: 0) {
                    // Color bar
                    Rectangle()
                        .fill(color)
                        .frame(width: 3)

                    HStack {
                        // Expand indicator
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .frame(width: 16)

                        VStack(alignment: .leading, spacing: 4) {
                            // Matcher
                            if let matcher = config.matcher {
                                HStack(spacing: 4) {
                                    Text("Matcher:")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(matcher)
                                        .font(.system(.caption, design: .monospaced))
                                        .fontWeight(.medium)
                                }
                            }

                            // Command count
                            if let hooks = config.hooks {
                                Text("\(hooks.count) command(s)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        // Delete button
                        Button {
                            configManager.removeHook(event: hookType, at: index)
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                }
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if let hooks = config.hooks {
                        ForEach(hooks) { hook in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "terminal")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(hook.command ?? "")
                                        .font(.system(.caption, design: .monospaced))
                                        .lineLimit(1)

                                    Spacer()

                                    // Open in editor button
                                    if let command = hook.command,
                                       let scriptURL = configManager.getScriptURL(from: command) {
                                        Button {
                                            configManager.openInEditor(scriptURL)
                                        } label: {
                                            Image(systemName: "pencil")
                                                .font(.caption2)
                                        }
                                        .buttonStyle(.plain)
                                        .help("Open in Editor")
                                    }
                                }

                                // Script content
                                if let command = hook.command,
                                   let content = scriptContents[command] {
                                    Text(content)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(8)
                                        .background(Color(NSColor.textBackgroundColor))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }
        }
    }

    private func loadScriptContents() {
        guard let hooks = config.hooks else { return }
        for hook in hooks {
            if let command = hook.command,
               let content = configManager.loadHookScriptContent(from: command) {
                scriptContents[command] = content
            }
        }
    }
}

// MARK: - Create Hook Sheet

struct CreateHookSheet: View {
    @EnvironmentObject var configManager: ConfigManager
    @Environment(\.dismiss) private var dismiss

    @State private var eventType = "PostToolUse"
    @State private var matcher = ""
    @State private var command = ""

    let eventTypes = ["PreToolUse", "PostToolUse", "PreCompact", "SessionStart", "SessionEnd"]

    var isValid: Bool {
        !matcher.isEmpty && !command.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Hook")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Form
            Form {
                Picker("Event Type", selection: $eventType) {
                    ForEach(eventTypes, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }

                TextField("Matcher (e.g., Bash, Edit|Write)", text: $matcher)
                TextField("Command (e.g., bash ~/.claude/hooks/my-hook.sh)", text: $command)
            }
            .formStyle(.grouped)
            .padding()

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Create") {
                    configManager.addHook(
                        event: eventType,
                        matcher: matcher,
                        command: command
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 450, height: 320)
    }
}

// MARK: - Empty State

struct EmptyHooksView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No Hooks Configured")
                .font(.headline)

            Text("Hooks run before or after Claude\nexecutes tools like Bash, Edit, etc.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    HooksView()
        .environmentObject(ConfigManager.shared)
        .frame(width: 550, height: 400)
}
