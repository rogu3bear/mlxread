import SwiftUI

struct PermissionView: View {
    @Environment(AccessibilityPermissionService.self) private var permissions
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section("Accessibility") {
                LabeledContent("Permission") {
                    Label(
                        permissions.isTrusted ? "Granted" : "Not granted",
                        systemImage: permissions.isTrusted ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                }

                // Trust and "tap actually installed" are distinct: the app
                // can be trusted yet fail to install the tap (rare), and the
                // user should see the true operational state.
                LabeledContent("Global shortcut ⌥⎋") {
                    Label(
                        shortcutStatus.text,
                        systemImage: shortcutStatus.symbol
                    )
                }

                Text("Allow MLXRead to read selected text in other apps and respond to Option–Escape. Your reading text stays on this Mac.")

                if !permissions.isTrusted {
                    Text("You can turn access off in System Settings at any time. MLXRead then stops reading and disables its shortcut.")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    if !permissions.isTrusted {
                        Button("Grant Access…") { permissions.requestAccess() }
                            .buttonStyle(.borderedProminent)
                    }
                    Button("Open Accessibility Settings") { permissions.openSystemSettings() }
                    Button("Recheck") {
                        permissions.refresh()
                        appState.installHotkeyIfPossible()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(.bottom, 8)
    }

    private var shortcutStatus: (text: String, symbol: String) {
        if !permissions.isTrusted {
            return ("Needs Accessibility access", "xmark.circle.fill")
        }
        if appState.hotkeyInstalled {
            return ("Active", "checkmark.circle.fill")
        }
        return ("Not active — click Recheck", "exclamationmark.triangle.fill")
    }
}
