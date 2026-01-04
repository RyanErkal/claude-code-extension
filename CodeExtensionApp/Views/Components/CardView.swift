import SwiftUI

// MARK: - Card View Modifier

struct CardStyle: ViewModifier {
    var padding: CGFloat = 12
    var cornerRadius: CGFloat = 8

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    func cardStyle(padding: CGFloat = 12, cornerRadius: CGFloat = 8) -> some View {
        modifier(CardStyle(padding: padding, cornerRadius: cornerRadius))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        Text("Default Card")
            .cardStyle()

        Text("Custom Padding Card")
            .cardStyle(padding: 20)

        Text("Custom Corner Radius Card")
            .cardStyle(cornerRadius: 16)

        VStack(alignment: .leading, spacing: 8) {
            Text("Complex Card")
                .font(.headline)
            Text("With multiple elements inside")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
    .padding()
    .frame(width: 300)
}
