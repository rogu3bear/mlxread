import SwiftUI

struct GeneralSettingsView: View {
    var showSetup: () -> Void
    @Environment(AppSettings.self) private var settings
    @Environment(AppState.self) private var appState
    @Environment(UpdateService.self) private var updates

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Read selected text") {
                LabeledContent("Keyboard shortcut") {
                    Text("⌥ Esc · Option–Escape").font(.body.weight(.medium))
                }
                Label(appState.selectionAccess.shortcutActive ? "Shortcut ready" : "Shortcut unavailable",
                      systemImage: appState.selectionAccess.shortcutActive ? "checkmark.circle" : "exclamationmark.triangle")
                Text("Select text in another app, then press Option–Escape to start reading. Press it again to stop.")
                Text("If macOS Speak Selection uses the same shortcut, change it in System Settings → Accessibility → Spoken Content.")
                    .foregroundStyle(.secondary)
                Button("Show Setup…", action: showSetup)
            }

            Section("Everyday use") {
                Toggle("Start MLXRead at login", isOn: Binding(
                    get: { appState.launchAtLoginEnabled },
                    set: { appState.setLaunchAtLogin($0) }
                ))
                Text("Keep the reading shortcut available whenever you use your Mac.")
                    .foregroundStyle(.secondary)
                Toggle("Show playback controls while reading", isOn: $settings.showPlaybackHUD)
                Text("A small floating panel shows progress and a Stop button.")
                    .foregroundStyle(.secondary)
            }

            Section("Selection capture") {
                Toggle("Use Copy when an app can’t share its selection", isOn: $settings.clipboardFallbackEnabled)
                Text("MLXRead briefly copies the selection, then restores your clipboard if nothing else has changed it.")
                    .foregroundStyle(.secondary)
                LabeledContent("Selection limit") {
                    HStack {
                        TextField("Characters", value: $settings.maximumSelectionLength, format: .number)
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 110)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("Maximum selection length in characters")
                        Text("characters")
                    }
                }
                Text("Between 500 and 100,000 characters. Longer selections stop at a word boundary; the menu tells you when text was shortened.")
                    .foregroundStyle(.secondary)
            }

            if updates.isConfigured {
                Section("Updates") {
                    Toggle("Automatically check for updates", isOn: Binding(
                        get: { updates.automaticallyChecksForUpdates },
                        set: { updates.automaticallyChecksForUpdates = $0 }
                    ))
                    Button("Check for Updates…") { updates.checkForUpdates() }
                        .disabled(!updates.canCheckForUpdates)
                    Text("Updates are signed and verified before installation.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}
