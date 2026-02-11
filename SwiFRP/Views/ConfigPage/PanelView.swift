import SwiftUI

struct PanelView: View {
    @Binding var config: ClientConfig
    @ObservedObject private var statusTracker = StatusTracker.shared
    @State private var isShowingStopConfirmation = false

    private var configState: ConfigState {
        statusTracker.configStates[config.name] ?? .unknown
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status row
            HStack(spacing: 8) {
                statusIcon
                statusText
                Spacer()
                actionButton
            }

            Divider()

            // Server address row
            HStack {
                Label(String(localized: "panel.serverAddress"), systemImage: "server.rack")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Spacer()
                Text(serverDisplayAddress)
                    .font(.caption)
                    .textSelection(.enabled)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(serverDisplayAddress, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help(String(localized: "common.copy"))
            }

            // Protocol row
            HStack {
                Label(String(localized: "panel.protocol"), systemImage: "bolt.horizontal")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Spacer()
                HStack(spacing: 4) {
                    Text(config.protocol)
                        .font(.caption)
                    if config.tlsEnable {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                            .help(String(localized: "panel.tlsEnabled"))
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .confirmationDialog(
            String(localized: "panel.stopConfirmation"),
            isPresented: $isShowingStopConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "panel.stop"), role: .destructive) {
                stopConfig()
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        }
    }

    // MARK: - Status Display

    @ViewBuilder
    private var statusIcon: some View {
        switch configState {
        case .started:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .stopped:
            Image(systemName: "stop.circle.fill")
                .foregroundColor(.gray)
        case .starting, .stopping:
            ProgressView()
                .controlSize(.small)
        case .unknown:
            Image(systemName: "questionmark.circle")
                .foregroundColor(.secondary)
        }
    }

    private var statusText: Text {
        switch configState {
        case .started:
            return Text(String(localized: "panel.status.running"))
                .foregroundColor(.green)
                .font(.headline)
        case .stopped:
            return Text(String(localized: "panel.status.stopped"))
                .foregroundColor(.secondary)
                .font(.headline)
        case .starting:
            return Text(String(localized: "panel.status.starting"))
                .foregroundColor(.orange)
                .font(.headline)
        case .stopping:
            return Text(String(localized: "panel.status.stopping"))
                .foregroundColor(.orange)
                .font(.headline)
        case .unknown:
            return Text(String(localized: "panel.status.unknown"))
                .foregroundColor(.secondary)
                .font(.headline)
        }
    }

    // MARK: - Action Button

    @ViewBuilder
    private var actionButton: some View {
        switch configState {
        case .started:
            Button {
                isShowingStopConfirmation = true
            } label: {
                Label(String(localized: "panel.stop"), systemImage: "stop.fill")
            }
            .buttonStyle(.bordered)

        case .stopped, .unknown:
            Button {
                startConfig()
            } label: {
                Label(String(localized: "panel.start"), systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)

        case .starting, .stopping:
            Button {
                // Disabled during transitions
            } label: {
                ProgressView()
                    .controlSize(.small)
            }
            .disabled(true)
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Helpers

    private var serverDisplayAddress: String {
        if config.serverAddr.isEmpty {
            return String(localized: "panel.noServer")
        }
        return "\(config.serverAddr):\(config.serverPort)"
    }

    private func startConfig() {
        statusTracker.configStates[config.name] = .starting
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try LaunchdManager.shared.install(config: config, autoStart: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    statusTracker.refreshStatus(for: config.name)
                }
            } catch {
                DispatchQueue.main.async {
                    statusTracker.configStates[config.name] = .stopped
                }
            }
        }
    }

    private func stopConfig() {
        statusTracker.configStates[config.name] = .stopping
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try LaunchdManager.shared.stop(configName: config.name)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    statusTracker.refreshStatus(for: config.name)
                }
            } catch {
                DispatchQueue.main.async {
                    statusTracker.configStates[config.name] = .started
                }
            }
        }
    }
}
