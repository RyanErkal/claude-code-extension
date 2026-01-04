import Foundation
import os.log
import SwiftUI

// MARK: - Error Handler

/// Centralized error handling service for the application.
/// Provides structured logging and user-facing error alerts.
final class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()

    // MARK: - Published State

    @Published var errorMessage: String?
    @Published var showError = false
    @Published var errorContext: String?

    // MARK: - Logger

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CodeExtensionApp",
        category: "Error"
    )

    private init() {}

    // MARK: - Error Handling

    /// Handle an error with context information.
    /// Logs the error and optionally shows it to the user.
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - context: A description of what was happening when the error occurred
    ///   - showToUser: Whether to display the error to the user (default: true)
    func handle(_ error: Error, context: String, showToUser: Bool = true) {
        let message = formatErrorMessage(error, context: context)

        // Log with structured logging
        logger.error("\(context): \(error.localizedDescription, privacy: .public)")

        if showToUser {
            DispatchQueue.main.async { [weak self] in
                self?.errorContext = context
                self?.errorMessage = message
                self?.showError = true
            }
        }
    }

    /// Handle an error message string with context.
    /// - Parameters:
    ///   - message: The error message
    ///   - context: A description of what was happening
    ///   - showToUser: Whether to display the error to the user (default: true)
    func handle(message: String, context: String, showToUser: Bool = true) {
        logger.error("\(context): \(message, privacy: .public)")

        if showToUser {
            DispatchQueue.main.async { [weak self] in
                self?.errorContext = context
                self?.errorMessage = message
                self?.showError = true
            }
        }
    }

    /// Log an informational message (not shown to user).
    /// - Parameters:
    ///   - message: The message to log
    ///   - context: The context of the message
    func log(_ message: String, context: String) {
        logger.info("\(context): \(message, privacy: .public)")
    }

    /// Log a warning (not shown to user by default).
    /// - Parameters:
    ///   - message: The warning message
    ///   - context: The context of the warning
    func warn(_ message: String, context: String) {
        logger.warning("\(context): \(message, privacy: .public)")
    }

    /// Dismiss the current error alert.
    func dismiss() {
        DispatchQueue.main.async { [weak self] in
            self?.showError = false
            self?.errorMessage = nil
            self?.errorContext = nil
        }
    }

    // MARK: - Private Helpers

    private func formatErrorMessage(_ error: Error, context: String) -> String {
        let nsError = error as NSError

        // Check for common error types and provide user-friendly messages
        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case NSFileNoSuchFileError, NSFileReadNoSuchFileError:
                return "The file could not be found."
            case NSFileReadNoPermissionError, NSFileWriteNoPermissionError:
                return "Permission denied. Check file permissions."
            case NSFileReadCorruptFileError:
                return "The file appears to be corrupted."
            default:
                break
            }
        }

        // For other errors, use the localized description
        return error.localizedDescription
    }
}

// MARK: - App Error Types

/// Custom errors for the application
enum AppError: LocalizedError {
    case configLoadFailed(String)
    case configSaveFailed(String)
    case processError(String)
    case fileNotFound(String)
    case parseError(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case let .configLoadFailed(detail):
            return "Failed to load configuration: \(detail)"
        case let .configSaveFailed(detail):
            return "Failed to save configuration: \(detail)"
        case let .processError(detail):
            return "Process error: \(detail)"
        case let .fileNotFound(path):
            return "File not found: \(path)"
        case let .parseError(detail):
            return "Failed to parse data: \(detail)"
        case let .networkError(detail):
            return "Network error: \(detail)"
        }
    }
}

// MARK: - View Extension for Error Alerts

extension View {
    /// Adds an error alert to the view that displays errors from the ErrorHandler.
    func errorAlert() -> some View {
        modifier(ErrorAlertModifier())
    }
}

struct ErrorAlertModifier: ViewModifier {
    @ObservedObject private var errorHandler = ErrorHandler.shared

    func body(content: Content) -> some View {
        content
            .alert(
                errorHandler.errorContext ?? "Error",
                isPresented: $errorHandler.showError,
                presenting: errorHandler.errorMessage
            ) { _ in
                Button("OK") {
                    errorHandler.dismiss()
                }
            } message: { message in
                Text(message)
            }
    }
}

// MARK: - Error Banner View

/// A dismissible error banner that can be placed in views.
struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void
    var onRetry: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            Text(message)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(2)

            Spacer()

            if let onRetry {
                Button("Retry") {
                    onRetry()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Loading View

/// A centered loading indicator with optional message.
struct LoadingView: View {
    var message: String?

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty State View

/// A view for displaying empty states with icon, title, and subtitle.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var action: (() -> Void)?
    var actionTitle: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let action, let actionTitle {
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("Error Banner") {
    VStack {
        ErrorBanner(
            message: "Failed to load settings. Please try again.",
            onDismiss: {},
            onRetry: {}
        )
        .padding()

        Spacer()
    }
}

#Preview("Loading View") {
    LoadingView(message: "Loading sessions...")
}

#Preview("Empty State") {
    EmptyStateView(
        icon: "terminal",
        title: "No Active Sessions",
        subtitle: "Claude Code sessions will appear here when running.",
        action: {},
        actionTitle: "Refresh"
    )
}
