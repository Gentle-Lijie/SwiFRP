import SwiftUI

struct BrowseField: View {
    let label: String
    @Binding var path: String
    var allowedTypes: [String] = []
    var canChooseDirectories: Bool = false

    var body: some View {
        HStack {
            TextField(label, text: $path)
                .textFieldStyle(.roundedBorder)

            Button(L("common.browse")) {
                browseFile()
            }
        }
    }

    private func browseFile() {
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        panel.canChooseFiles = !canChooseDirectories
        panel.canChooseDirectories = canChooseDirectories
        panel.allowsMultipleSelection = false
        panel.title = label

        if !allowedTypes.isEmpty {
            panel.allowedContentTypes = allowedTypes.compactMap {
                UTType(filenameExtension: $0)
            }
        }

        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
        #endif
    }
}

#if canImport(AppKit)
import UniformTypeIdentifiers
#endif
