import SwiftUI

struct CommandsView: View {
    @EnvironmentObject var configManager: ConfigManager
    @State private var searchText = ""
    @State private var selectedCommand: Skill?
    @State private var showingCreateSheet = false

    var filteredCommands: [Skill] {
        let commands = configManager.globalCommands
        if searchText.isEmpty {
            return commands
        }
        return commands.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Text("Commands")
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    showingCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)

                TextField("Search...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .sheet(isPresented: $showingCreateSheet) {
                CreateCommandSheet()
            }

            Divider()

            // Content
            if configManager.globalCommands.isEmpty {
                EmptyCommandsView()
            } else {
                HStack(spacing: 0) {
                    // List
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(filteredCommands) { command in
                                CommandRow(
                                    command: command,
                                    isSelected: selectedCommand?.id == command.id
                                ) {
                                    selectedCommand = command
                                }
                            }
                        }
                        .padding(8)
                    }
                    .frame(width: 220)
                    .background(Color(NSColor.controlBackgroundColor))

                    Divider()

                    // Detail
                    if let command = selectedCommand {
                        CommandDetailPanel(command: command)
                    } else {
                        VStack {
                            Spacer()
                            Image(systemName: "command")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("Select a Command")
                                .font(.headline)
                                .padding(.top, 8)
                            Text("Choose a command to view details")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

// MARK: - Command Row

struct CommandRow: View {
    let command: Skill
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "command")
                    .foregroundColor(.orange)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text("/\(command.name)")
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .lineLimit(1)

                    if !command.description.isEmpty {
                        Text(command.description)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Command Detail Panel

struct CommandDetailPanel: View {
    let command: Skill
    @EnvironmentObject var configManager: ConfigManager
    @State private var showingContent = false
    @State private var showingDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("/\(command.name)")
                            .font(.title3)
                            .fontWeight(.semibold)

                        HStack(spacing: 6) {
                            Text("Command")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .clipShape(Capsule())

                            Text(command.source.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        configManager.openInEditor(command.path)
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .help("Open in Editor")

                    Button {
                        NSWorkspace.shared.selectFile(command.path.path, inFileViewerRootedAtPath: command.path.deletingLastPathComponent().path)
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                    .help("Show in Finder")

                    Button {
                        showingDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("Delete Command")
                    .confirmationDialog("Delete Command?", isPresented: $showingDeleteConfirm) {
                        Button("Delete", role: .destructive) {
                            _ = configManager.deleteCommand(command)
                        }
                    } message: {
                        Text("This will permanently delete the command '\(command.name)'.")
                    }
                }

                if !command.description.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Description")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(command.description)
                            .font(.subheadline)
                    }
                }

                if let tools = command.allowedTools, !tools.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Allowed Tools")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(tools)
                            .font(.system(.caption, design: .monospaced))
                            .padding(6)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                if let hint = command.argumentHint {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Argument Hint")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(hint)
                            .font(.system(.caption, design: .monospaced))
                    }
                }

                if let model = command.model {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Model")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(model)
                            .font(.caption)
                    }
                }

                Divider()

                // Content Preview
                DisclosureGroup("Content Preview", isExpanded: $showingContent) {
                    Text(command.content.prefix(2000))
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .font(.caption)
            }
            .padding(16)
        }
    }
}

// MARK: - Empty State

struct EmptyCommandsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "command")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No Commands Found")
                .font(.headline)

            Text("Commands are defined in\n~/.claude/commands/*.md")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Create Command Sheet

struct CreateCommandSheet: View {
    @EnvironmentObject var configManager: ConfigManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""

    var isValid: Bool {
        !name.isEmpty && !name.contains(" ") && !name.contains("/")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Command")
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
                TextField("Name (no spaces)", text: $name)
                TextField("Description", text: $description)
            }
            .formStyle(.grouped)
            .padding()

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Create") {
                    if configManager.createCommand(
                        name: name,
                        description: description
                    ) {
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 400, height: 280)
    }
}

#Preview {
    CommandsView()
        .environmentObject(ConfigManager.shared)
        .frame(width: 550, height: 400)
}
