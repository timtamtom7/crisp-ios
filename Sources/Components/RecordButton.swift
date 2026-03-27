import SwiftUI

struct RecordButton: View {
    let state: CaptureViewModel.State
    let action: () -> Void

    @State private var isPulsing = false

    var body: some View {
        Button(action: {
            // iOS 26: Haptic feedback on record button tap
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            action()
        }) {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(ringColor, lineWidth: state == .listening ? 3 : 2)
                    .frame(width: 80, height: 80)
                    .scaleEffect(isPulsing && state == .listening ? 1.15 : 1.0)
                    .opacity(isPulsing && state == .listening ? 0.3 : 1.0)

                // Inner circle / square
                if state == .idle {
                    Circle()
                        .fill(DesignTokens.accent)
                        .frame(width: 64, height: 64)
                } else if state == .listening {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(DesignTokens.accent)
                        .frame(width: 28, height: 28)
                } else {
                    Circle()
                        .fill(DesignTokens.accent.opacity(0.7))
                        .frame(width: 64, height: 64)
                }
            }
        }
        .buttonStyle(RecordButtonStyle())
        .onChange(of: state) { _, newValue in
            if newValue == .listening {
                startPulse()
            } else {
                isPulsing = false
            }
        }
    }

    private var ringColor: Color {
        switch state {
        case .idle: return DesignTokens.accent.opacity(0.5)
        case .listening: return DesignTokens.accent
        case .processing: return DesignTokens.accent.opacity(0.7)
        case .saved: return DesignTokens.accent
        }
    }

    private func startPulse() {
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
    }
}

struct RecordButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
