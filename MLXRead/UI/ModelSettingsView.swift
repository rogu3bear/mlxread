import SwiftUI

struct ModelSettingsView: View {
    @Environment(ModelStore.self) private var modelStore
    @Environment(SpeechCoordinator.self) private var coordinator
    @Environment(AppSettings.self) private var settings
    @State private var removalError: String?

    var body: some View {
        Form {
            Section {
                Text("Voices that stay on your Mac").font(.title2.weight(.semibold))
                Text("Download a model to add local speech. One model is enough to get started.")
            }
            ForEach(ModelManifest.all) { model in
                Section(model.displayName) {
                    modelRow(model)
                }
            }
            Section {
                LabeledContent("Total disk usage", value: format(bytes: modelStore.totalDiskUsageBytes()))
                Button("Show Downloaded Files in Finder") {
                    modelStore.revealInFinder()
                }
                if let removalError {
                    Text(removalError).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.bottom, 8)
        .onAppear { modelStore.refreshAllStates() }
    }

    @ViewBuilder
    private func modelRow(_ model: ModelInfo) -> some View {
        Text(model.summary)
        if settings.selectedModelID == model.id {
            Label("Selected for reading", systemImage: "checkmark.circle")
        }
        switch modelStore.state(for: model) {
        case .notDownloaded:
            Text("Download size: about \(model.approximateSizeMB) MB")
                .foregroundStyle(.secondary)
            Button("Download \(model.displayName)") { modelStore.download(model) }
        case .downloading(let fraction):
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: max(0.0, min(1.0, fraction))) {
                    Text("Downloading… \(Int(fraction * 100))%")
                }
                Button("Cancel Download") { modelStore.cancelDownload(model) }
            }
        case .downloaded:
            if settings.selectedModelID == model.id,
               modelStore.availability(for: model, voice: settings.speechConfiguration.voice) == .voiceRequired {
                Label("Saved voice unavailable", systemImage: "exclamationmark.triangle")
                Text("Choose another available voice in Voice settings.")
            } else {
                Label("Ready to use", systemImage: "checkmark.circle")
            }
            LabeledContent("Disk usage", value: format(bytes: modelStore.diskUsageBytes(for: model)))
            HStack(spacing: 16) {
                if settings.selectedModelID != model.id {
                    Button("Use for Reading") {
                        settings.selectModel(model)
                        coordinator.refreshAvailability(clearFailure: true)
                    }
                }
                Button("Move to Trash", role: .destructive) {
                    do {
                        try modelStore.remove(model, movingToTrash: true)
                        removalError = nil
                        coordinator.refreshAvailability()
                    } catch {
                        removalError = "Couldn’t remove \(model.displayName). \(error.localizedDescription)"
                    }
                }
            }
            .disabled(coordinator.state.isBusy)
            Text("Restore the folder from Trash or download it again to use this model later.")
                .foregroundStyle(.secondary)
        case .failed(let message):
            Text("Download didn’t finish. Check your connection and try again.")
            DisclosureGroup("Download details") { Text(message).textSelection(.enabled) }
            Button("Retry Download") { modelStore.download(model) }
        }
        DisclosureGroup("Model details") {
            LabeledContent("Source", value: model.id)
                .textSelection(.enabled)
            LabeledContent("License", value: model.weightsLicense)
        }
    }

    private func format(bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
