import SwiftUI

struct PropertiesDialog: View {
    let config: ClientConfig
    @Binding var isPresented: Bool
    @ObservedObject var statusTracker: StatusTracker = .shared

    var body: some View {
        VStack(spacing: 0) {
            Text(L("properties.title"))
                .font(.headline)
                .padding()

            ScrollView {
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 8) {
                    propertyRow(L("properties.configName"), config.name)
                    propertyRow(L("properties.identifier"), LaunchdManager.shared.serviceLabel(for: config.name))
                    propertyRow(L("properties.serviceName"), LaunchdManager.shared.serviceLabel(for: config.name))
                    propertyRow(L("properties.fileFormat"), config.legacyFormat ? "INI" : "TOML")
                    propertyRow(L("properties.serverAddr"), config.serverAddr)
                    propertyRow(L("properties.serverPort"), "\(config.serverPort)")
                    propertyRow(L("properties.protocol"), config.protocol)
                    propertyRow(L("properties.proxyCount"), "\(config.proxies.count)")
                    propertyRow(L("properties.startupMode"), config.manualStart
                        ? L("properties.manual")
                        : L("properties.automatic"))

                    let logFiles = FileUtils.logFilesForConfig(name: config.name)
                    propertyRow(L("properties.logFiles"), "\(logFiles.count)")
                    propertyRow(L("properties.logSize"), StringUtils.formatBytes(FileUtils.totalLogSize(name: config.name)))

                    if let state = statusTracker.configStates[config.name], state == .started {
                        if let proxies = statusTracker.proxyStatuses[config.name] {
                            let tcpCount = proxies.filter { $0.type == "tcp" }.count
                            let udpCount = proxies.filter { $0.type == "udp" }.count
                            propertyRow(L("properties.tcpConnections"), "\(tcpCount)")
                            propertyRow(L("properties.udpConnections"), "\(udpCount)")
                        }
                    }

                    let configURL = ConfigFileManager.shared.configFileURL(for: config.name)
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: configURL.path) {
                        if let created = attrs[.creationDate] as? Date {
                            propertyRow(L("properties.fileCreated"), dateString(created))
                        }
                        if let modified = attrs[.modificationDate] as? Date {
                            propertyRow(L("properties.fileModified"), dateString(modified))
                        }
                    }
                }
                .padding()
            }
            .frame(maxHeight: 400)

            Divider()

            HStack {
                Spacer()
                Button(L("common.close")) {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 480)
    }

    @ViewBuilder
    private func propertyRow(_ label: String, _ value: String) -> some View {
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
