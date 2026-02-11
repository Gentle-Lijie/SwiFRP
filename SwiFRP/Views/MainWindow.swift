import SwiftUI

struct MainWindow: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            List(AppTab.allCases, id: \.self, selection: $appState.selectedTab) { tab in
                Label(tab.rawValue.capitalized, systemImage: iconForTab(tab))
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            switch appState.selectedTab {
            case .configuration:
                Text("Configuration")
            case .log:
                Text("Log")
            case .preferences:
                Text("Preferences")
            case .about:
                Text("About")
            }
        }
    }

    private func iconForTab(_ tab: AppTab) -> String {
        switch tab {
        case .configuration: return "gearshape"
        case .log: return "doc.text"
        case .preferences: return "slider.horizontal.3"
        case .about: return "info.circle"
        }
    }
}
