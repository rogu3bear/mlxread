import SwiftUI

struct MenuBarContent: View {
    @Environment(SpeechCoordinator.self) private var coordinator
    @Environment(AppSettings.self) private var settings
    @Environment(ModelStore.self) private var modelStore
    @Environment(AccessibilityPermissionService.self) private var permissions
    @Environment(UpdateService.self) private var updates
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            Text(statusLine)

            if coordinator.lastReadWasTruncated {
                Text("Selection shortened to limit")
            }

            Divider()

            Button("Read Selection") {
                coordinator.beginReadingSelection()
            }
            .keyboardShortcut("r")
            .disabled(coordinator.state.isBusy || !permissions.isTrusted ||
                      modelStore.state(for: settings.selectedModel) != .downloaded)

            Button("Stop") {
                coordinator.stop()
            }
            .keyboardShortcut(".")
            .disabled(!coordinator.state.isBusy)

            Divider()

            Picker("Model", selection: modelBinding) {
                ForEach(ModelManifest.all) { model in
                    Text(model.displayName).tag(model.id)
                }
            }
            .disabled(coordinator.state.isBusy)

            if settings.selectedModel.supportsVoices {
                let voices = modelStore.availableVoices(for: settings.selectedModel)
                if !voices.isEmpty {
                    Picker("Voice", selection: voiceBinding) {
                        ForEach(voices, id: \.self) { voice in
                            Text(String(VoiceOption(id: voice).menuLabel.prefix(30))).tag(voice)
                        }
                    }
                    .disabled(coordinator.state.isBusy)
                }
            }

            Picker("Speed", selection: speedBinding) {
                ForEach(Array(Set([0.5, 0.8, 1.0, 1.25, 1.5, 2.0, settings.speechSpeed])).sorted(), id: \.self) { speed in
                    Text(String(format: "%g×", speed)).tag(speed)
                }
            }
            if coordinator.state.isBusy {
                Text("Speed applies to next reading")
            }

            Divider()

            SettingsLink {
                Text("Settings…")
            }
            .keyboardShortcut(",")

            if updates.isConfigured {
                Button("Check for Updates…") {
                    updates.checkForUpdates()
                }
                .disabled(!updates.canCheckForUpdates)
            }

            Toggle("Launch at Login", isOn: launchAtLoginBinding)

            Divider()

            Button("Quit MLXRead") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }

    private var statusLine: String {
        if case .downloading(let fraction) = modelStore.state(for: settings.selectedModel) {
            return "Downloading voice · \(Int(max(0, min(1, fraction)) * 100))%"
        }
        return coordinator.state.displayName
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: { settings.selectedModelID },
            set: { newValue in
                if let model = ModelManifest.model(withID: newValue) {
                    settings.selectModel(model)
                }
                coordinator.refreshAvailability()
            }
        )
    }

    private var voiceBinding: Binding<String> {
        Binding(
            get: { settings.selectedVoice },
            set: { settings.selectedVoice = $0 }
        )
    }

    private var speedBinding: Binding<Double> {
        Binding(
            get: { settings.speechSpeed },
            set: { settings.speechSpeed = $0 }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { appState.launchAtLoginEnabled },
            set: { appState.setLaunchAtLogin($0) }
        )
    }
}
