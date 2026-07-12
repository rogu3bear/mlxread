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
                    .foregroundStyle(permissions.isTrusted ? .green : .red)
                }

                // Trust and "tap actually installed" are distinct: the app
                // can be trusted yet fail to install the tap (rare), and the
                // user should see the true operational state.
                LabeledContent("Global shortcut ⌥⎋") {
                    Label(
                        shortcutStatus.text,
                        systemImage: shortcutStatus.symbol
                    )
                    .foregroundStyle(shortcutStatus.color)
                }

                Text("MLXRead reads the frontmost app's selected text through the macOS Accessibility API, and its Option–Escape shortcut is a keyboard event tap. Both require Accessibility access. Selected text never leaves this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !permissions.isTrusted {
                    Text("If you revoke access later, MLXRead removes its keyboard tap immediately and stops any active reading.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    if !permissions.isTrusted {
                        Button("Grant Access…") { permissions.requestAccess() }
                            .buttonStyle(.borderedProminent)
                    }
                    Button("Open System Settings") { permissions.openSystemSettings() }
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

    private var shortcutStatus: (text: String, symbol: String, color: Color) {
        if !permissions.isTrusted {
            return ("Needs Accessibility access", "xmark.circle.fill", .red)
        }
        if appState.hotkeyInstalled {
            return ("Active", "checkmark.circle.fill", .green)
        }
        return ("Not installed — click Recheck", "exclamationmark.triangle.fill", .orange)
    }
}
