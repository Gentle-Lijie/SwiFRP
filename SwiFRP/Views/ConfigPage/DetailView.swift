import SwiftUI

struct DetailView: View {
    @Binding var config: ClientConfig
    @StateObject private var proxyViewModel: ProxyListViewModel

    init(config: Binding<ClientConfig>) {
        self._config = config
        _proxyViewModel = StateObject(wrappedValue: ProxyListViewModel(config: config.wrappedValue))
    }

    var body: some View {
        VStack(spacing: 0) {
            PanelView(config: $config)
                .padding()

            Divider()

            ProxyTableView(config: $config, viewModel: proxyViewModel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: config) { newConfig in
            proxyViewModel.config = newConfig
        }
    }
}
