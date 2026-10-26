import AppKit
import SwiftUI

/// Edits config.json. Save also writes Nebula's files, so a running tunnel takes the change at once.
struct SettingsView: View {
    let tunnel: Tunnel
    @State private var draft = Config()

    var body: some View {
        Form {
            TextField("Nameserver", text: $draft.nameserver)
            TextField("DNS domain (*.internal)", text: $draft.dnsDomain)
            TextField("Lighthouse", text: $draft.lighthouse)
            TextField("Hub endpoint", text: $draft.hubEndpoint)
            TextField("CA URL", text: $draft.caURL)
            TextField("CA app ID URI", text: $draft.caAppIDURI)
            HStack {
                Button("Reset to Defaults") { draft = Config() }
                Button("Open config.json") { NSWorkspace.shared.open(Config.file) }
                Spacer()
                Button("Save") {
                    Task {
                        await tunnel.save(draft)
                        draft = tunnel.config
                    }
                }
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft == tunnel.config)
            }
        }
        .formStyle(.grouped)
        .frame(width: 560)
        .onAppear { draft = tunnel.config }
    }
}
