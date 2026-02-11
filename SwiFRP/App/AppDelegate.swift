import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Single instance check
        let runningApps = NSRunningApplication.runningApplications(
            withBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.swifrp.app"
        )
        if runningApps.count > 1 {
            // Activate existing instance
            if let existingApp = runningApps.first(where: { $0 != NSRunningApplication.current }) {
                existingApp.activate()
            }
            NSApp.terminate(nil)
            return
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
    }
}
