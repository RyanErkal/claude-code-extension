import SwiftUI

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String

    private let title: String
    private let subtitle: String?
    private let iconFont: Font
    private let titleFont: Font
    private let subtitleFont: Font
    private let action: (() -> Void)?
    private let actionTitle: String?

    /// Compact empty state (typically used inside cards).
    init(
        icon: String,
        message: String,
        iconSize: Font = .title,
        messageFont: Font = .caption
    ) {
        self.icon = icon
        self.title = message
        self.subtitle = nil
        self.iconFont = iconSize
        self.titleFont = messageFont
        self.subtitleFont = .caption
        self.action = nil
        self.actionTitle = nil
    }

    /// Full empty state (title + subtitle, optional action).
    init(
        icon: String,
        title: String,
        subtitle: String,
        action: (() -> Void)? = nil,
        actionTitle: String? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.iconFont = .system(size: 48)
        self.titleFont = .headline
        self.subtitleFont = .caption
        self.action = action
        self.actionTitle = actionTitle
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            Image(systemName: icon)
                .font(iconFont)
                .foregroundColor(.secondary)

            VStack(spacing: 4) {
                Text(title)
                    .font(titleFont)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                if let subtitle {
                    Text(subtitle)
                        .font(subtitleFont)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            if let action, let actionTitle {
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("Message") {
    EmptyStateView(
        icon: "chart.bar",
        message: "No data available"
    )
    .frame(width: 300, height: 150)
    .padding()
}

#Preview("Custom Sizes") {
    EmptyStateView(
        icon: "folder",
        message: "No files found in this directory",
        iconSize: .largeTitle,
        messageFont: .body
    )
    .frame(width: 300, height: 200)
    .padding()
}

#Preview("In Card") {
    EmptyStateView(
        icon: "doc.text",
        message: "Start a session to see history"
    )
    .frame(height: 120)
    .cardStyle()
    .padding()
}

#Preview("Title + Subtitle + Action") {
    EmptyStateView(
        icon: "terminal",
        title: "No Active Sessions",
        subtitle: "Claude Code sessions will appear here when running.",
        action: {},
        actionTitle: "Refresh"
    )
    .frame(width: 360, height: 220)
    .padding()
}
