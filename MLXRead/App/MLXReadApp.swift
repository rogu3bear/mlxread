import SwiftUI

@main
struct MLXReadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
                .environment(appDelegate.appState.coordinator)
                .environment(appDelegate.appState.settings)
                .environment(appDelegate.appState.modelStore)
                .environment(appDelegate.appState.selectionAccess)
                .environment(appDelegate.appState.updates)
                .environment(appDelegate.appState)
        } label: {
            MenuBarIcon()
                .environment(appDelegate.appState.coordinator)
        }

        Settings {
            SettingsView(showSetup: appDelegate.showOnboarding)
                .environment(appDelegate.appState.coordinator)
                .environment(appDelegate.appState.settings)
                .environment(appDelegate.appState.modelStore)
                .environment(appDelegate.appState.selectionAccess)
                .environment(appDelegate.appState.updates)
                .environment(appDelegate.appState)
        }
    }
}

private struct MenuBarIcon: View {
    @Environment(SpeechCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var frameTime: TimeInterval = 0
    // TimelineView can loop while MenuBarExtra extracts its image. Subscribe
    // to this timer only while showing the animated ring.
    private let frameTimer = Timer.publish(every: 1.0 / 24, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            switch coordinator.state {
            case .capturing, .preparing, .generating, .stopping:
                if reduceMotion {
                    Image(nsImage: progressRing(at: 0))
                } else {
                    Image(nsImage: progressRing(at: frameTime))
                        .onReceive(frameTimer) { frameTime = $0.timeIntervalSinceReferenceDate }
                }
            default:
                Image(systemName: symbolName)
            }
        }
        .accessibilityLabel("MLXRead, \(coordinator.state.displayName)")
        .help(coordinator.state.displayName)
    }

    // MenuBarExtra extracts an image from its label. Draw each frame into the
    // image itself so the ring moves in the menu bar, even with its menu closed.
    private func progressRing(at time: TimeInterval) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let circle = NSBezierPath(ovalIn: NSRect(x: 2.5, y: 2.5, width: 13, height: 13))
            circle.lineWidth = 1.8
            NSColor.black.withAlphaComponent(0.2).setStroke()
            circle.stroke()

            let angle = 90 - CGFloat(time.truncatingRemainder(dividingBy: 0.9) / 0.9) * 360
            let arc = NSBezierPath()
            arc.appendArc(withCenter: NSPoint(x: 9, y: 9), radius: 6.5,
                          startAngle: angle, endAngle: angle - 250, clockwise: true)
            arc.lineWidth = 1.8
            arc.lineCapStyle = .round
            NSColor.black.setStroke()
            arc.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }

    private var symbolName: String {
        switch coordinator.state {
        case .playing: return "waveform.circle.fill"
        case .capturing, .preparing, .generating, .stopping: return "waveform.circle"
        case .failed: return "exclamationmark.circle"
        case .permissionRequired, .modelRequired, .voiceRequired, .unavailable: return "waveform.slash"
        case .idle: return "waveform"
        }
    }
}
