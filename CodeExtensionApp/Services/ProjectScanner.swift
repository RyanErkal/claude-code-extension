import Foundation
import Combine
import AppKit

// MARK: - Project Scanner

class ProjectScanner: ObservableObject {
    static let shared = ProjectScanner()

    @Published var projects: [DiscoveredProject] = []
    @Published var isScanning = false

    private let preferences = AppPreferences.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Re-scan when scan paths change
        preferences.$scanPaths
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.scan()
            }
            .store(in: &cancellables)
    }

    // MARK: - Scan

    func scan() {
        isScanning = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var discoveredProjects: [DiscoveredProject] = []

            for scanPath in self.preferences.scanPaths {
                let projects = self.scanDirectory(at: scanPath, maxDepth: 3)
                discoveredProjects.append(contentsOf: projects)
            }

            // Sort by name
            discoveredProjects.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            DispatchQueue.main.async {
                self.projects = discoveredProjects
                self.isScanning = false
            }
        }
    }

    // MARK: - Scan Directory

    private func scanDirectory(at path: String, maxDepth: Int, currentDepth: Int = 0) -> [DiscoveredProject] {
        guard currentDepth < maxDepth else { return [] }

        let fm = FileManager.default
        let url = URL(fileURLWithPath: path)

        var projects: [DiscoveredProject] = []

        // Check if this directory has .claude/
        let claudeDir = url.appendingPathComponent(".claude")
        if fm.fileExists(atPath: claudeDir.path) {
            projects.append(DiscoveredProject(path: path))
        }

        // Check if this directory has CLAUDE.md at root
        let claudeMD = url.appendingPathComponent("CLAUDE.md")
        if fm.fileExists(atPath: claudeMD.path) && !projects.contains(where: { $0.path == path }) {
            projects.append(DiscoveredProject(path: path))
        }

        // Scan subdirectories
        do {
            let contents = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey])

            for item in contents {
                // Skip hidden directories (except .claude which we already checked)
                guard !item.lastPathComponent.hasPrefix(".") else { continue }

                // Skip common non-project directories
                let skipDirs = ["node_modules", "vendor", ".git", "dist", "build", ".next", "coverage"]
                guard !skipDirs.contains(item.lastPathComponent) else { continue }

                var isDirectory: ObjCBool = false
                if fm.fileExists(atPath: item.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    let subProjects = scanDirectory(at: item.path, maxDepth: maxDepth, currentDepth: currentDepth + 1)
                    projects.append(contentsOf: subProjects)
                }
            }
        } catch {
            // Silently skip directories we can't read
        }

        return projects
    }

    // MARK: - Project Actions

    func openInFinder(_ project: DiscoveredProject) {
        let url = URL(fileURLWithPath: project.path)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }

    func openInVSCode(_ project: DiscoveredProject) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", "Visual Studio Code", project.path]

        do {
            try task.run()
        } catch {
            print("Error opening VS Code: \(error)")
        }
    }

    func openInTerminal(_ project: DiscoveredProject) {
        // SECURITY: Escape single quotes to prevent command injection
        // A path like "foo'$(rm -rf ~)'bar" would execute arbitrary commands
        // Escaping with '\'' closes the quote, adds escaped quote, reopens quote
        let escapedPath = project.path.replacingOccurrences(of: "'", with: "'\\''")

        let script = """
        tell application "Terminal"
            activate
            do script "cd '\(escapedPath)'"
        end tell
        """

        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}
