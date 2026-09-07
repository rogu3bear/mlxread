import SwiftUI

struct PermissionView: View {
    @Environment(SelectionAccessService.self) private var access

    var body: some View {
        Form {
            Section("Accessibility") {
                LabeledContent("Permission") {
                    Label(
                        access.isTrusted ? "Granted" : "Not granted",
                        systemImage: access.isTrusted ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                }

                LabeledContent("Global shortcut ⌥⎋") {
                    Label(
                        shortcutStatus.text,
                        systemImage: shortcutStatus.symbol
                    )
                }

                Text("Allow MLXRead to read selected text in other apps and respond to Option–Escape. Your reading text stays on this Mac.")

                if !access.isTrusted {
                    Text("Enable MLXRead in System Settings. Access is detected automatically.")
                    Text("You can turn access off in System Settings at any time. MLXRead then stops reading and disables its shortcut.")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    if !access.isTrusted {
                        Button("Grant Access…") { access.requestAccess() }
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button("Open Accessibility Settings") { access.openSystemSettings() }
                    }
                    if access.shortcutNeedsRetry {
                        Button("Retry Shortcut") { access.retryShortcut() }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(.bottom, 8)
    }

    private var shortcutStatus: (text: String, symbol: String) {
        if !access.isTrusted {
            return ("Needs Accessibility access", "xmark.circle.fill")
        }
        if access.shortcutActive {
            return ("Active", "checkmark.circle.fill")
        }
        return access.shortcutNeedsRetry
            ? ("Unavailable — retry below", "exclamationmark.triangle.fill")
            : ("Starting…", "clock")
    }
}
