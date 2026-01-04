import Foundation
import Combine

// MARK: - File Watcher

class FileWatcher: ObservableObject {
    private var sources: [String: DispatchSourceFileSystemObject] = [:]
    private var fileDescriptors: [String: Int32] = [:]

    var onFileChanged: ((String) -> Void)?

    deinit {
        stopWatchingAll()
    }

    // MARK: - Watch File

    func watch(path: String) {
        guard sources[path] == nil else { return }

        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else {
            print("Failed to open file for watching: \(path)")
            return
        }

        fileDescriptors[path] = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .extend],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            self?.onFileChanged?(path)
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        sources[path] = source
    }

    // MARK: - Stop Watching

    func stopWatching(path: String) {
        if let source = sources.removeValue(forKey: path) {
            source.cancel()
        }
        if let fd = fileDescriptors.removeValue(forKey: path) {
            close(fd)
        }
    }

    func stopWatchingAll() {
        for (path, source) in sources {
            source.cancel()
            if let fd = fileDescriptors[path] {
                close(fd)
            }
        }
        sources.removeAll()
        fileDescriptors.removeAll()
    }

    // MARK: - Watch Claude Config

    func watchClaudeConfig() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let claudeDir = home.appendingPathComponent(".claude")

        // Watch main settings file
        watch(path: claudeDir.appendingPathComponent("settings.json").path)

        // Watch stats cache
        watch(path: claudeDir.appendingPathComponent("stats-cache.json").path)
    }

    func watchProject(_ project: DiscoveredProject) {
        let claudeDir = URL(fileURLWithPath: project.path).appendingPathComponent(".claude")

        // Watch local settings
        watch(path: claudeDir.appendingPathComponent("settings.local.json").path)

        // Watch MCP config
        watch(path: claudeDir.appendingPathComponent(".mcp.json").path)

        // Watch CLAUDE.md
        watch(path: URL(fileURLWithPath: project.path).appendingPathComponent("CLAUDE.md").path)
    }
}
