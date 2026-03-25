import SwiftUI

// MARK: - WaveformView

struct WaveformView: View {
    let audioLevel: Float
    let isAnimating: Bool

    @State private var phase: Double = 0
    @State private var bars: [CGFloat] = Array(repeating: 0.2, count: 40)
    @State private var animationTimer: Timer?

    private let barCount = 40
    private let barSpacing: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    WaveformBar(
                        height: bars[index],
                        maxHeight: geometry.size.height,
                        isAnimating: isAnimating
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
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
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            guard isAnimating else { return }
            phase += 0.15
            updateBarsWithPhase()
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func updateBarsWithPhase() {
        for i in 0..<barCount {
            let normalizedLevel = CGFloat(audioLevel)
            let wave = sin(phase + Double(i) * 0.3) * 0.5 + 0.5
            let base = 0.15 + normalizedLevel * 0.7 * CGFloat(wave)
            bars[i] = max(0.1, min(1.0, base))
        }
    }

    private func updateBars(with level: Float) {
        guard isAnimating else { return }
        for i in 0..<barCount {
            let normalizedLevel = CGFloat(level)
            let wave = sin(phase + Double(i) * 0.3) * 0.5 + 0.5
            let base = 0.15 + normalizedLevel * 0.7 * CGFloat(wave)
            bars[i] = max(0.1, min(1.0, base))
        }
    }

    private func fadeBarsToIdle() {
        for i in 0..<barCount {
            bars[i] = 0.15 + CGFloat.random(in: 0...0.1)
        }
    }
}

// MARK: - WaveformBar

struct WaveformBar: View {
    let height: CGFloat
    let maxHeight: CGFloat
    let isAnimating: Bool

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
    }
}
