import SwiftUI

@main
struct SwiFRPApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        let args = CommandLine.arguments
        if args.contains("-v") {
            print("SwiFRP v0.1.0")
            print("FRP version: 0.61.1")
            print("Build date: 2026-02-11")
            exit(0)
        }
        if let idx = args.firstIndex(of: "-c"), idx + 1 < args.count {
            let configPath = args[idx + 1]
            print("Starting in service mode with config: \(configPath)")
            // Service mode would start frpc here
        }
    }

    var body: some Scene {
        WindowGroup {
            MainWindow()
                .frame(minWidth: 800, minHeight: 500)
                .environmentObject(AppState.shared)
        }
        .defaultSize(width: 1000, height: 650)
    }
}
