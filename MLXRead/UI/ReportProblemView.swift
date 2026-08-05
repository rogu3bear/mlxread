import SwiftUI

/// "Report a problem" settings tab: collects an optional email + description,
/// attaches a privacy-safe debug bundle, and uploads it to the maintainer.
struct ReportProblemView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppSettings.self) private var settings

    @State private var description = ""
    @State private var summary = ""
    @State private var showDetails = false
    @State private var phase: Phase = .idle

    private enum Phase: Equatable {
        case idle
        case sending
        case sent
        case failed(String)
    }

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Text("Something not working? Send a report straight to the developer. It never includes your selected or spoken text — only app diagnostics.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Your email (optional)") {
                TextField("you@example.com", text: $settings.reporterEmail)
                    .textContentType(.emailAddress)
                    .disableAutocorrection(true)
                Text("So the developer can reply. Leave it blank to report anonymously.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("What happened?") {
                TextEditor(text: $description)
                    .frame(minHeight: 90)
                    .font(.body)
            }

            Section {
                DisclosureGroup("What's included", isExpanded: $showDetails) {
                    Text(summary.isEmpty ? "…" : summary)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Section {
                switch phase {
                case .sent:
                    Label("Report sent — thank you.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Button("Send another") {
                        description = ""
                        phase = .idle
                    }
                case .failed(let message):
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Button("Try again") { submit() }
                default:
                    Button(action: submit) {
                        if phase == .sending {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text("Sending…")
                            }
                        } else {
                            Text("Send Report")
                        }
                    }
                    .disabled(phase == .sending)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.bottom, 8)
        .onAppear {
            if summary.isEmpty {
                summary = DebugBundle(appState: appState).summary
            }
        }
    }

    private func submit() {
        phase = .sending
        let email = settings.reporterEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let desc = description
        let bundle = DebugBundle(appState: appState) // built on the main actor
        Task {
            do {
                let zip = try bundle.makeZip()
                try await ReportSender().send(
                    zip: zip,
                    fields: .init(
                        email: email,
                        description: desc,
                        appVersion: bundle.appVersion,
                        osVersion: bundle.osVersion
                    )
                )
                await MainActor.run { phase = .sent }
            } catch {
                await MainActor.run { phase = .failed(error.localizedDescription) }
            }
        }
    }
}
