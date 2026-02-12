import SwiftUI

struct KeyValueEditor: View {
    let title: String
    @Binding var pairs: [String: String]

    @State private var entries: [KeyValueEntry] = []
    @State private var selectedID: UUID? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !title.isEmpty {
                Text(title)
                    .font(.headline)
            }

            Table(entries, selection: $selectedID) {
                TableColumn(L("keyvalue.key")) { entry in
                    TextField("", text: binding(for: entry.id, keyPath: \.key))
                        .textFieldStyle(.plain)
                }
                .width(min: 80, ideal: 140)

                TableColumn(L("keyvalue.value")) { entry in
                    TextField("", text: binding(for: entry.id, keyPath: \.value))
                        .textFieldStyle(.plain)
                }
                .width(min: 80, ideal: 200)
            }
            .frame(minHeight: 120)

            HStack {
                Button {
                    let entry = KeyValueEntry(key: "", value: "")
                    entries.append(entry)
                    syncToPairs()
                } label: {
                    Image(systemName: "plus")
                }

                Button {
                    if let id = selectedID {
                        entries.removeAll { $0.id == id }
                        selectedID = nil
                        syncToPairs()
                    }
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selectedID == nil)

                Spacer()

                Button(L("common.clearAll")) {
                    entries.removeAll()
                    syncToPairs()
                }
                .disabled(entries.isEmpty)
            }
        }
        .onAppear { loadFromPairs() }
        .onChange(of: pairs) { _ in
            if !isSynced() { loadFromPairs() }
        }
    }

    private func loadFromPairs() {
        entries = pairs.sorted(by: { $0.key < $1.key }).map {
            KeyValueEntry(key: $0.key, value: $0.value)
        }
    }

    private func syncToPairs() {
        var result: [String: String] = [:]
        for entry in entries where !entry.key.isEmpty {
            result[entry.key] = entry.value
        }
        pairs = result
    }

    private func isSynced() -> Bool {
        let current = entries.filter { !$0.key.isEmpty }
        guard current.count == pairs.count else { return false }
        for entry in current {
            if pairs[entry.key] != entry.value { return false }
        }
        return true
    }

    private func binding(for id: UUID, keyPath: WritableKeyPath<KeyValueEntry, String>) -> Binding<String> {
        Binding(
            get: {
                entries.first { $0.id == id }?[keyPath: keyPath] ?? ""
            },
            set: { newValue in
                if let index = entries.firstIndex(where: { $0.id == id }) {
                    entries[index][keyPath: keyPath] = newValue
                    syncToPairs()
                }
            }
        )
    }
}

struct KeyValueEntry: Identifiable {
    let id = UUID()
    var key: String
    var value: String
}
