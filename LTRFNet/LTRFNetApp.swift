import ServiceManagement
import SwiftUI

@main
struct LTRFNetApp: App {
    @State private var tunnel = Tunnel()

    var body: some Scene {
        MenuBarExtra {
            MenuView(tunnel: tunnel)
        } label: {
            Image(tunnel.enabled ? "MenuOn" : "MenuOff")
        }
        Window("LTRFNet Settings", id: "settings") {
            SettingsView(tunnel: tunnel)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
    }
}

struct MenuView: View {
    let tunnel: Tunnel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Toggle("Enabled", isOn: Binding(get: { tunnel.enabled }, set: { on in Task { await tunnel.setEnabled(on) } }))
        Text(tunnel.status)
        Button("Renew Now") { Task { await tunnel.renewNow() } }
        if tunnel.needsApproval {
            Button("Approve in System Settings…") { SMAppService.openSystemSettingsLoginItems() }
        }
        Divider()
        Button("Settings…") {
            openWindow(id: "settings")
            NSApp.activate()
        }
        .keyboardShortcut(",")
        Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
