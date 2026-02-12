import SwiftUI

struct AboutPageView: View {
    @EnvironmentObject var appState: AppState
    @State private var updateInfo: UpdateInfo? = nil
    @State private var isCheckingUpdate = false
    @State private var updateError: String? = nil

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "network")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)

            Text("SwiFRP")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(L("about.version \(Constants.appVersion)"))
                .font(.title3)

            Text(L("about.frpVersion \(Constants.frpVersion)"))
                .foregroundColor(.secondary)

            Text(L("about.buildDate \(Constants.buildDate)"))
                .foregroundColor(.secondary)
                .font(.caption)

            Divider()
                .frame(width: 300)

            // Update section
            if isCheckingUpdate {
                ProgressView(L("about.checkingUpdate"))
            } else if let info = updateInfo {
                VStack(spacing: 8) {
                    Text(L("about.newVersion \(info.version)"))
                        .foregroundColor(.green)
                        .fontWeight(.medium)

                    Link(L("about.downloadUpdate"), destination: info.downloadURL)
                        .buttonStyle(.borderedProminent)
                }
            } else {
                Button(L("about.checkForUpdate")) {
                    checkForUpdate()
                }
            }

            if let error = updateError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Divider()
                .frame(width: 300)

            HStack(spacing: 24) {
                if let projectURL = URL(string: "https://github.com/koho/SwiFRP") {
                    Link(L("about.projectURL"), destination: projectURL)
                }
                if let frpDocsURL = URL(string: "https://gofrp.org/docs/") {
                    Link(L("about.frpDocs"), destination: frpDocsURL)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func checkForUpdate() {
        isCheckingUpdate = true
        updateError = nil

        Task {
            do {
                let info = try await UpdateChecker.shared.checkForUpdate()
                await MainActor.run {
                    isCheckingUpdate = false
                    if let info = info {
                        updateInfo = info
                        appState.hasNewVersion = true
                    } else {
                        updateError = L("about.upToDate")
                    }
                }
            } catch {
                await MainActor.run {
                    isCheckingUpdate = false
                    updateError = error.localizedDescription
                }
            }
        }
    }
}
