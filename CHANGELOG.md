# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-04

### Added
- Initial release of Code Extension App
- **Session Management**: View and manage active Claude Code sessions
- **MCP Servers**: Configure Model Context Protocol servers (global and per-project)
- **Skills & Commands**: Create and manage custom skills with YAML frontmatter
- **Hooks**: Configure pre/post tool use hooks
- **Analytics Dashboard**: View usage statistics, costs, and activity heatmaps
- **Agents**: Manage custom agent configurations
- **Global Settings**: Edit permissions, environment variables, and CLAUDE.md
- **Project Scanner**: Discover projects with Claude configurations
- **Menubar Integration**: Quick access from macOS menubar
- **Auto-launch**: Option to start at login

### Security
- File permission validation for config files
- Path traversal protection
- Symlink attack prevention
- AppleScript command injection protection
