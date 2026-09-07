import SwiftUI

struct SettingsView: View {
    var showSetup: () -> Void
    @State private var selectedTab = Tab.voice

    private enum Tab: Hashable { case voice, general, models, permissions, report }
    var body: some View {
        TabView(selection: $selectedTab) {
            VoiceSettingsView()
                .tabItem { Label("Voice", systemImage: "person.wave.2") }
                .tag(Tab.voice)
            GeneralSettingsView(showSetup: showSetup)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(Tab.general)
            ModelSettingsView()
                .tabItem { Label("Models", systemImage: "internaldrive") }
                .tag(Tab.models)
            PermissionView()
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
                .tag(Tab.permissions)
            ReportProblemView()
                .tabItem { Label("Report", systemImage: "exclamationmark.bubble") }
                .tag(Tab.report)
        }
        .font(.body)
        .frame(width: 600, height: 680)
    }
}
