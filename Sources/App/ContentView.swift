import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showPricing = false

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            CaptureView(showPricing: $showPricing)
                .tabItem {
                    Label("Capture", systemImage: "mic.fill")
                }
                .tag(AppState.Tab.capture)

            LibraryView(showPricing: $showPricing)
                .tabItem {
                    Label("Library", systemImage: "waveform")
                }
                .tag(AppState.Tab.library)
        }
        .tint(DesignTokens.accent)
        .sheet(isPresented: $showPricing) {
            PricingView()
        }
    }
}
