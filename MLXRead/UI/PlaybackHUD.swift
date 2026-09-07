import AppKit
import SwiftUI

/// Compact floating playback controller. Optional, off by default.
/// Hosted in a non-activating panel so keyboard focus stays with the
/// foreground application.
struct PlaybackHUDView: View {
    @Environment(SpeechCoordinator.self) private var coordinator
    @Environment(AppSettings.self) private var settings
    var onClose: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: coordinator.state == .playing ? "waveform" : "hourglass")
                .symbolEffect(.variableColor.iterative, isActive: coordinator.state.isBusy)
                .accessibilityHidden(true)
            Text(coordinator.state.displayName)
                .font(.body)
                .lineLimit(1)
                .frame(width: 160, alignment: .leading)

            Button {
                coordinator.stop()
            } label: {
                Image(systemName: "stop.fill")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Stop reading")
            .help("Stop reading (Option–Escape)")
            .disabled(!coordinator.state.isBusy)

            Text(String(format: "%g×", coordinator.activeConfiguration?.speed ?? settings.speechSpeed))
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Hide playback controls")
            .help("Hide controls for this reading; speech continues")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

/// Shows the HUD panel while a read is active (when enabled in settings).
@MainActor
final class PlaybackHUDController {
    private let appState: AppState
    private var panel: NSPanel?
    private var observationTask: Task<Void, Never>?
    /// User dismissed the HUD for the current read; reappears next read.
    private var suppressedForCurrentRead = false

    init(appState: AppState) {
        self.appState = appState
        observe()
    }

    deinit {
        observationTask?.cancel()
    }

    private func observe() {
        observationTask = Task { [weak self] in
            // Poll the observable state at UI cadence; withObservationTracking
            // re-registration loops are easy to get subtly wrong for a
            // long-lived observer, and 5 Hz is imperceptible for a HUD.
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self else { return }
                self.update()
            }
        }
    }

    private func update() {
        let busy = appState.coordinator.state.isBusy
        let wanted = appState.settings.showPlaybackHUD && busy && !suppressedForCurrentRead
        if !busy {
            suppressedForCurrentRead = false
        }
        if wanted {
            showPanel()
        } else {
            hidePanel()
        }
    }

    private func showPanel() {
        if panel == nil {
            let content = PlaybackHUDView { [weak self] in
                self?.suppressedForCurrentRead = true
                self?.hidePanel()
            }
            .environment(appState.coordinator)
            .environment(appState.settings)

            let hosting = NSHostingView(rootView: AnyView(content))
            let panel = NSPanel(
                contentRect: .zero,
                styleMask: [.nonactivatingPanel, .hudWindow, .utilityWindow, .titled],
                backing: .buffered,
                defer: false
            )
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isMovableByWindowBackground = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.hidesOnDeactivate = false
            panel.becomesKeyOnlyIfNeeded = true
            panel.contentView = hosting
            panel.setContentSize(hosting.fittingSize)
            positionBottomRight(panel)
            self.panel = panel
        }
        panel?.orderFrontRegardless()
    }

    private func hidePanel() {
        panel?.orderOut(nil)
    }

    private func positionBottomRight(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let inset: CGFloat = 24
        let frame = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: frame.maxX - size.width - inset,
            y: frame.minY + inset
        ))
    }
}
