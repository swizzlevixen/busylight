import SwiftUI

@main
struct BusyLightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Hidden window MUST come before Settings scene for the workaround to work
        Window("Hidden", id: "hidden") {
            HiddenWindowView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1, height: 1)
        .windowStyle(.hiddenTitleBar)

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
