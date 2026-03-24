import SwiftUI

struct WaveformView: View {
    let audioLevel: Float
    let isAnimating: Bool

    @State private var phase: Double = 0
    @State private var bars: [CGFloat] = Array(repeating: 0.2, count: 40)

    private let barCount = 40
    private let barSpacing: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    WaveformBar(
                        height: bars[index],
                        maxHeight: geometry.size.height,
                        isAnimating: isAnimating,
                        index: index
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            startAnimation()
        }
        .onChange(of: audioLevel) { _, newValue in
            updateBars(with: newValue)
        }
        .onChange(of: isAnimating) { _, newValue in
            if !newValue {
                fadeBarsToIdle()
            }
        }
    }

    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            if isAnimating {
                phase += 0.15
                updateBarsWithPhase()
            }
        }
    }

    private func updateBarsWithPhase() {
        withAnimation(.linear(duration: 0.05)) {
            for i in 0..<barCount {
                let normalizedLevel = CGFloat(audioLevel)
                let wave = sin(phase + Double(i) * 0.3) * 0.5 + 0.5
                let base = 0.15 + normalizedLevel * 0.7 * CGFloat(wave)
                bars[i] = max(0.1, min(1.0, base))
            }
        }
    }

    private func updateBars(with level: Float) {
        guard isAnimating else { return }
        withAnimation(.linear(duration: 0.05)) {
            for i in 0..<barCount {
                let normalizedLevel = CGFloat(level)
                let wave = sin(phase + Double(i) * 0.3) * 0.5 + 0.5
                let base = 0.15 + normalizedLevel * 0.7 * CGFloat(wave)
                bars[i] = max(0.1, min(1.0, base))
            }
        }
    }

    private func fadeBarsToIdle() {
        withAnimation(.easeOut(duration: 0.5)) {
            for i in 0..<barCount {
                bars[i] = 0.15 + CGFloat.random(in: 0...0.1)
            }
        }
    }
}

struct WaveformBar: View {
    let height: CGFloat
    let maxHeight: CGFloat
    let isAnimating: Bool
    let index: Int

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(
                LinearGradient(
                    colors: [
                        DesignTokens.accentGradientStart,
                        DesignTokens.accentGradientMid,
                        DesignTokens.accentGradientEnd
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: 3, height: max(4, maxHeight * height))
            .shadow(color: DesignTokens.accent.opacity(isAnimating ? 0.6 : 0.2), radius: isAnimating ? 4 : 1)
    }
}
