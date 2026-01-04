import SwiftUI

struct SkillsView: View {
    @EnvironmentObject var configManager: ConfigManager
    @State private var selectedSkill: Skill?
    @State private var selectedFile: SkillFile?
    @State private var showingCreateSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Text("Skills")
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    showingCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)

                Button {
                    configManager.loadGlobalSkills()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .sheet(isPresented: $showingCreateSheet) {
                CreateSkillSheet()
            }

            Divider()

            // Content
            if configManager.globalSkills.isEmpty {
                EmptySkillsView()
            } else {
                HStack(spacing: 0) {
                    // Skills List with nested folders
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(configManager.globalSkills) { skill in
                                SkillTreeItem(
                                    skill: skill,
                                    selectedSkill: $selectedSkill,
                                    selectedFile: $selectedFile
                                )
                            }
                        }
                        .padding(8)
                    }
                    .frame(width: 220)
                    .background(Color(NSColor.controlBackgroundColor))

                    Divider()

                    // Detail Panel
                    if let file = selectedFile {
                        SkillFileDetailPanel(file: file)
                    } else if let skill = selectedSkill {
                        SkillDetailPanel(skill: skill)
                    } else {
                        VStack {
                            Spacer()
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("Select a Skill")
                                .font(.headline)
                                .padding(.top, 8)
                            Text("Choose a skill to view details")
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

// MARK: - Skill Tree Item (with nested folders)

struct SkillTreeItem: View {
    let skill: Skill
    @Binding var selectedSkill: Skill?
    @Binding var selectedFile: SkillFile?
    @State private var isExpanded = false

    var isSelected: Bool {
        selectedSkill?.id == skill.id && selectedFile == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main skill row
            HStack(spacing: 6) {
                // Expand/collapse button for skills with nested content
                if skill.hasNestedContent {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .frame(width: 12, height: 12)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer()
                        .frame(width: 12)
                }

                Image(systemName: "wand.and.stars")
                    .foregroundColor(.purple)
                    .frame(width: 14)

                Text(skill.name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)

                Spacer()

                if skill.hasNestedContent {
                    Text("\(skill.nestedFolders.count)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                selectedSkill = skill
                selectedFile = nil
            }

            // Nested folders
            if isExpanded && skill.hasNestedContent {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(skill.nestedFolders) { folder in
                        SkillFolderItem(
                            folder: folder,
                            selectedFile: $selectedFile,
                            onSelectFile: {
                                selectedSkill = skill
                            }
                        )
                    }
                }
                .padding(.leading, 18)
            }
        }
    }
}

// MARK: - Skill Folder Item

struct SkillFolderItem: View {
    let folder: SkillFolder
    @Binding var selectedFile: SkillFile?
    let onSelectFile: () -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Folder row
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .frame(width: 12, height: 12)

                    Image(systemName: "folder.fill")
                        .foregroundColor(.blue)
                        .font(.caption2)
                        .frame(width: 14)

                    Text(folder.displayName)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer()

                    Text("\(folder.files.count)")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Files in folder
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(folder.files) { file in
                        SkillFileRow(
                            file: file,
                            isSelected: selectedFile?.id == file.id
                        ) {
                            selectedFile = file
                            onSelectFile()
                        }
                    }
                }
                .padding(.leading, 18)
            }
        }
    }
}

// MARK: - Skill File Row

struct SkillFileRow: View {
    let file: SkillFile
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .foregroundColor(.orange)
                    .font(.system(size: 10))
                    .frame(width: 14)

                Text(file.displayName)
                    .font(.caption)
                    .fontWeight(isSelected ? .medium : .regular)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Skill Detail Panel

struct SkillDetailPanel: View {
    let skill: Skill
    @EnvironmentObject var configManager: ConfigManager
    @State private var showingContent = false
    @State private var showingDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(skill.name)
                            .font(.title3)
                            .fontWeight(.semibold)

                        HStack(spacing: 6) {
                            Text("Skill")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.2))
                                .clipShape(Capsule())

                            Text(skill.source.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        configManager.openInEditor(skill.path)
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .help("Open in Editor")

                    Button {
                        NSWorkspace.shared.selectFile(skill.path.path, inFileViewerRootedAtPath: skill.path.deletingLastPathComponent().path)
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
                    .help("Delete Skill")
                    .confirmationDialog("Delete Skill?", isPresented: $showingDeleteConfirm) {
                        Button("Delete", role: .destructive) {
                            _ = configManager.deleteSkill(skill)
                        }
                    } message: {
                        Text("This will permanently delete the skill '\(skill.name)' and all its files.")
                    }
                }

                if !skill.description.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Description")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(skill.description)
                            .font(.subheadline)
                    }
                }

                if let tools = skill.allowedTools, !tools.isEmpty {
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

                if skill.hasNestedContent {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nested Content")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ForEach(skill.nestedFolders) { folder in
                            HStack(spacing: 6) {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.blue)
                                    .font(.caption2)
                                Text(folder.displayName)
                                    .font(.caption)
                                Text("(\(folder.files.count) files)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Divider()

                // Content Preview
                DisclosureGroup("Content Preview", isExpanded: $showingContent) {
                    Text(skill.content.prefix(2000))
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

// MARK: - Skill File Detail Panel

struct SkillFileDetailPanel: View {
    let file: SkillFile

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(file.displayName)
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text(file.path.lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button {
                        NSWorkspace.shared.selectFile(file.path.path, inFileViewerRootedAtPath: file.path.deletingLastPathComponent().path)
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                }

                Divider()

                // Content
                Text(file.content)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(16)
        }
    }
}

// MARK: - Empty State

struct EmptySkillsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "wand.and.stars")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No Skills Found")
                .font(.headline)

            Text("Skills are defined in\n~/.claude/skills/*/SKILL.md")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Create Skill Sheet

struct CreateSkillSheet: View {
    @EnvironmentObject var configManager: ConfigManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var allowedTools = ""
    @State private var model = ""

    var isValid: Bool {
        !name.isEmpty && !name.contains(" ") && !name.contains("/")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Skill")
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
                TextField("Allowed Tools (optional)", text: $allowedTools)
                TextField("Model (optional)", text: $model)
            }
            .formStyle(.grouped)
            .padding()

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Create") {
                    if configManager.createSkill(
                        name: name,
                        description: description,
                        allowedTools: allowedTools.isEmpty ? nil : allowedTools,
                        model: model.isEmpty ? nil : model
                    ) {
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 400, height: 350)
    }
}

#Preview {
    SkillsView()
        .environmentObject(ConfigManager.shared)
        .frame(width: 550, height: 400)
}
