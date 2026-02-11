import SwiftUI
import Combine

class LogViewModel: ObservableObject {
    @Published var selectedConfigName: String? = nil
    @Published var availableLogFiles: [URL] = []
    @Published var selectedLogFile: URL? = nil
    @Published var logContent: [String] = []
    @Published var isAutoRefreshing = false

    private var refreshTimer: Timer? = nil
    private var fileMonitor: DispatchSourceFileSystemObject? = nil

    private static let maxDisplayLines = 2000
    private static let refreshInterval: TimeInterval = 5.0

    deinit {
        stopAutoRefresh()
        stopFileMonitor()
    }

    // MARK: - Log Files

    func loadLogFiles() {
        guard let name = selectedConfigName else {
            availableLogFiles = []
            selectedLogFile = nil
            logContent = []
            return
        }
        availableLogFiles = FileUtils.logFilesForConfig(name: name)
        if let first = availableLogFiles.first {
            selectedLogFile = first
            loadLogContent()
        } else {
            selectedLogFile = nil
            logContent = []
        }
    }

    func loadLogContent() {
        guard let url = selectedLogFile else {
            logContent = []
            return
        }
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            if lines.count > Self.maxDisplayLines {
                logContent = Array(lines.suffix(Self.maxDisplayLines))
            } else {
                logContent = lines
            }
        } catch {
            logContent = [String(localized: "log.error.readFailed")]
        }
    }

    // MARK: - Auto Refresh

    func startAutoRefresh() {
        stopAutoRefresh()
        isAutoRefreshing = true
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.loadLogContent()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        isAutoRefreshing = false
    }

    // MARK: - File Monitor

    func startFileMonitor() {
        stopFileMonitor()
        guard let url = selectedLogFile,
              FileManager.default.fileExists(atPath: url.path) else { return }

        let fd = open(url.path, O_RDONLY | O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            let flags = source.data
            if flags.contains(.delete) || flags.contains(.rename) {
                self.stopFileMonitor()
                return
            }
            self.loadLogContent()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        fileMonitor = source
    }

    private func stopFileMonitor() {
        fileMonitor?.cancel()
        fileMonitor = nil
    }

    // MARK: - Actions

    func openLogFolder() {
        #if canImport(AppKit)
        if let url = selectedLogFile {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.open(AppPaths.logsDirectory)
        }
        #endif
    }

    func selectConfig(_ name: String?) {
        selectedConfigName = name
        stopAutoRefresh()
        stopFileMonitor()
        loadLogFiles()
    }

    func selectLogFile(_ url: URL?) {
        selectedLogFile = url
        stopFileMonitor()
        loadLogContent()
        if isAutoRefreshing {
            startFileMonitor()
        }
    }
}
