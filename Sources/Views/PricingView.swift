import SwiftUI

struct PricingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("crisp_subscription_tier") private var subscriptionTier = "free"

    var body: some View {
        ZStack {
            DesignTokens.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Choose your plan")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(DesignTokens.textPrimary)

                        Text("Start free. Upgrade anytime.")
                            .font(.system(size: 16))
                            .foregroundColor(DesignTokens.textSecondary)
                    }
                    .padding(.top, 8)

                    // Tier cards
                    VStack(spacing: 16) {
                        PricingTierCard(
                            tier: .free,
                            isSelected: subscriptionTier == "free",
                            onSelect: { selectTier("free") }
                        )

                        PricingTierCard(
                            tier: .pro,
                            isSelected: subscriptionTier == "pro",
                            onSelect: { selectTier("pro") }
                        )

                        PricingTierCard(
                            tier: .unlimited,
                            isSelected: subscriptionTier == "unlimited",
                            onSelect: { selectTier("unlimited") },
                            isHighlighted: true
                        )
                    }

                    // FAQ / note
                    VStack(spacing: 8) {
                        Text("Cancel anytime. No hidden fees.")
                            .font(.system(size: 13))
                            .foregroundColor(DesignTokens.textSecondary)

                        Text("Prices in USD. Billed monthly.")
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.textSecondary.opacity(0.7))
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(DesignTokens.textSecondary)
                            .padding(16)
                    }
                }
                Spacer()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func selectTier(_ tier: String) {
        subscriptionTier = tier
    }
}

// MARK: - Pricing Tier

enum PricingTier: String, CaseIterable {
    case free
    case pro
    case unlimited

    var name: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        case .unlimited: return "Unlimited"
        }
    }

    var price: String {
        switch self {
        case .free: return "$0"
        case .pro: return "$4.99"
        case .unlimited: return "$9.99"
        }
    }

    var period: String {
        switch self {
        case .free: return "forever"
        case .pro, .unlimited: return "/month"
        }
    }

    var tagline: String {
        switch self {
        case .free: return "Try it out"
        case .pro: return "For daily users"
        case .unlimited: return "No compromises"
        }
    }

    var features: [String] {
        switch self {
        case .free:
            return [
                "10 recordings per month",
                "Up to 10 minutes per recording",
                "Basic transcription",
                "Searchable library"
            ]
        case .pro:
            return [
                "Unlimited recordings",
                "Up to 10 minutes per recording",
                "Full transcription",
                "Cloud sync",
                "Export to text",
                "Searchable library"
            ]
        case .unlimited:
            return [
                "Everything in Pro",
                "Record up to 2 hours",
                "Priority transcription",
                "Advanced editing tools",
                "Priority support",
                "Cloud sync"
            ]
        }
    }

    var isFree: Bool { self == .free }
}

// MARK: - Pricing Tier Card

struct PricingTierCard: View {
    let tier: PricingTier
    let isSelected: Bool
    let onSelect: () -> Void
    var isHighlighted: Bool = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 0) {
                // Top row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(tier.name)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(DesignTokens.textPrimary)

                            if isHighlighted {
                                Text("Best value")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(DesignTokens.background)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(DesignTokens.accent)
                                    .clipShape(Capsule())
                            }
                        }

                        Text(tier.tagline)
                            .font(.system(size: 13))
                            .foregroundColor(DesignTokens.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text(tier.price)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(DesignTokens.textPrimary)

                            Text(tier.period)
                                .font(.system(size: 13))
                                .foregroundColor(DesignTokens.textSecondary)
                        }
                    }
                }
                .padding(20)

                Divider()
                    .background(DesignTokens.textSecondary.opacity(0.15))

                // Features
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(tier.features, id: \.self) { feature in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(isHighlighted ? DesignTokens.accent : DesignTokens.accent.opacity(0.8))
                                .frame(width: 20)

                            Text(feature)
                                .font(.system(size: 14))
                                .foregroundColor(DesignTokens.textPrimary)
                        }
                    }
                }
                .padding(20)

                // Selected indicator
                if isSelected {
                    HStack {
                        Spacer()
                        Text("Current plan")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignTokens.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(DesignTokens.accent.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusLg)
                    .fill(DesignTokens.surface.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.radiusLg)
                            .stroke(
                                isSelected
                                    ? DesignTokens.accent
                                    : (isHighlighted ? DesignTokens.accent.opacity(0.4) : DesignTokens.textSecondary.opacity(0.1)),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.radiusLg)
                            .fill(.ultraThinMaterial)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusLg))
            .shadow(color: isHighlighted ? DesignTokens.accent.opacity(0.1) : .clear, radius: 12)
        }
        .buttonStyle(.plain)
    }
}
