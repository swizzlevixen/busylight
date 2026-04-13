import SwiftUI

@main
struct BusyLightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
        } label: {
            // Kept as a separate View so @Observable change tracking works.
            MenuBarLabelView()
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .onDisappear {
                    NotificationCenter.default.post(name: .settingsWindowClosed, object: nil)
                }
        }
        .commands {
            CommandGroup(replacing: .help) {
                Button("Busy Light Help") {
                    HelpManager.openHelp()
                }
                .keyboardShortcut("?", modifiers: .command)
                Divider()
                Button("Getting Started") {
                    HelpManager.openHelp(anchor: "getting-started")
                }
                Button("Adding Scenes") {
                    HelpManager.openHelp(anchor: "adding-scenes")
                }
                Button("Using Triggers") {
                    HelpManager.openHelp(anchor: "using-triggers")
                }
                Button("Troubleshooting") {
                    HelpManager.openHelp(anchor: "troubleshooting")
                }
            }
        }
    }
}

extension Notification.Name {
    static let openSettingsRequest = Notification.Name("BusyLight.openSettingsRequest")
    static let settingsWindowClosed = Notification.Name("BusyLight.settingsWindowClosed")
    static let haConnectionStateChanged = Notification.Name("BusyLight.haConnectionStateChanged")
}
