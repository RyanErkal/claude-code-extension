import SwiftUI

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var action: (() -> Void)? = nil
    var actionLabel: String = "See All"

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let action = action {
                Button(actionLabel) {
                    action()
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
        }
    }
}

// MARK: - Preview

#Preview("Basic Header") {
    SectionHeader(title: "Recent Sessions")
        .padding()
}

#Preview("With Subtitle") {
    SectionHeader(
        title: "Model Usage",
        subtitle: "Last 7 days"
    )
    .padding()
}

#Preview("With Action") {
    SectionHeader(
        title: "Activity",
        action: {},
        actionLabel: "View Details"
    )
    .padding()
}

#Preview("Full Featured") {
    SectionHeader(
        title: "Analytics Dashboard",
        subtitle: "Updated just now",
        action: {},
        actionLabel: "Refresh"
    )
    .padding()
}
