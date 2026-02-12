import SwiftUI

struct URLImportDialog: View {
    @Binding var isPresented: Bool
    var onImport: ([ClientConfig]) -> Void

    @State private var urlText: String = ""
    @State private var statusMessage: String = ""
    @State private var isImporting = false
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            Text(L("urlImport.title"))
                .font(.headline)

            Text(L("urlImport.description"))
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: $urlText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 120)
                .border(Color.secondary.opacity(0.3))

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            if isImporting {
                ProgressView()
                    .scaleEffect(0.8)
            }

            Divider()

            HStack {
                Spacer()
                Button(L("common.cancel")) {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button(L("urlImport.import")) {
                    importURLs()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isImporting)
            }
        }
        .padding()
        .frame(width: 480, height: 300)
    }

    private func importURLs() {
        let urls = urlText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !urls.isEmpty else { return }

        isImporting = true
        errorMessage = nil
        statusMessage = ""

        Task {
            do {
                let configs = try await ImportExportManager.shared.importFromURLs(urls) { current, total in
                    DispatchQueue.main.async {
                        statusMessage = L("urlImport.downloading \(current) \(total)")
                    }
                }

                await MainActor.run {
                    isImporting = false
                    statusMessage = ""
                    onImport(configs)
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    statusMessage = ""
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
