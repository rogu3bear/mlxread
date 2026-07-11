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
                .environment(appDelegate.appState.permissions)
                .environment(appDelegate.appState)
        } label: {
            MenuBarIcon()
                .environment(appDelegate.appState.coordinator)
        }

        Settings {
            SettingsView()
                .environment(appDelegate.appState.coordinator)
                .environment(appDelegate.appState.settings)
                .environment(appDelegate.appState.modelStore)
                .environment(appDelegate.appState.permissions)
                .environment(appDelegate.appState)
        }
    }
}

private struct MenuBarIcon: View {
    @Environment(SpeechCoordinator.self) private var coordinator

    var body: some View {
        Image(systemName: symbolName)
    }

    private var symbolName: String {
        switch coordinator.state {
        case .playing: return "waveform.circle.fill"
        case .capturing, .preparing, .generating, .stopping: return "waveform.circle"
        case .failed: return "exclamationmark.circle"
        case .permissionRequired, .modelRequired, .unavailable: return "waveform.slash"
        case .idle: return "waveform"
        }
    }
}
