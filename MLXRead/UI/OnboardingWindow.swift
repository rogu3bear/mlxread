import AppKit
import SwiftUI

struct OnboardingView: View {
    @Environment(AccessibilityPermissionService.self) private var permissions
    @Environment(AppSettings.self) private var settings
    @Environment(AppState.self) private var appState
    var dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading) {
                    Text("Welcome to MLXRead")
                        .font(.title2.bold())
                    Text("Press ⌥⎋ to hear any selected text, spoken by a local model.")
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Label {
                    Text("MLXRead needs **Accessibility** access to read the current selection and to listen for Option–Escape. Nothing is sent off this Mac.")
                } icon: {
                    Image(systemName: permissions.isTrusted ? "checkmark.circle.fill" : "1.circle")
                        .foregroundStyle(permissions.isTrusted ? .green : .primary)
                }

                Label {
                    Text("If Apple’s built-in **Speak selection** is enabled with the same shortcut, disable or reassign it under System Settings → Accessibility → Spoken Content. MLXRead won’t change it for you.")
                } icon: {
                    Image(systemName: "2.circle")
                }

                Label {
                    Text("Download a voice model once in Settings → Models. After that, MLXRead works fully offline.")
                } icon: {
                    Image(systemName: "3.circle")
                }
            }
            .font(.callout)

            Divider()

            HStack {
                if permissions.isTrusted {
                    Label("Accessibility granted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Grant Accessibility Access…") {
                        permissions.requestAccess()
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
                Button("Done") {
                    settings.onboardingCompleted = true
                    appState.installHotkeyIfPossible()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}

@MainActor
final class OnboardingWindowController {
    private let appState: AppState
    private var window: NSWindow?

    init(appState: AppState) {
        self.appState = appState
    }

    func show() {
        if window == nil {
            let view = OnboardingView { [weak self] in
                self?.window?.close()
            }
            .environment(appState.permissions)
            .environment(appState.settings)
            .environment(appState)

            // Automatic SwiftUI window sizing must stay OFF here: on this
            // macOS build, the hosting view's window-resize during ordering
            // (`setFrameSize` → safe-area invalidation) lands inside the
            // display cycle and AppKit aborts the process with
            // "_postWindowNeedsUpdateConstraints during display cycle".
            // Fixed content rect + sizingOptions = [] avoids that path.
            let hosting = NSHostingView(rootView: AnyView(view))
            hosting.sizingOptions = []
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 440),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "MLXRead Setup"
            window.isReleasedWhenClosed = false
            hosting.frame = NSRect(x: 0, y: 0, width: 480, height: 440)
            window.contentView = hosting
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
