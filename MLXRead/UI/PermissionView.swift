import SwiftUI

struct PermissionView: View {
    @Environment(AccessibilityPermissionService.self) private var permissions
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section("Accessibility") {
                LabeledContent("Status") {
                    Label(
                        permissions.isTrusted ? "Granted" : "Not granted",
                        systemImage: permissions.isTrusted ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                    .foregroundStyle(permissions.isTrusted ? .green : .red)
                }

                Text("MLXRead reads the selected text of the frontmost app through the macOS Accessibility API, and its Option–Escape shortcut is a keyboard event tap. Both require Accessibility access. The selected text never leaves this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Open System Settings") {
                        permissions.openSystemSettings()
                    }
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
}
