import SwiftUI

struct ConfigPageView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: ConfigListViewModel

    init() {
        _viewModel = StateObject(wrappedValue: ConfigListViewModel(appState: AppState.shared))
    }

    var body: some View {
        HSplitView {
            ConfigListView(viewModel: viewModel)
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 350)

            if let index = appState.selectedConfigIndex,
               index >= 0, index < appState.configs.count {
                DetailView(config: $appState.configs[index])
            } else {
                WelcomeView()
            }
        }
    }
}

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "network")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            Text(L("welcome.title"))
                .font(.title2)
                .foregroundColor(.secondary)
            Text(L("welcome.subtitle"))
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
