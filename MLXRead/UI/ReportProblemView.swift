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
                Text("Send your description and app diagnostics to the developer. MLXRead does not attach the text you’ve been reading.")
            }

            Section("Your email (optional)") {
                TextField("you@example.com", text: $settings.reporterEmail)
                    .textContentType(.emailAddress)
                    .disableAutocorrection(true)
                Text("So the developer can reply. Leave it blank to report anonymously.")
                    .foregroundStyle(.secondary)
            }

            Section("What happened?") {
                Text("Describe the problem and what you expected. Don’t include private reading content.")
                    .foregroundStyle(.secondary)
                TextEditor(text: $description)
                    .frame(minHeight: 90)
                    .font(.body)
                    .accessibilityLabel("Problem description")
            }

            Section {
                DisclosureGroup("What's included", isExpanded: $showDetails) {
                    Text(summary.isEmpty ? "…" : summary)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Section {
                switch phase {
                case .sent:
                    Label("Report sent — thank you.", systemImage: "checkmark.circle.fill")
                    Button("Send another") {
                        description = ""
                        phase = .idle
                    }
                case .failed(let message):
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .fixedSize(horizontal: false, vertical: true)
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
