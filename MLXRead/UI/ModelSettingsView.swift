import SwiftUI

struct ModelSettingsView: View {
    @Environment(ModelStore.self) private var modelStore
    @Environment(SpeechCoordinator.self) private var coordinator

    var body: some View {
        Form {
            ForEach(ModelManifest.all) { model in
                Section(model.displayName) {
                    modelRow(model)
                }
            }
            Section {
                LabeledContent("Total disk usage", value: format(bytes: modelStore.totalDiskUsageBytes()))
                Button("Reveal model directory in Finder") {
                    modelStore.revealInFinder()
                }
            }
        }
        .formStyle(.grouped)
        .padding(.bottom, 8)
        .onAppear { modelStore.refreshAllStates() }
    }

    @ViewBuilder
    private func modelRow(_ model: ModelInfo) -> some View {
        LabeledContent("Repository", value: model.id)
        LabeledContent("License", value: model.weightsLicense)
        switch modelStore.state(for: model) {
        case .notDownloaded:
            LabeledContent("Status", value: "Not downloaded (~\(model.approximateSizeMB) MB)")
            Button("Download") { modelStore.download(model) }
        case .downloading(let fraction):
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: max(0.0, min(1.0, fraction))) {
                    Text("Downloading… \(Int(fraction * 100))%")
                }
                Button("Cancel") { modelStore.cancelDownload(model) }
            }
        case .downloaded:
            LabeledContent("Status", value: "Downloaded")
            LabeledContent("Disk usage", value: format(bytes: modelStore.diskUsageBytes(for: model)))
            Button("Remove", role: .destructive) {
                try? modelStore.remove(model)
                coordinator.refreshAvailability()
            }
            .disabled(coordinator.state.isBusy)
        case .failed(let message):
            LabeledContent("Status", value: "Failed")
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
            Button("Retry") { modelStore.download(model) }
        }
    }

    private func format(bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
