import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusMd)
                    .fill(DesignTokens.surface.opacity(0.7))
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.radiusMd)
                            .fill(.ultraThinMaterial)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusMd))
    }
}
