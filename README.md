<div align="center">

# Claude Code Extension

**A native macOS menubar app for managing Claude Code**

[![macOS](https://img.shields.io/badge/macOS-14.0+-000000?style=flat&logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-FA7343?style=flat&logo=swift&logoColor=white)](https://swift.org/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

<img src="assets/screenshot.png" alt="Claude Code Extension Screenshot" width="600">

*Manage sessions, MCP servers, skills, hooks, and settings—all from your menubar.*

[Features](#features) • [Installation](#installation) • [Usage](#usage) • [Contributing](#contributing)

</div>

---

## Features

### 📊 Session Management
Monitor and manage all running Claude Code sessions in real-time. View active CLI processes and IDE integrations, see working directories, and terminate sessions when needed.

### 🔌 MCP Server Configuration
Browse and manage Model Context Protocol servers at both global and project levels. View server configurations, environment variables, and connection status.

### ⚡ Skills & Commands
Create, edit, and organize custom skills and slash commands. Full YAML frontmatter support with live preview of skill content and metadata.

### 🪝 Hooks Management
Configure pre and post tool-use hooks with visual editing. Supports all hook event types with script path validation and content preview.

### 📈 Analytics Dashboard
Track your Claude Code usage with beautiful visualizations:
- Daily usage charts with cost tracking
- Model breakdown by tokens and cost
- Activity heatmaps by hour
- Cache efficiency metrics

### ⚙️ Global & Local Settings
- **Permissions**: Manage allow/deny/ask lists for tools and commands
- **Environment Variables**: Configure global environment settings
- **CLAUDE.md**: Edit your global instructions file
- **Project Settings**: Per-project configuration overrides

### 🔍 Project Scanner
Automatically discover projects with Claude Code configurations across your development directories. Quick access to open projects in Finder, Terminal, or VS Code.

---

## Installation

### Requirements

- **macOS 14.0** (Sonoma) or later
- **Xcode 15.0** or later

### Option 1: Build from Source

```bash
# Clone the repository
git clone https://github.com/RyanErkal/claude-code-extension.git
cd claude-code-extension

# Generate the Xcode project (recommended)
brew install xcodegen
xcodegen generate

# Open in Xcode
open CodeExtensionApp.xcodeproj

# Build and Run (⌘R)
```

### Option 2: Download Release

Download the latest `.dmg` from the [Releases](https://github.com/RyanErkal/claude-code-extension/releases) page.

---

## Usage

### Quick Start

1. **Launch the app** — appears in your menubar as a terminal icon
2. **Sessions tab** — view running Claude Code instances
3. **Settings tab** — configure permissions and hooks
4. **Skills tab** — manage your custom skills

### Configuration

The app reads and manages these Claude Code configuration files:

| File | Location | Purpose |
|------|----------|---------|
| `settings.json` | `~/.claude/` | Global permissions, hooks, environment |
| `CLAUDE.md` | `~/.claude/` | Global instructions for Claude |
| `.claude.json` | `~/` | Global + per-project MCP server configurations |
| `settings.local.json` | `project/.claude/` | Project-specific permissions |
| `.mcp.json` | `project/.claude/` | Project MCP servers (legacy/optional) |
| `SKILL.md` | `~/.claude/skills/*/` | Custom skill definitions |

### Scan Paths

By default, the app scans `~/Dev/` for projects. To customize:

1. Go to **Settings → Scan Paths**
2. Add or remove folders to scan
3. Open **Projects** to browse discovered configs

### Auto-Launch

To start automatically at login:

1. Open **System Settings → General → Login Items**
2. Click **+** under "Open at Login"
3. Add the app

---

## Project Structure

```
claude-code-extension/
├── CodeExtensionApp/
│   ├── App.swift                    # MenuBarExtra entry point
│   ├── Models/                      # Data models
│   │   ├── ClaudeSettings.swift     # Settings schema
│   │   ├── MCPServer.swift          # MCP configuration
│   │   ├── Skill.swift              # Skill definitions
│   │   ├── Session.swift            # Active sessions
│   │   └── Analytics.swift          # Usage analytics
│   ├── Services/                    # Business logic
│   │   ├── ConfigManager.swift      # Configuration facade
│   │   ├── MCPServerService.swift   # MCP operations
│   │   ├── SkillService.swift       # Skill CRUD
│   │   ├── HookService.swift        # Hook management
│   │   ├── SessionMonitor.swift     # Process monitoring
│   │   └── AnalyticsService.swift   # Usage tracking
│   ├── Views/                       # SwiftUI views
│   │   ├── Analytics/               # Dashboard components
│   │   ├── Components/              # Shared UI components
│   │   └── *.swift                  # Feature views
│   └── Utilities/                   # Helpers
│       ├── ErrorHandler.swift       # Centralized errors
│       └── SecurityValidator.swift  # File validation
├── LICENSE
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
└── CHANGELOG.md
```

---

## Building for Distribution

### Create a Release Build

```bash
# Archive in Xcode
# Product → Archive

# Or via command line
xcodebuild archive \
  -scheme CodeExtensionApp \
  -archivePath build/CodeExtensionApp.xcarchive
```

### Create DMG

```bash
brew install create-dmg

create-dmg \
  --volname "Claude Code Extension" \
  --volicon "assets/icon.icns" \
  --window-size 500 320 \
  --icon-size 100 \
  --icon "Claude Code Extension.app" 130 150 \
  --app-drop-link 370 150 \
  --hide-extension "Claude Code Extension.app" \
  "Claude-Code-Extension.dmg" \
  "build/Claude Code Extension.app"
```

---

## Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.md) and [Code of Conduct](CODE_OF_CONDUCT.md) before submitting a PR.

### Development Setup

1. Fork the repository
2. Clone your fork
3. Open in Xcode 15+
4. Create a feature branch
5. Make your changes
6. Submit a PR

### Code Style

- SwiftUI for all UI components
- `// MARK: -` for code organization
- `os.log` for logging (not `print()`)
- Follow Apple's Swift API Design Guidelines

---

## Security

This app handles sensitive configuration files. Security measures include:

- **File permission validation** before loading configs
- **Path traversal protection** for all file operations
- **Symlink attack prevention**
- **No network requests** — fully offline operation

Report security issues via [GitHub Security Advisories](https://github.com/RyanErkal/claude-code-extension/security/advisories/new).

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

<div align="center">

**[⬆ Back to Top](#claude-code-extension)**

Made with ❤️ for the Claude Code community

</div>
