import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            VoiceSettingsView()
                .tabItem { Label("Voice", systemImage: "person.wave.2") }
            ModelSettingsView()
                .tabItem { Label("Models", systemImage: "internaldrive") }
            PermissionView()
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
            ReportProblemView()
                .tabItem { Label("Report", systemImage: "exclamationmark.bubble") }
        }
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }
}
