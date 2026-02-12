import SwiftUI

struct PanelView: View {
    @Binding var config: ClientConfig
    @ObservedObject private var statusTracker = StatusTracker.shared
    @State private var isShowingStopConfirmation = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var errorDetails = ""
    @State private var showSuccess = false

    private var configState: ConfigState {
        statusTracker.configStates[config.name] ?? .unknown
    }
    
    private var frpcMissing: Bool {
        !LaunchdManager.shared.frpcExists
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // FRPC Missing Warning
            if frpcMissing {
                frpcMissingWarning
            }
            
            // Error message
            if !errorMessage.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
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
                Label(L("panel.serverAddress"), systemImage: "server.rack")
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
                .help(L("common.copy"))
            }

            // Protocol row
            HStack {
                Label(L("panel.protocol"), systemImage: "bolt.horizontal")
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
                            .help(L("panel.tlsEnabled"))
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
            L("panel.stopConfirmation"),
            isPresented: $isShowingStopConfirmation,
            titleVisibility: .visible
        ) {
            Button(L("panel.stop"), role: .destructive) {
                stopConfig()
            }
            Button(L("common.cancel"), role: .cancel) {}
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text(L("error.title")),
                message: Text(errorDetails),
                dismissButton: .default(Text(L("common.ok")))
            )
        }
        .alert(isPresented: $showSuccess) {
            Alert(
                title: Text(L("panel.startSuccess")),
                message: Text(""),
                dismissButton: .default(Text(L("common.ok")))
            )
        }
    }
    
    // MARK: - FRPC Missing Warning
    
    private var frpcMissingWarning: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            VStack(alignment: .leading, spacing: 2) {
                Text(L("panel.frpcNotFound"))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
                Text(L("panel.frpcNotFoundHint"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button {
                if let url = URL(string: "https://github.com/fatedier/frp/releases") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Text(L("panel.download"))
                    .font(.caption)
            }
            .buttonStyle(.link)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.red.opacity(0.1))
        )
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
            return Text(L("panel.status.running"))
                .foregroundColor(.green)
                .font(.headline)
        case .stopped:
            return Text(L("panel.status.stopped"))
                .foregroundColor(.secondary)
                .font(.headline)
        case .starting:
            return Text(L("panel.status.starting"))
                .foregroundColor(.orange)
                .font(.headline)
        case .stopping:
            return Text(L("panel.status.stopping"))
                .foregroundColor(.orange)
                .font(.headline)
        case .unknown:
            return Text(L("panel.status.unknown"))
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
                Label(L("panel.stop"), systemImage: "stop.fill")
            }
            .buttonStyle(.bordered)

        case .stopped, .unknown:
            Button {
                startConfig()
            } label: {
                Label(L("panel.start"), systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(frpcMissing)

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
            return L("panel.noServer")
        }
        return "\(config.serverAddr):\(config.serverPort)"
    }

    private func startConfig() {
        guard !frpcMissing else { return }
        
        errorMessage = ""
        statusTracker.configStates[config.name] = .starting
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try LaunchdManager.shared.install(config: config, autoStart: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    statusTracker.refreshStatus(for: config.name)
                    
                    // Check for errors after starting
                    if let error = LaunchdManager.shared.getServiceError(configName: config.name) {
                        // Read last lines of log for details
                        let logContent = readRecentLog()
                        DispatchQueue.main.async {
                            errorDetails = "\(error)\n\nLog:\n\(logContent)"
                            showError = true
                            statusTracker.configStates[config.name] = .stopped
                        }
                    } else {
                        // Success
                        DispatchQueue.main.async {
                            showSuccess = true
                        }
                    }
                    
                    // Probe proxy statuses
                    Task {
                        await statusTracker.probeProxies(for: config)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    statusTracker.configStates[config.name] = .stopped
                    errorDetails = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func stopConfig() {
        errorMessage = ""
        statusTracker.configStates[config.name] = .stopping
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try LaunchdManager.shared.stop(configName: config.name)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    statusTracker.refreshStatus(for: config.name)
                    // Verify it actually stopped
                    let state = statusTracker.configStates[config.name] ?? .unknown
                    if state != .stopped {
                        errorMessage = "Service may still be running. Try stopping again."
                    }
                    // Clear proxy statuses
                    statusTracker.proxyStatuses[config.name] = []
                }
            } catch {
                DispatchQueue.main.async {
                    statusTracker.configStates[config.name] = .started
                    errorDetails = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func readRecentLog() -> String {
        let logURL = AppPaths.logURL(for: config.name)
        guard let content = try? String(contentsOf: logURL, encoding: .utf8) else {
            return "Unable to read log file"
        }
        let lines = content.components(separatedBy: .newlines)
        let recentLines = lines.suffix(20)
        return recentLines.joined(separator: "\n")
    }
}
