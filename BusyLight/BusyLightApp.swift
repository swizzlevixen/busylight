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
    }
}

extension Notification.Name {
    static let openSettingsRequest = Notification.Name("BusyLight.openSettingsRequest")
    static let settingsWindowClosed = Notification.Name("BusyLight.settingsWindowClosed")
}
