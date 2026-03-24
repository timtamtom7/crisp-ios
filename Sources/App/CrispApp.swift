import SwiftUI

@main
struct CrispApp: App {
    @StateObject private var appState = AppState()
    @State private var showOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if showOnboarding {
                    OnboardingView(isCompleted: $showOnboarding)
                } else {
                    ContentView()
                        .environmentObject(appState)
                        .preferredColorScheme(.dark)
                }
            }
            .onAppear {
                showOnboarding = !appState.isOnboardingCompleted
            }
        }
    }
}
