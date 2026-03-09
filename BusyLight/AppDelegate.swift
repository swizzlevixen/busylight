import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        TriggerManager.shared.startAllMonitors()

        // Handle opening the Settings window (activation policy + window title).
        // Uses SettingsOpener, which captures the openSettings action from
        // MenuBarLabelView (always live), so this works at any time.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenSettings(_:)),
            name: .openSettingsRequest,
            object: nil
        )

        // First-run welcome dialog (deferred so the app finishes launching first)
        if !AppSettings.shared.hasCompletedFirstRun {
            DispatchQueue.main.async { [self] in
                showFirstRunDialog()
            }
        }
    }

    @objc private func handleOpenSettings(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Open the Settings window via the captured SwiftUI openSettings action.
        // SettingsOpener captures this from MenuBarLabelView, which is always live.
        SettingsOpener.shared.openSettings()

        // Rename the settings window after it appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let settingsWindow = NSApp.windows.first(where: {
                $0.isVisible && $0.styleMask.contains(.titled)
            }) {
                settingsWindow.title = "Settings"
                settingsWindow.makeKeyAndOrderFront(nil)
                settingsWindow.orderFrontRegardless()
            }
        }
    }

    private func showFirstRunDialog() {
        let alert = NSAlert()
        alert.messageText = "Welcome to Busy Light"
        alert.informativeText = """
            Busy Light connects to Home Assistant to control scenes that \
            indicate your availability.

            To get started, you\u{2019}ll need:
            1. Your Home Assistant URL (e.g., http://homeassistant.local:8123)
            2. A Long-Lived Access Token (created in your HA profile settings)

            Click \u{201C}Open Settings\u{201D} to configure your connection.
            """
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")
        alert.alertStyle = .informational

        AppSettings.shared.hasCompletedFirstRun = true

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            NotificationCenter.default.post(
                name: .openSettingsRequest,
                object: nil,
                userInfo: ["tab": "homeassistant"]
            )
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        TriggerManager.shared.stopAllMonitors()
    }
}
