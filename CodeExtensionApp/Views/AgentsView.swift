import SwiftUI

struct AgentsView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Agents")
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Content - Agents are project-specific
            VStack(spacing: 16) {
                Spacer()

                Image(systemName: "person.2")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)

                Text("Agents are Project-Specific")
                    .font(.headline)

                Text("Custom agents are defined per-project in\n.claude/agents/*.md files")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Divider()
                    .frame(width: 200)
                    .padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text("To create an agent:")
                        .font(.caption)
                        .fontWeight(.semibold)

                    Text("1. Create a .md file in your project's .claude/agents/ directory")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("2. Add YAML frontmatter with name, description, model, etc.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("3. The agent will be available via @agent-name in Claude Code")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Spacer()
            }
            .padding(16)
        }
    }
}

#Preview {
    AgentsView()
        .frame(width: 550, height: 400)
}
