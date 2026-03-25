import Cocoa
import SwiftUI

@main
struct CrispMacApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MacContentView()
                .environmentObject(appState)
                .frame(minWidth: 800, minHeight: 600)
                .darkMode()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                appState.refreshWidgetNotes()
            }
        }
    }
}

// MARK: - Dark Mode Modifier

extension View {
    func darkMode() -> some View {
        self
            .preferredColorScheme(.dark)
            .environment(\.colorScheme, .dark)
    }
}
