import SwiftUI

struct MacContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: AppState.Tab = .capture

    var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sidebarContent: some View {
        List(selection: $selectedTab) {
            NavigationLink(value: AppState.Tab.capture) {
                Label("Capture", systemImage: "waveform")
            }
            NavigationLink(value: AppState.Tab.library) {
                Label("Library", systemImage: "books.vertical")
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 280)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedTab {
        case .capture:
            CaptureView()
        case .library:
            LibraryView()
        }
    }
}
