import Combine
import Foundation

class StatusTracker: ObservableObject {
    static let shared = StatusTracker()

    @Published var configStates: [String: ConfigState] = [:]
    @Published var proxyStatuses: [String: [ProxyStatus]] = [:]

    private var timer: Timer?
    private var trackedConfigs: [ClientConfig] = []
    private let pollInterval: TimeInterval = 3.0

    private init() {}

    // MARK: - Tracking

    func startTracking() {
        stopTracking()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.timer = Timer.scheduledTimer(withTimeInterval: self.pollInterval, repeats: true) { [weak self] _ in
                self?.pollAll()
            }
            RunLoop.main.add(self.timer!, forMode: .common)
        }
        pollAll()
    }

    func stopTracking() {
        timer?.invalidate()
        timer = nil
    }

    func setTrackedConfigs(_ configs: [ClientConfig]) {
        trackedConfigs = configs
    }

    // MARK: - Refresh

    func refreshStatus(for configName: String) {
        let state = LaunchdManager.shared.queryStatus(configName: configName)
        DispatchQueue.main.async {
            self.configStates[configName] = state
        }
    }

    func probeProxies(for config: ClientConfig) async {
        guard config.adminPort > 0 else { return }

        do {
            let statuses = try await FRPCBridge.shared.fetchProxyStatus(
                adminAddr: config.adminAddr.isEmpty ? "127.0.0.1" : config.adminAddr,
                adminPort: config.adminPort,
                user: config.adminUser.isEmpty ? nil : config.adminUser,
                password: config.adminPwd.isEmpty ? nil : config.adminPwd
            )
            await MainActor.run {
                self.proxyStatuses[config.name] = statuses
            }
        } catch {
            await MainActor.run {
                self.proxyStatuses[config.name] = []
            }
        }
    }

    // MARK: - Internal

    private func pollAll() {
        for config in trackedConfigs {
            refreshStatus(for: config.name)

            if configStates[config.name] == .started && config.adminPort > 0 {
                Task {
                    await probeProxies(for: config)
                }
            }
        }
    }
}
