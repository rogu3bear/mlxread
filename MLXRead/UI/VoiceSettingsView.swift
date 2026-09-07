import SwiftUI

struct VoiceSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ModelStore.self) private var modelStore
    @Environment(SpeechCoordinator.self) private var coordinator
    @State private var sampleText = VoiceOption.sampleText(language: "en-US")
    @State private var search = ""
    @State private var englishOnly = true
    @State private var hasPreparedSample = false

    private var model: ModelInfo { settings.selectedModel }
    private var language: String { settings.speechConfiguration.language ?? "en-US" }
    private var samplePassage: String { VoiceOption.sampleText(language: language) }
    private var sampleIsEmpty: Bool { sampleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private var voices: [VoiceOption] {
        guard modelStore.state(for: model) == .downloaded else { return [] }
        if !model.supportsVoices {
            return [VoiceOption(id: "default", displayName: "Default English voice", fixedLanguage: "en-US")]
        }
        return modelStore.availableVoices(for: model).map { model.voiceOption($0) }.sorted {
            let leftEnglish = $0.languageCode.hasPrefix("en")
            let rightEnglish = $1.languageCode.hasPrefix("en")
            if leftEnglish != rightEnglish { return leftEnglish }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private var visibleVoices: [VoiceOption] {
        voices.filter { voice in
            (!englishOnly || model.supportsIndependentLanguage || voice.languageCode.hasPrefix("en")) &&
                (search.isEmpty || voice.menuLabel.localizedStandardContains(search))
        }
    }

    private var availability: SpeechState? {
        modelStore.availability(for: model, voice: settings.speechConfiguration.voice, language: language)
    }

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Reading voice") {
                Picker("Speech engine", selection: Binding(
                    get: { settings.selectedModelID },
                    set: { if let model = ModelManifest.model(withID: $0) { settings.selectModel(model) } }
                )) {
                    ForEach(ModelManifest.all) { Text($0.displayName).tag($0.id) }
                }
                .disabled(coordinator.state.isBusy)
                Text(model.summary).fixedSize(horizontal: false, vertical: true)
                if model.supportsIndependentLanguage {
                    Picker("Reading language", selection: $settings.selectedLanguage) {
                        ForEach(model.languages, id: \.self) { Text(VoiceOption.languageName($0)).tag($0) }
                    }
                    .disabled(coordinator.state.isBusy)
                    Picker("Delivery", selection: $settings.speechDelivery) {
                        ForEach(SpeechDelivery.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    Text("Choose the language of your text and a speaking style.")
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                } else {
                    LabeledContent("Reading language", value: VoiceOption.languageName(language))
                }
                LabeledContent("Selected voice", value: model.supportsVoices ? model.voiceOption(settings.selectedVoice).name : "Default English voice")
                if availability == .voiceRequired {
                    Label("Choose an available voice that supports the reading language below.", systemImage: "exclamationmark.triangle")
                        .fixedSize(horizontal: false, vertical: true)
                }
                downloadStatus
            }

            Section(model.supportsVoices ? "Compare voices" : "Preview") {
                DisclosureGroup("Preview passage and speed") {
                    TextEditor(text: $sampleText)
                        .font(.body).lineSpacing(3).frame(height: 64)
                        .accessibilityLabel("Voice preview text")
                        .disabled(coordinator.state.isBusy)
                    Button("Use sample text") { sampleText = samplePassage }
                        .disabled(coordinator.state.isBusy)
                    HStack {
                        Slider(value: $settings.speechSpeed, in: 0.5...2, step: 0.05) { Text("Reading speed") }
                            .accessibilityValue(String(format: "%g times normal speed", settings.speechSpeed))
                            .help("0.5× to 2× normal speed")
                        Text(String(format: "%g×", settings.speechSpeed)).monospacedDigit().frame(width: 40)
                        Button("Reset speed") { settings.speechSpeed = 1 }
                    }
                }
                if coordinator.state.isBusy {
                    HStack {
                        Text(coordinator.state.displayName)
                        Spacer()
                        Button("Stop preview") { coordinator.stop() }
                    }
                } else if case .failed(let error) = coordinator.state {
                    Label(error.errorDescription ?? "Couldn’t play the preview. Try again.", systemImage: "exclamationmark.triangle")
                        .fixedSize(horizontal: false, vertical: true)
                } else if sampleIsEmpty {
                    Text("Enter a passage or use the sample text to compare voices.")
                }
                Text(model.supportsVoices
                     ? "Preview stays on this Mac and does not change your selected voice. Choose Use to keep a voice for reading."
                     : "Listen to the sample passage or try your own text. Previews stay on this Mac.")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }

            if !voices.isEmpty {
                Section(voices.count == 1 ? "Voice preview" : "Voice previews · \(voices.count) available") {
                    if voices.count > 1 {
                        TextField("Find a voice", text: $search)
                        if !model.supportsIndependentLanguage && model.languages.count > 1 {
                            Picker("Show", selection: $englishOnly) {
                                Text("English voices").tag(true)
                                Text("All languages").tag(false)
                            }.pickerStyle(.segmented)
                        }
                    }
                    ForEach(visibleVoices) { voice in voiceRow(voice) }
                    if visibleVoices.isEmpty { Text("No matching voices. Clear the search or show all languages.") }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if !hasPreparedSample { sampleText = samplePassage; hasPreparedSample = true }
        }
        .onChange(of: settings.selectedModelID) { _, _ in
            search = ""
            coordinator.refreshAvailability(clearFailure: true)
        }
        .onChange(of: language) { _, _ in
            sampleText = samplePassage
            coordinator.refreshAvailability(clearFailure: true)
        }
        .onChange(of: settings.selectedVoice) { _, _ in coordinator.refreshAvailability(clearFailure: true) }
    }

    private func voiceRow(_ voice: VoiceOption) -> some View {
        let usable = model.canRead(voice: voice.id, language: language)
        let previewLanguage = model.supportsIndependentLanguage && usable ? language : voice.languageCode
        let selected = !model.supportsVoices || voice.id == settings.selectedVoice
        let active = coordinator.state.isBusy && (coordinator.activeConfiguration?.voice ?? "default") == voice.id
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(voice.name).fontWeight(.medium)
                Text(voice.languageName + (model.supportsIndependentLanguage ? " native voice" : ""))
                    .foregroundStyle(.secondary)
                if !usable {
                    Text("Chinese dialect only in this engine. Preview uses Chinese.")
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            Button(active ? "Stop" : "Preview") {
                if active { coordinator.stop() }
                else {
                    let configuration = SpeechConfiguration(
                        voice: model.supportsVoices ? voice.id : nil, speed: settings.speechSpeed,
                        language: previewLanguage, delivery: settings.speechDelivery
                    )
                    let passage = previewLanguage == language ? sampleText : VoiceOption.sampleText(language: previewLanguage)
                    coordinator.speakSample(passage, configuration: configuration)
                }
            }
            .disabled(sampleIsEmpty || (coordinator.state.isBusy && !active))
            .accessibilityLabel("\(active ? "Stop" : "Preview") \(voice.name) in \(VoiceOption.languageName(previewLanguage))")
            .accessibilityIdentifier("preview-\(voice.id)")
            if selected { Text("Selected").frame(width: 66) }
            else {
                Button("Use") { settings.selectedVoice = voice.id }
                    .disabled(coordinator.state.isBusy || !usable)
                    .accessibilityLabel("Use \(voice.name) for reading")
                    .frame(width: 66)
            }
        }
        .padding(.vertical, 5)
    }

    @ViewBuilder
    private var downloadStatus: some View {
        switch modelStore.state(for: model) {
        case .notDownloaded:
            Button("Download voices · \(model.downloadSize)") { modelStore.download(model) }
        case .downloading(let fraction):
            ProgressView(value: fraction) { Text("Downloading · \(Int(fraction * 100))%") }
            Button("Cancel Download") { modelStore.cancelDownload(model) }
        case .checking, .cancelling, .deleting:
            ProgressView(modelStore.state(for: model).label)
        case .incomplete, .failed:
            Text("The model download is incomplete. Retry here or delete it in Models.")
            if case .failed(let message) = modelStore.state(for: model) {
                DisclosureGroup("Download details") { Text(message).textSelection(.enabled) }
            }
            Button("Retry Download") { modelStore.download(model) }
        case .downloaded: EmptyView()
        }
    }
}
