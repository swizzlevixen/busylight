import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        // When running as a test host, bypass the system keychain to avoid
        // the authorization dialog (we may be running remotely / unattended).
        if ProcessInfo.processInfo.environment["XCInjectBundleInto"] != nil {
            KeychainHelper.testStore = KeychainHelper.testStore ?? [:]
        }
        #endif

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
            Task { @MainActor in
                showFirstRunDialog()
            }
        }
    }

    @objc private func handleOpenSettings(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()

        // Listen for the Settings window to become key, then rename it and
        // strip the unwanted View menu.  One-shot: removes itself after firing.
        var token: NSObjectProtocol?
        token = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { windowNotification in
            guard let window = windowNotification.object as? NSWindow,
                  window.styleMask.contains(.titled) else { return }

            window.title = "Settings"
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()

            if let viewMenu = NSApp.mainMenu?.item(withTitle: "View") {
                NSApp.mainMenu?.removeItem(viewMenu)
            }

            if let token { NotificationCenter.default.removeObserver(token) }
        }

        // Open the Settings window via the captured SwiftUI openSettings action.
        // SettingsOpener captures this from MenuBarLabelView, which is always live.
        SettingsOpener.shared.openSettings()
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
