import SwiftUI

struct VoiceSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ModelStore.self) private var modelStore
    @Environment(SpeechCoordinator.self) private var coordinator

    private static let samplePhrase = "MLXRead speaks selected text with a local model, entirely on this Mac."

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Picker("Model", selection: $settings.selectedModelID) {
                    ForEach(ModelManifest.all) { model in
                        Text("\(model.displayName) — \(model.summary)").tag(model.id)
                    }
                }
                .onChange(of: settings.selectedModelID) { _, newValue in
                    settings.selectedVoice = ModelManifest.model(withID: newValue)?.defaultVoice ?? ""
                    coordinator.refreshAvailability()
                }

                if settings.selectedModel.supportsVoices {
                    let voices = modelStore.availableVoices(for: settings.selectedModel)
                    if voices.isEmpty {
                        LabeledContent("Voice", value: "Download the model to list voices")
                    } else {
                        Picker("Voice", selection: $settings.selectedVoice) {
                            ForEach(voices, id: \.self) { Text($0).tag($0) }
                        }
                    }
                }
            }

            Section {
                LabeledContent("Speed") {
                    Slider(value: $settings.speechSpeed, in: 0.5...2.0, step: 0.05) {
                        Text("Speed")
                    } minimumValueLabel: {
                        Text("0.5×")
                    } maximumValueLabel: {
                        Text("2×")
                    }
                    .frame(width: 220)
                }
                LabeledContent("Current", value: String(format: "%.2f×", settings.speechSpeed))
            }

            Section {
                HStack {
                    Button("Play test phrase") {
                        coordinator.speakSample(Self.samplePhrase)
                    }
                    .disabled(coordinator.state.isBusy)
                    Button("Stop") {
                        coordinator.stop()
                    }
                    .disabled(!coordinator.state.isBusy)
                    Spacer()
                    Text(coordinator.state.displayName)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.bottom, 8)
    }
}
