import SwiftUI

// MARK: - Sort Option

enum SessionSortOption: String, CaseIterable {
    case newest = "Newest"
    case oldest = "Oldest"
    case costHigh = "Cost (High)"
    case durationLong = "Duration (Long)"
}

// MARK: - Session History View

struct SessionHistoryView: View {
    @ObservedObject private var dataService = SessionDataService.shared
    @State private var selectedSession: SessionStats?
    @State private var searchText = ""
    @State private var sortOption: SessionSortOption = .newest

    private var filteredSessions: [SessionStats] {
        var sessions = dataService.sessionStats

        // Filter by search text
        if !searchText.isEmpty {
            sessions = sessions.filter {
                $0.projectName.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Sort
        switch sortOption {
        case .newest:
            sessions.sort { $0.startTime > $1.startTime }
        case .oldest:
            sessions.sort { $0.startTime < $1.startTime }
        case .costHigh:
            sessions.sort { $0.estimatedCost > $1.estimatedCost }
        case .durationLong:
            sessions.sort { $0.duration > $1.duration }
        }

        return sessions
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Session History")
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    dataService.loadAllSessions()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .disabled(dataService.isLoading)

                Picker("Sort", selection: $sortOption) {
                    ForEach(SessionSortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 130)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Search field
            TextField("Search by project name...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            Divider()

            // Content
            if dataService.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading sessions...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Spacer()
                }
            } else if filteredSessions.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No Sessions Found")
                        .font(.headline)
                        .padding(.top, 8)
                    Text(searchText.isEmpty ? "Session history will appear after using Claude Code" : "No sessions match your search")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                HSplitView {
                    // Session list
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(filteredSessions) { session in
                                SessionHistoryRow(
                                    session: session,
                                    isSelected: selectedSession?.id == session.id
                                )
                                .onTapGesture {
                                    selectedSession = session
                                }
                            }
                        }
                        .padding(12)
                    }
                    .frame(minWidth: 280, idealWidth: 280, maxWidth: 320)

                    // Detail panel
                    if let session = selectedSession {
                        SessionDetailPanel(session: session)
                    } else {
                        VStack {
                            Spacer()
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("Select a Session")
                                .font(.headline)
                                .padding(.top, 8)
                            Text("Choose a session from the list to view details")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .onAppear {
            if dataService.sessionStats.isEmpty {
                dataService.loadAllSessions()
            }
        }
    }
}

// MARK: - Session History Row

struct SessionHistoryRow: View {
    let session: SessionStats
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(session.projectName)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .lineLimit(1)

                Spacer()

                Text(session.startTime.relativeTime)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                Label(session.formattedDuration, systemImage: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Label("\(session.messageCount)", systemImage: "message")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Label(session.formattedCost, systemImage: "dollarsign.circle")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Session Detail Panel

struct SessionDetailPanel: View {
    let session: SessionStats

    private var modelBadge: String {
        guard let model = session.model else { return "Unknown Model" }
        if model.contains("opus") { return "Opus 4.5" }
        if model.contains("sonnet") { return "Sonnet 4" }
        if model.contains("haiku") { return "Haiku" }
        return model
    }

    private var cacheSavings: Double {
        // Use actual model pricing for accurate cache savings calculation
        let pricing = ModelPricing.pricing(for: session.model ?? "sonnet")
        // Savings = what cached tokens would have cost at full input price minus actual cache cost
        let fullCost = Double(session.cacheReadTokens) / 1_000_000 * pricing.inputPerMTok
        let cachedCost = Double(session.cacheReadTokens) / 1_000_000 * pricing.cacheReadPerMTok
        return fullCost - cachedCost
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Project info
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.projectName)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(session.projectPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    // Model badge
                    Text(modelBadge)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.15))
                        .foregroundColor(.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(.top, 4)
                }

                Divider()

                // Time section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Time")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    VStack(spacing: 6) {
                        StatItem(label: "Started", value: session.startTime.formatted(date: .abbreviated, time: .shortened))
                        StatItem(label: "Duration", value: session.formattedDuration)
                        StatItem(label: "Messages", value: "\(session.messageCount)")
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Token usage section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Token Usage")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    VStack(spacing: 6) {
                        TokenRow(label: "Input", count: session.inputTokens, color: .blue)
                        TokenRow(label: "Output", count: session.outputTokens, color: .green)
                        TokenRow(label: "Cache Read", count: session.cacheReadTokens, color: .orange)
                        TokenRow(label: "Cache Write", count: session.cacheWriteTokens, color: .purple)

                        Divider()
                            .padding(.vertical, 4)

                        HStack {
                            Text("Total")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(formatTokenCount(session.inputTokens + session.outputTokens + session.cacheReadTokens + session.cacheWriteTokens))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Cost section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cost")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        CostCard(
                            title: "Estimated Cost",
                            value: formatCost(session.estimatedCost),
                            color: .blue
                        )

                        CostCard(
                            title: "Cache Savings",
                            value: formatCost(cacheSavings),
                            color: .green
                        )
                    }
                }

                Spacer()
            }
            .padding(16)
        }
    }

    private func formatCost(_ cost: Double) -> String {
        if cost < 0.01 {
            return String(format: "$%.4f", cost)
        } else {
            return String(format: "$%.2f", cost)
        }
    }
}

// MARK: - Helper Views

struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .monospacedDigit()
        }
    }
}

struct TokenRow: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Text(formatTokenCount(count))
                .font(.caption)
                .monospacedDigit()
        }
    }
}

struct CostCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Formatting Helpers

private func formatTokenCount(_ count: Int) -> String {
    if count < 1000 {
        return "\(count)"
    } else if count < 1_000_000 {
        let value = Double(count) / 1000.0
        return String(format: "%.1fK", value)
    } else {
        let value = Double(count) / 1_000_000.0
        return String(format: "%.1fM", value)
    }
}

// MARK: - Date Extension

extension Date {
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview {
    SessionHistoryView()
        .frame(width: 700, height: 500)
}
