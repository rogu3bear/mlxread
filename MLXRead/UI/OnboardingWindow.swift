import AppKit
import SwiftUI

struct OnboardingView: View {
    @Environment(SelectionAccessService.self) private var access
    @Environment(AppSettings.self) private var settings
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
                    Text("Select text. Press Option–Escape. Listen.")
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Label {
                    Text("Allow **Accessibility** access so MLXRead can read selected text and respond to Option–Escape. Your reading text stays on this Mac.")
                } icon: {
                    Image(systemName: access.isTrusted ? "checkmark.circle.fill" : "1.circle")
                        .foregroundStyle(access.isTrusted ? .green : .primary)
                }

                Label {
                    Text("If macOS **Speak Selection** also uses Option–Escape, change its shortcut in System Settings → Accessibility → Spoken Content.")
                } icon: {
                    Image(systemName: "2.circle")
                }

                Label {
                    Text("Open **Voice settings**, download a model, and preview a voice. The first preview prepares pronunciation files for that language; later readings can work offline.")
                } icon: {
                    Image(systemName: "3.circle")
                }
            }
            .font(.body)
            .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack {
                if access.isTrusted {
                    Label("Accessibility granted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Grant Accessibility Access…") {
                        access.requestAccess()
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
                Button("Close Setup", action: finishSetup)
                .keyboardShortcut(.defaultAction)
            }
            SettingsLink { Text("Open Settings…") }
        }
        .padding(24)
        .frame(width: 560)
        .onChange(of: access.isTrusted) { _, granted in
            if granted { finishSetup() }
        }
    }

    private func finishSetup() {
        settings.onboardingCompleted = true
        dismiss()
    }
}

@MainActor
final class OnboardingWindowController {
    private let access: SelectionAccessService
    private let settings: AppSettings
    private var window: NSWindow?

    init(access: SelectionAccessService, settings: AppSettings) {
        self.access = access
        self.settings = settings
    }

    func show() {
        if window == nil {
            let view = OnboardingView { [weak self] in
                self?.window?.close()
            }
            .environment(access)
            .environment(settings)

            // Automatic SwiftUI window sizing must stay OFF here: on this
            // macOS build, the hosting view's window-resize during ordering
            // (`setFrameSize` → safe-area invalidation) lands inside the
            // display cycle and AppKit aborts the process with
            // "_postWindowNeedsUpdateConstraints during display cycle".
            // Fixed content rect + sizingOptions = [] avoids that path.
            let hosting = NSHostingView(rootView: AnyView(view))
            hosting.sizingOptions = []
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 460),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "MLXRead Setup"
            window.isReleasedWhenClosed = false
            hosting.frame = NSRect(x: 0, y: 0, width: 560, height: 460)
            window.contentView = hosting
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
