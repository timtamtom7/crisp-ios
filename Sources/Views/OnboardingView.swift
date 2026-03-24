import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @Binding var isCompleted: Bool
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            DesignTokens.background
                .ignoresSafeArea()

            TabView(selection: $currentPage) {
                OnboardingPage1()
                    .tag(0)

                OnboardingPage2()
                    .tag(1)

                OnboardingPage3()
                    .tag(2)

                OnboardingPage4(onComplete: {
                    markCompleted()
                })
                .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            // Page indicator + skip
            VStack {
                Spacer()

                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? DesignTokens.accent : DesignTokens.textSecondary.opacity(0.4))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentPage ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 32)

                if currentPage < 3 {
                    Button {
                        markCompleted()
                    } label: {
                        Text("Skip")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DesignTokens.textSecondary)
                    }
                    .padding(.bottom, 48)
                } else {
                    Spacer()
                        .frame(height: 80)
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private func markCompleted() {
        UserDefaults.standard.set(true, forKey: "onboarding_completed_v1")
        withAnimation(.easeOut(duration: 0.3)) {
            isCompleted = false
        }
    }
}

// MARK: - Page 1: Your thoughts, captured

struct OnboardingPage1: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Custom graphic: layered waveforms with a thought bubble / capture frame
            OnboardingGraphic1()
                .frame(width: 240, height: 240)
                .padding(.bottom, 48)

            VStack(spacing: 12) {
                Text("Your thoughts, captured")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(DesignTokens.textPrimary)
                    .multilineTextAlignment(.center)

                Text("One tap. Speak your mind. Walk away with a perfectly transcribed note — no typing, no organizing, no friction.")
                    .font(.system(size: 16))
                    .foregroundColor(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Page 2: Speak freely

struct OnboardingPage2: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            OnboardingGraphic2()
                .frame(width: 240, height: 240)
                .padding(.bottom, 48)

            VStack(spacing: 12) {
                Text("Speak freely")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(DesignTokens.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Watch your words appear in real-time as you talk. Crisp transcribes as you speak — every syllable, captured the moment it leaves your mouth.")
                    .font(.system(size: 16))
                    .foregroundColor(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Page 3: Find anything instantly

struct OnboardingPage3: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            OnboardingGraphic3()
                .frame(width: 240, height: 240)
                .padding(.bottom, 48)

            VStack(spacing: 12) {
                Text("Find anything instantly")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(DesignTokens.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Every word, searchable. Your library is your second memory — search across all your recordings and pull up any moment in seconds.")
                    .font(.system(size: 16))
                    .foregroundColor(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Page 4: You're ready

struct OnboardingPage4: View {
    let onComplete: () -> Void
    @State private var showPermissionRequest = false
    @State private var permissionGranted = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            OnboardingGraphic4(permissionGranted: permissionGranted)
                .frame(width: 240, height: 240)
                .padding(.bottom, 48)

            VStack(spacing: 12) {
                Text("You're ready")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(DesignTokens.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Crisp needs microphone access to start capturing your voice. Tap below to grant permission — you can change this anytime in Settings.")
                    .font(.system(size: 16))
                    .foregroundColor(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if showPermissionRequest {
                    Text("Permission required to record")
                        .font(.system(size: 13))
                        .foregroundColor(.red.opacity(0.8))
                        .padding(.top, 8)
                }
            }

            Spacer()

            Button {
                requestPermissions()
            } label: {
                Text(permissionGranted ? "Permission granted" : "Enable microphone")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(permissionGranted ? DesignTokens.background : DesignTokens.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        permissionGranted
                            ? DesignTokens.accent.opacity(0.5)
                            : DesignTokens.accent
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(permissionGranted)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private func requestPermissions() {
        AVAudioApplication.requestRecordPermission { granted in
            Task { @MainActor in
                if granted {
                    permissionGranted = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        onComplete()
                    }
                } else {
                    showPermissionRequest = true
                }
            }
        }
    }
}

// MARK: - Custom Onboarding Graphics

struct OnboardingGraphic1: View {
    @State private var wavePhase: Double = 0

    var body: some View {
        ZStack {
            // Background circle — subtle
            Circle()
                .fill(DesignTokens.surface)
                .frame(width: 200, height: 200)

            // Concentric waveform rings
            ForEach(0..<3, id: \.self) { ring in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                DesignTokens.accentGradientStart.opacity(0.6 - Double(ring) * 0.15),
                                DesignTokens.accentGradientEnd.opacity(0.3 - Double(ring) * 0.08)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 100 + CGFloat(ring) * 50, height: 100 + CGFloat(ring) * 50)
                    .scaleEffect(1.0 + CGFloat(ring) * 0.05)
            }

            // Central waveform bars
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [DesignTokens.accentGradientStart, DesignTokens.accentGradientEnd],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 8, height: barHeight(for: i))
                        .shadow(color: DesignTokens.accent.opacity(0.5), radius: 6)
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    wavePhase = .pi * 2
                }
            }

            // Floating dots — representing captured thoughts
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .fill(DesignTokens.accent.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .offset(dotOffset(for: i))
                    .onAppear {
                        // Subtle float animation per dot
                    }
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [40, 65, 80, 55, 35]
        return heights[index]
    }

    private func dotOffset(for index: Int) -> CGSize {
        let offsets: [(CGFloat, CGFloat)] = [
            (-90, -70), (80, -50), (-70, 80), (90, 60)
        ]
        return CGSize(width: offsets[index].0, height: offsets[index].1)
    }
}

struct OnboardingGraphic2: View {
    @State private var isAnimating = false
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Radiating rings
            ForEach(0..<4, id: \.self) { ring in
                Circle()
                    .stroke(DesignTokens.accent.opacity(0.3 - Double(ring) * 0.07), lineWidth: 1.5)
                    .frame(width: 60 + CGFloat(ring) * 40, height: 60 + CGFloat(ring) * 40)
                    .scaleEffect(pulseScale + CGFloat(ring) * 0.08)
                    .opacity(2.0 - pulseScale - CGFloat(ring) * 0.3)
            }

            // Mic icon
            ZStack {
                Circle()
                    .fill(DesignTokens.accent)
                    .frame(width: 72, height: 72)
                    .shadow(color: DesignTokens.accent.opacity(0.5), radius: 12)

                Image(systemName: "mic.fill")
                    .font(.system(size: 28))
                    .foregroundColor(DesignTokens.background)
            }

            // Sound wave lines from mic
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [DesignTokens.accentGradientStart, DesignTokens.accentGradientEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 30 + CGFloat(i) * 12, height: 4)
                    .offset(y: CGFloat(i - 1) * 28)
                    .opacity(Double(2 - i) * 0.3)
                    .rotationEffect(.degrees(i == 1 ? 0 : (i == 0 ? -20 : 20)))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                pulseScale = 1.4
            }
        }
    }
}

struct OnboardingGraphic3: View {
    @State private var searchOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Background card
            RoundedRectangle(cornerRadius: 20)
                .fill(DesignTokens.surface)
                .frame(width: 220, height: 160)

            // Magnifying glass with waveform inside
            ZStack {
                Circle()
                    .stroke(DesignTokens.accent, lineWidth: 3)
                    .frame(width: 64, height: 64)

                Image(systemName: "waveform")
                    .font(.system(size: 22))
                    .foregroundColor(DesignTokens.accent)
                    .offset(x: 4, y: 4)

                // Handle
                Capsule()
                    .fill(DesignTokens.accent)
                    .frame(width: 4, height: 24)
                    .rotationEffect(.degrees(45))
                    .offset(x: 26, y: 26)
            }
            .offset(y: -20)

            // Floating transcript lines
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(DesignTokens.textSecondary.opacity(0.4))
                    .frame(width: 100, height: 6)

                RoundedRectangle(cornerRadius: 3)
                    .fill(DesignTokens.textSecondary.opacity(0.25))
                    .frame(width: 130, height: 6)

                RoundedRectangle(cornerRadius: 3)
                    .fill(DesignTokens.accent.opacity(0.7))
                    .frame(width: 80, height: 6)
            }
            .offset(y: 40)

            // Search highlight glow
            RoundedRectangle(cornerRadius: 4)
                .stroke(DesignTokens.accent.opacity(0.6), lineWidth: 2)
                .frame(width: 86, height: 14)
                .offset(y: 48)
                .shadow(color: DesignTokens.accent.opacity(0.4), radius: 4)
        }
        .offset(x: searchOffset)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                searchOffset = 8
            }
        }
    }
}

struct OnboardingGraphic4: View {
    let permissionGranted: Bool
    @State private var pulseScale: CGFloat = 1.0
    @State private var checkRotation: Double = 0

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(DesignTokens.surface)
                .frame(width: 200, height: 200)

            // Outer pulse ring
            if permissionGranted {
                Circle()
                    .stroke(DesignTokens.accent.opacity(0.4), lineWidth: 2)
                    .frame(width: 180, height: 180)
                    .scaleEffect(pulseScale)
                    .opacity(2.0 - pulseScale)
            }

            // Mic
            ZStack {
                Circle()
                    .fill(permissionGranted ? DesignTokens.accent : DesignTokens.textSecondary.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .shadow(color: permissionGranted ? DesignTokens.accent.opacity(0.6) : .clear, radius: 16)

                Image(systemName: permissionGranted ? "checkmark" : "mic.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(permissionGranted ? DesignTokens.background : DesignTokens.textSecondary)
                    .rotationEffect(.degrees(permissionGranted ? 0 : 0))
            }
            .scaleEffect(permissionGranted ? 1.0 : 1.0)

            // Small orbiting dots
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(DesignTokens.accent.opacity(0.5))
                    .frame(width: 10, height: 10)
                    .offset(orbitOffset(index: i, radius: 110))
                    .opacity(permissionGranted ? 1.0 : 0.0)
            }
        }
        .onChange(of: permissionGranted) { _, newValue in
            if newValue {
                withAnimation(.easeOut(duration: 0.8)) {
                    checkRotation = 360
                }
                withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    pulseScale = 1.3
                }
            }
        }
    }

    private func orbitOffset(index: Int, radius: CGFloat) -> CGSize {
        let angle = (Double(index) / 3.0) * .pi * 2 - .pi / 2
        return CGSize(
            width: cos(angle) * radius,
            height: sin(angle) * radius
        )
    }
}
