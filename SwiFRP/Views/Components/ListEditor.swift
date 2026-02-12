import SwiftUI

struct ListEditor: View {
    let title: String
    @Binding var items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !title.isEmpty {
                Text(title)
                    .font(.headline)
            }

            ForEach(items.indices, id: \.self) { index in
                HStack {
                    TextField("", text: $items[index])
                        .textFieldStyle(.roundedBorder)

                    Button {
                        items.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                }
            }

            Button {
                items.append("")
            } label: {
                Label(L("common.add"), systemImage: "plus")
            }
        }
    }
}
