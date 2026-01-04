# Contributing to Code Extension App

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## Development Setup

### Requirements
- macOS 14.0 or later
- Xcode 15.0 or later
- Swift 5.9+

### Getting Started

1. Clone the repository
2. Open `CodeExtensionApp.xcodeproj` in Xcode
3. Build and run (Cmd+R)

## Code Style

### Swift Conventions
- Use SwiftUI for all UI components
- Follow Apple's Swift API Design Guidelines
- Use `// MARK: -` comments to organize code sections
- Keep files focused and under 300 lines when possible

### Architecture
- **Models/** - Data structures and Codable types
- **Services/** - Business logic and file operations
- **Views/** - SwiftUI views and components
- **Utilities/** - Extensions and helpers

### Patterns
- Use `@StateObject` for service singletons
- Use `@EnvironmentObject` for shared state
- Use `os.log` for logging (not `print()`)
- Handle errors via `ErrorHandler.shared`

## Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Run the build to ensure no errors
5. Commit with clear messages
6. Push to your fork
7. Open a Pull Request

### PR Guidelines
- Keep changes focused and atomic
- Update documentation if needed
- Add comments for complex logic
- Test on macOS 14.0+

## Reporting Issues

When reporting bugs, please include:
- macOS version
- App version
- Steps to reproduce
- Expected vs actual behavior
- Screenshots if applicable

## Questions?

Open a GitHub Discussion for questions or ideas.
