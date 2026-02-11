import SwiftUI

struct PropertiesDialog: View {
    let config: ClientConfig
    @Binding var isPresented: Bool
    @ObservedObject var statusTracker: StatusTracker = .shared

    var body: some View {
        VStack(spacing: 0) {
            Text(String(localized: "properties.title"))
                .font(.headline)
                .padding()

            ScrollView {
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 8) {
                    propertyRow(String(localized: "properties.configName"), config.name)
                    propertyRow(String(localized: "properties.identifier"), LaunchdManager.shared.serviceLabel(for: config.name))
                    propertyRow(String(localized: "properties.serviceName"), LaunchdManager.shared.serviceLabel(for: config.name))
                    propertyRow(String(localized: "properties.fileFormat"), config.legacyFormat ? "INI" : "TOML")
                    propertyRow(String(localized: "properties.serverAddr"), config.serverAddr)
                    propertyRow(String(localized: "properties.serverPort"), "\(config.serverPort)")
                    propertyRow(String(localized: "properties.protocol"), config.protocol)
                    propertyRow(String(localized: "properties.proxyCount"), "\(config.proxies.count)")
                    propertyRow(String(localized: "properties.startupMode"), config.manualStart
                        ? String(localized: "properties.manual")
                        : String(localized: "properties.automatic"))

                    let logFiles = FileUtils.logFilesForConfig(name: config.name)
                    propertyRow(String(localized: "properties.logFiles"), "\(logFiles.count)")
                    propertyRow(String(localized: "properties.logSize"), StringUtils.formatBytes(FileUtils.totalLogSize(name: config.name)))

                    if let state = statusTracker.configStates[config.name], state == .started {
                        if let proxies = statusTracker.proxyStatuses[config.name] {
                            let tcpCount = proxies.filter { $0.type == "tcp" }.count
                            let udpCount = proxies.filter { $0.type == "udp" }.count
                            propertyRow(String(localized: "properties.tcpConnections"), "\(tcpCount)")
                            propertyRow(String(localized: "properties.udpConnections"), "\(udpCount)")
                        }
                    }

                    let configURL = ConfigFileManager.shared.configFileURL(for: config.name)
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: configURL.path) {
                        if let created = attrs[.creationDate] as? Date {
                            propertyRow(String(localized: "properties.fileCreated"), dateString(created))
                        }
                        if let modified = attrs[.modificationDate] as? Date {
                            propertyRow(String(localized: "properties.fileModified"), dateString(modified))
                        }
                    }
                }
                .padding()
            }
            .frame(maxHeight: 400)

            Divider()

            HStack {
                Spacer()
                Button(String(localized: "common.close")) {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 480)
    }

    private func propertyRow(_ label: String, _ value: String) -> some GridRow<some View> {
        GridRow {
            Text(label)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .gridColumnAlignment(.trailing)
            Text(value)
                .textSelection(.enabled)
                .gridColumnAlignment(.leading)
        }
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
