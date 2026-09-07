import SwiftUI

struct VoiceSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ModelStore.self) private var modelStore
    @Environment(SpeechCoordinator.self) private var coordinator
    @State private var sampleText = VoiceOption(id: "af_heart").sampleText
    @State private var hasPreparedSample = false

    private var voice: VoiceOption {
        VoiceOption(id: settings.selectedModel.supportsVoices ? settings.selectedVoice : "af_heart")
    }

    private var voices: [VoiceOption] {
        modelStore.availableVoices(for: settings.selectedModel)
            .map { VoiceOption(id: $0) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Voice") {
                Picker("Speech model", selection: Binding(
                    get: { settings.selectedModelID },
                    set: { if let model = ModelManifest.model(withID: $0) { settings.selectModel(model) } }
                )) {
                    ForEach(ModelManifest.all) { model in
                        Text(model.displayName).tag(model.id)
                    }
                }
                Text(settings.selectedModel.summary)
                    .foregroundStyle(.secondary)

                if settings.selectedModel.supportsVoices, !voices.isEmpty {
                    Picker("Language", selection: Binding(
                        get: { voice.languageCode },
                        set: { language in
                            if let first = voices.first(where: { $0.languageCode == language }) {
                                settings.selectedVoice = first.id
                            }
                        }
                    )) {
                        ForEach(languageOptions) { option in
                            Text(option.languageName).tag(option.languageCode)
                        }
                    }
                    .help("Choose the language of the text you’ll be reading")
                    Picker("Voice", selection: $settings.selectedVoice) {
                        ForEach(voices.filter { $0.languageCode == voice.languageCode }) { option in
                            Text(option.name).tag(option.id)
                        }
                    }
                } else if !settings.selectedModel.supportsVoices {
                    LabeledContent("Language", value: "English")
                    Text("Soprano has one voice. Choose Kokoro for more voices and languages.")
                        .foregroundStyle(.secondary)
                }
                downloadStatus
            }
            .disabled(coordinator.state.isBusy)

            Section("Reading speed") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Slider(value: $settings.speechSpeed, in: 0.5...2.0, step: 0.05) {
                            Text("Reading speed")
                        } minimumValueLabel: {
                            Text("0.5×").font(.body)
                        } maximumValueLabel: {
                            Text("2×").font(.body)
                        }
                        .labelsHidden()
                        .accessibilityValue(String(format: "%g times normal speed", settings.speechSpeed))
                        Text(String(format: "%g×", settings.speechSpeed))
                            .monospacedDigit().frame(width: 48, alignment: .trailing)
                    }
                    HStack {
                        Button("Slower · 0.8×") { settings.speechSpeed = 0.8 }
                        Button("Normal · 1×") { settings.speechSpeed = 1.0 }
                        Button("Faster · 1.25×") { settings.speechSpeed = 1.25 }
                    }
                    Text(coordinator.state.isBusy
                         ? "Speed changes apply to your next reading."
                         : "Preview again to hear the new pace.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Listen and compare") {
                VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $sampleText)
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .frame(height: 88)
                    .accessibilityLabel("Voice preview text")
                    .disabled(coordinator.state.isBusy)

                HStack(spacing: 16) {
                    Button {
                        if coordinator.state.isBusy {
                            coordinator.stop()
                        } else {
                            coordinator.speakSample(sampleText)
                        }
                    } label: {
                        Label(coordinator.state.isBusy ? "Stop" : "Preview Voice",
                              systemImage: coordinator.state.isBusy ? "stop.fill" : "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!coordinator.state.isBusy &&
                              (modelStore.state(for: settings.selectedModel) != .downloaded ||
                               sampleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                    Button("Use sample text") { sampleText = voice.sampleText }
                        .disabled(coordinator.state.isBusy)
                    Spacer()
                }

                previewStatus
                Text("Preview text stays on this Mac and is not saved. The first preview in a language may download pronunciation files.")
                    .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            reconcileVoice()
            if !hasPreparedSample {
                sampleText = voice.sampleText
                hasPreparedSample = true
            }
        }
        .onChange(of: settings.selectedModelID) { _, _ in
            reconcileVoice()
            coordinator.refreshAvailability()
        }
        .onChange(of: voice.languageCode) { _, _ in sampleText = voice.sampleText }
        .onChange(of: modelStore.state(for: settings.selectedModel)) { _, _ in
            reconcileVoice()
            coordinator.refreshAvailability()
        }
    }

    private var languageOptions: [VoiceOption] {
        var seen = Set<String>()
        return voices.filter { seen.insert($0.languageCode).inserted }
            .sorted { $0.languageName.localizedStandardCompare($1.languageName) == .orderedAscending }
    }

    private func reconcileVoice() {
        guard settings.selectedModel.supportsVoices, !voices.isEmpty,
              !voices.contains(where: { $0.id == settings.selectedVoice }) else { return }
        settings.selectedVoice = voices.first(where: { $0.id == settings.selectedModel.defaultVoice })?.id
            ?? voices[0].id
    }

    @ViewBuilder
    private var downloadStatus: some View {
        let model = settings.selectedModel
        switch modelStore.state(for: model) {
        case .notDownloaded:
            Text("Download this model to hear its voices on your Mac.")
            Button("Download \(model.displayName) · about \(model.approximateSizeMB) MB") {
                modelStore.download(model)
            }
        case .downloading(let fraction):
            ProgressView(value: max(0, min(1, fraction))) {
                Text("Downloading · \(Int(max(0, min(1, fraction)) * 100))%")
            }
            Button("Cancel Download") { modelStore.cancelDownload(model) }
        case .failed(let message):
            Text("The model couldn’t be downloaded. Check your connection and try again.")
            DisclosureGroup("Download details") { Text(message).textSelection(.enabled) }
            Button("Retry Download") { modelStore.download(model) }
        case .downloaded:
            EmptyView()
        }
    }

    @ViewBuilder
    private var previewStatus: some View {
        if coordinator.state.isBusy {
            HStack(spacing: 8) {
                if coordinator.state != .playing {
                    ProgressView().controlSize(.small)
                }
                Text(coordinator.state.displayName)
            }
        } else if case .failed(let error) = coordinator.state {
            Label(error.errorDescription ?? "Couldn’t play the preview. Try again.",
                  systemImage: "exclamationmark.triangle")
                .fixedSize(horizontal: false, vertical: true)
        } else if sampleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text("Enter a passage or use the sample text to preview this voice.")
        } else if modelStore.state(for: settings.selectedModel) == .downloaded {
            Text("Ready to preview. Use Option–Escape to read text selected in another app.")
        }
    }
}
