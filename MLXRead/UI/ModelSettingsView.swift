import SwiftUI

struct ModelSettingsView: View {
    @Environment(ModelStore.self) private var modelStore
    @Environment(SpeechCoordinator.self) private var coordinator
    @Environment(AppSettings.self) private var settings
    @State private var removalError: String?

    var body: some View {
        Form {
            Section {
                Text("Choose how your reading sounds").font(.title2.weight(.semibold))
                Text("Download a model, then preview its voice. Downloads stay on this Mac and can be deleted at any time.")
                    .fixedSize(horizontal: false, vertical: true)
                LabeledContent("Downloaded", value: "\(downloadedCount) of \(ModelManifest.all.count) models")
            }
            ForEach(ModelManifest.all) { model in
                Section(model.displayName) {
                    modelRow(model)
                }
            }
            Section("Storage") {
                LabeledContent("Total disk usage", value: format(bytes: modelStore.totalDiskUsageBytes()))
                HStack {
                    Button("Refresh Status") { modelStore.refreshAllStates() }
                    Button("Show Files in Finder") { modelStore.revealInFinder() }
                }
                if let removalError {
                    Label(removalError, systemImage: "exclamationmark.triangle")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.bottom, 8)
        .onAppear { modelStore.refreshAllStates() }
    }

    private var downloadedCount: Int {
        ModelManifest.all.filter { modelStore.state(for: $0) == .downloaded }.count
    }

    @ViewBuilder
    private func modelRow(_ model: ModelInfo) -> some View {
        let state = modelStore.state(for: model)
        let selected = settings.selectedModelID == model.id
        VStack(alignment: .leading, spacing: 10) {
            Text(model.summary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Label(status(for: model), systemImage: statusIcon(state))
                Spacer()
                if selected { Text("Selected").fontWeight(.medium) }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("model-status-\(model.id)")

            switch state {
            case .notDownloaded:
                Button("Download · \(model.downloadSize)") { modelStore.download(model) }
                    .accessibilityLabel("Download \(model.displayName), about \(model.downloadSize)")
            case .downloading(let fraction):
                ProgressView(value: fraction) {
                    Text("Downloading · \(Int(fraction * 100))%")
                        .monospacedDigit()
                }
                HStack(spacing: 16) {
                    Button("Cancel") { modelStore.cancelDownload(model) }
                    deleteButton(model)
                }
            case .checking, .cancelling, .deleting:
                ProgressView().controlSize(.small)
            case .downloaded:
                Text("On disk · \(format(bytes: modelStore.diskUsageBytes(for: model)))")
                    .foregroundStyle(.secondary)
                HStack(spacing: 16) {
                    if !selected {
                        Button("Use Model") {
                            settings.selectModel(model)
                            coordinator.refreshAvailability(clearFailure: true)
                        }
                        .disabled(coordinator.state.isBusy)
                    }
                    Button(selected && coordinator.state.isBusy ? "Stop" : "Preview") {
                        if selected && coordinator.state.isBusy {
                            coordinator.stop()
                        } else {
                            settings.selectModel(model)
                            coordinator.refreshAvailability(clearFailure: true)
                            let language = settings.speechConfiguration.language ?? model.voiceOption(settings.selectedVoice).languageCode
                            coordinator.speakSample(VoiceOption.sampleText(language: language))
                        }
                    }
                    .disabled(coordinator.state.isBusy && !selected)
                    .accessibilityLabel("\(selected && coordinator.state.isBusy ? "Stop" : "Preview") \(model.displayName)")
                    deleteButton(model)
                }
            case .incomplete, .failed:
                Text("Some files are missing or the download did not finish. Retry to repair it, or delete the download.")
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 16) {
                    Button("Retry Download") { modelStore.download(model) }
                    deleteButton(model)
                }
                if case .failed(let message) = state {
                    DisclosureGroup("Error details") { Text(message).textSelection(.enabled) }
                }
            }
            DisclosureGroup("Model details") {
                LabeledContent("Download size", value: "About \(model.downloadSize)")
                LabeledContent("Source", value: model.id).textSelection(.enabled)
                LabeledContent("License", value: model.weightsLicense)
                Link("Model card and credits", destination: URL(string: "https://huggingface.co/\(model.id)")!)
                if model.id == ModelManifest.pocket.id {
                    Link("Voice credits", destination: URL(string: "https://huggingface.co/kyutai/tts-voices")!)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func deleteButton(_ model: ModelInfo) -> some View {
        Button("Delete", role: .destructive) {
            Task {
                do {
                    try await modelStore.remove(model)
                    removalError = nil
                } catch {
                    removalError = "Couldn’t delete \(model.displayName). \(error.localizedDescription)"
                }
            }
        }
        .disabled(settings.selectedModelID == model.id && coordinator.state.isBusy)
        .accessibilityLabel("Delete \(model.displayName) download")
        .help("Delete this model's downloaded files. You can download it again later.")
    }

    private func status(for model: ModelInfo) -> String {
        let state = modelStore.state(for: model)
        guard state == .downloaded else { return state.label }
        if settings.selectedModelID == model.id {
            if coordinator.state.isBusy { return coordinator.state.displayName }
            if case .failed = coordinator.state { return "Speech failed · retry Preview" }
            if modelStore.availability(for: model, voice: settings.speechConfiguration.voice,
                                       language: settings.speechConfiguration.language) == .voiceRequired {
                return "Choose a voice for this language in Voice settings"
            }
        }
        return "Ready to preview"
    }

    private func statusIcon(_ state: ModelDownloadState) -> String {
        switch state {
        case .downloaded: return "checkmark.circle"
        case .failed, .incomplete: return "exclamationmark.triangle"
        case .deleting: return "trash"
        default: return "arrow.down.circle"
        }
    }

    private func format(bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
