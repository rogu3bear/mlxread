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
                Text("Last selection was truncated to the length limit")
            }

            Divider()

            Button("Read Selection") {
                coordinator.beginReadingSelection()
            }
            .keyboardShortcut("r")
            .disabled(coordinator.state.isBusy)

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

            if settings.selectedModel.supportsVoices {
                let voices = modelStore.availableVoices(for: settings.selectedModel)
                if !voices.isEmpty {
                    Picker("Voice", selection: voiceBinding) {
                        ForEach(voices, id: \.self) { voice in
                            Text(voice).tag(voice)
                        }
                    }
                }
            }

            Picker("Speed", selection: speedBinding) {
                ForEach([0.8, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                    Text(String(format: "%g×", speed)).tag(speed)
                }
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
        var line = coordinator.state.displayName
        if case .downloading(let fraction) = modelStore.state(for: settings.selectedModel) {
            line += " — downloading \(Int(fraction * 100))%"
        }
        return line
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: { settings.selectedModelID },
            set: { newValue in
                settings.selectedModelID = newValue
                if let model = ModelManifest.model(withID: newValue) {
                    settings.selectedVoice = model.defaultVoice ?? ""
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
