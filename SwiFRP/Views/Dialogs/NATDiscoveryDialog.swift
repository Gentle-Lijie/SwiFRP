import SwiftUI

struct NATDiscoveryDialog: View {
    let stunServer: String
    @Binding var isPresented: Bool

    @State private var isDetecting = false
    @State private var natType: String = ""
    @State private var natBehavior: String = ""
    @State private var localAddress: String = ""
    @State private var externalAddresses: String = ""
    @State private var isPublic: String = ""
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            Text(String(localized: "nat.title"))
                .font(.headline)

            HStack {
                Text(String(localized: "nat.stunServer"))
                    .fontWeight(.medium)
                Text(stunServer.isEmpty ? Constants.defaultSTUNServer : stunServer)
                    .textSelection(.enabled)
            }

            if isDetecting {
                ProgressView(String(localized: "nat.detecting"))
                    .padding()
            }

            if !natType.isEmpty {
                Divider()

                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        Text(String(localized: "nat.natType"))
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Text(natType).textSelection(.enabled)
                    }
                    GridRow {
                        Text(String(localized: "nat.natBehavior"))
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Text(natBehavior).textSelection(.enabled)
                    }
                    GridRow {
                        Text(String(localized: "nat.localAddress"))
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Text(localAddress).textSelection(.enabled)
                    }
                    GridRow {
                        Text(String(localized: "nat.externalAddresses"))
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Text(externalAddresses).textSelection(.enabled)
                    }
                    GridRow {
                        Text(String(localized: "nat.isPublic"))
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Text(isPublic).textSelection(.enabled)
                    }
                }
                .padding(.horizontal)
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Divider()

            HStack {
                Button(String(localized: "nat.startDetection")) {
                    startDetection()
                }
                .disabled(isDetecting)

                Spacer()

                Button(String(localized: "common.close")) {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 440)
    }

    private func startDetection() {
        isDetecting = true
        errorMessage = nil
        natType = ""
        natBehavior = ""
        localAddress = ""
        externalAddresses = ""
        isPublic = ""

        let server = stunServer.isEmpty ? Constants.defaultSTUNServer : stunServer

        Task {
            do {
                let result = try await runNATDiscovery(stunServer: server)
                await MainActor.run {
                    natType = result.natType
                    natBehavior = result.natBehavior
                    localAddress = result.localAddress
                    externalAddresses = result.externalAddresses
                    isPublic = result.isPublic ? String(localized: "common.yes") : String(localized: "common.no")
                    isDetecting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isDetecting = false
                }
            }
        }
    }

    private func runNATDiscovery(stunServer: String) async throws -> NATResult {
        // Use frpc nathole discover command via Process
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let process = Process()
                    let pipe = Pipe()

                    // Try to locate frpc binary
                    if let bundlePath = Bundle.main.path(forResource: "frpc", ofType: nil) {
                        process.executableURL = URL(fileURLWithPath: bundlePath)
                    } else {
                        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/frpc")
                    }

                    process.arguments = ["nathole", "discover", "--nat_hole_stun_server", stunServer]
                    process.standardOutput = pipe
                    process.standardError = pipe

                    try process.run()
                    process.waitUntilExit()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""

                    let result = parseNATOutput(output)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func parseNATOutput(_ output: String) -> NATResult {
        var result = NATResult()
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("NAT type:") || trimmed.contains("nat_type:") {
                result.natType = extractValue(from: trimmed)
            } else if trimmed.contains("behavior:") || trimmed.contains("Behavior:") {
                result.natBehavior = extractValue(from: trimmed)
            } else if trimmed.contains("local_addr:") || trimmed.contains("Local address:") {
                result.localAddress = extractValue(from: trimmed)
            } else if trimmed.contains("external_addr:") || trimmed.contains("External address:") {
                result.externalAddresses = extractValue(from: trimmed)
            } else if trimmed.contains("public") {
                result.isPublic = trimmed.lowercased().contains("true") || trimmed.lowercased().contains("yes")
            }
        }

        if result.natType.isEmpty {
            result.natType = output.isEmpty
                ? String(localized: "nat.error.noOutput")
                : String(localized: "nat.error.parseFailed")
        }

        return result
    }

    private func extractValue(from line: String) -> String {
        if let colonIndex = line.lastIndex(of: ":") {
            return String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
        }
        return line
    }
}

private struct NATResult {
    var natType: String = ""
    var natBehavior: String = ""
    var localAddress: String = ""
    var externalAddresses: String = ""
    var isPublic: Bool = false
}
