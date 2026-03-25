import SwiftUI

/// Displays AI-detected insights for a voice note: topic, sentiment, entities, speaking pace.
struct AIInsightsView: View {
    let analysis: AnalysisResult

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignTokens.accent)

                Text("AI Insights")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignTokens.textSecondary)

                Spacer()
            }

            // Topic badge
            if let topic = analysis.topic {
                InsightRow(
                    icon: topicIcon(for: topic),
                    label: "Topic",
                    value: topic,
                    color: topicColor(for: topic)
                )
            }

            // Sentiment
            if let sentiment = analysis.sentiment {
                InsightRow(
                    icon: sentimentIcon(for: sentiment),
                    label: "Sentiment",
                    value: sentimentLabel(for: sentiment),
                    color: sentimentColor(for: sentiment)
                )
            }

            // Speaking pace
            if let wpm = analysis.speakingPace {
                InsightRow(
                    icon: "gauge.with.dots.needle.33percent",
                    label: "Speaking Pace",
                    value: "\(Int(wpm)) wpm",
                    color: DesignTokens.accent
                )
            }

            // Entities
            if !analysis.entities.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.text.rectangle")
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.textSecondary)

                        Text("People & Places")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignTokens.textSecondary)
                    }

                    FlowLayout(spacing: 6) {
                        ForEach(analysis.entities.prefix(8), id: \.self) { entity in
                            Text(entity)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(DesignTokens.textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(DesignTokens.surface)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(DesignTokens.textSecondary.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                }
            }

            // Folder suggestion
            if let suggestion = analysis.folderSuggestion {
                HStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Suggested Folder")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DesignTokens.textSecondary)

                        Text(suggestion)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(DesignTokens.textPrimary)
                    }
                }
                .padding(10)
                .background(DesignTokens.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusSm))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusMd)
                .fill(DesignTokens.surface.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusMd)
                        .stroke(DesignTokens.textSecondary.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Helpers

    private func topicIcon(for topic: String) -> String {
        switch topic {
        case "Meeting": return "person.3.fill"
        case "Personal": return "heart.fill"
        case "Idea": return "lightbulb.fill"
        case "Tutorial": return "book.fill"
        case "News": return "newspaper.fill"
        case "Health": return "heart.text.square.fill"
        case "Work": return "briefcase.fill"
        default: return "tag.fill"
        }
    }

    private func topicColor(for topic: String) -> Color {
        switch topic {
        case "Meeting": return .blue
        case "Personal": return .pink
        case "Idea": return .yellow
        case "Tutorial": return .green
        case "News": return .orange
        case "Health": return .red
        case "Work": return .purple
        default: return DesignTokens.accent
        }
    }

    private func sentimentIcon(for sentiment: Double) -> String {
        if sentiment > 0.3 { return "face.smiling.fill" }
        if sentiment < -0.3 { return "face.smiling.inverse" }
        return "face.dashed.fill"
    }

    private func sentimentLabel(for sentiment: Double) -> String {
        if sentiment > 0.5 { return "Very Positive" }
        if sentiment > 0.2 { return "Positive" }
        if sentiment > -0.2 { return "Neutral" }
        if sentiment > -0.5 { return "Negative" }
        return "Very Negative"
    }

    private func sentimentColor(for sentiment: Double) -> Color {
        if sentiment > 0.3 { return .green }
        if sentiment < -0.3 { return .red }
        return DesignTokens.textSecondary
    }
}

// MARK: - Insight Row

struct InsightRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)
                .frame(width: 20)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DesignTokens.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DesignTokens.textPrimary)
        }
    }
}
