import SwiftUI

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let message: String
    var iconSize: Font = .title
    var messageFont: Font = .caption

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: icon)
                .font(iconSize)
                .foregroundColor(.secondary)
            Text(message)
                .font(messageFont)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview("Default Empty State") {
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
