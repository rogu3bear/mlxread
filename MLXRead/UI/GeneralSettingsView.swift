import SwiftUI

struct GeneralSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AppState.self) private var appState
    @Environment(AccessibilityPermissionService.self) private var permissions
    @Environment(UpdateService.self) private var updates

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                LabeledContent("Global shortcut") {
                    HStack(spacing: 6) {
                        Text(HotkeyConfiguration.optionEscape.displayString)
                            .font(.title3.monospaced())
                        Text(appState.hotkeyInstalled ? "active" : (permissions.isTrusted ? "not installed" : "needs Accessibility permission"))
                            .foregroundStyle(appState.hotkeyInstalled ? .green : .secondary)
                    }
                }
                Text("If macOS’s built-in “Speak selection” uses the same shortcut, disable or reassign it in System Settings → Accessibility → Spoken Content. MLXRead never changes that setting for you.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { appState.launchAtLoginEnabled },
                    set: { appState.setLaunchAtLogin($0) }
                ))
                Toggle("Clipboard fallback for apps without Accessibility text", isOn: $settings.clipboardFallbackEnabled)
                Toggle("Show floating playback controller", isOn: $settings.showPlaybackHUD)
                Toggle("Show selection preview in this window (kept off by default)", isOn: $settings.showSelectionPreview)
            }

            Section {
                LabeledContent("Maximum selection length") {
                    TextField(
                        "characters",
                        value: $settings.maximumSelectionLength,
                        format: .number
                    )
                    .frame(width: 100)
                    .multilineTextAlignment(.trailing)
                }
                Text("Longer selections are truncated at a word boundary and the truncation is reported in the menu.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if updates.isConfigured {
                Section("Updates") {
                    Toggle("Automatically check for updates", isOn: Binding(
                        get: { updates.automaticallyChecksForUpdates },
                        set: { updates.automaticallyChecksForUpdates = $0 }
                    ))
                    HStack {
                        Button("Check Now") { updates.checkForUpdates() }
                            .disabled(!updates.canCheckForUpdates)
                        Spacer()
                        Text("Updates are cryptographically signed (EdDSA) and verified before install.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button("Reset onboarding") {
                    settings.onboardingCompleted = false
                }
            }
        }
        .formStyle(.grouped)
        .padding(.bottom, 8)
    }
}
