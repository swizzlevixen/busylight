import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var menuDelegateHandler: MenuDelegateHandler!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            let settings = AppSettings.shared
            switch settings.displayMode {
            case .emojiOnly:
                button.title = "\u{26AB}"
            case .nameOnly:
                button.title = "No Scene"
            case .both:
                button.title = "\u{26AB} No Scene"
            }
        }

        menu = NSMenu()
        menuDelegateHandler = MenuDelegateHandler()
        menu.delegate = menuDelegateHandler
        statusItem.menu = menu

        MenuBarManager.shared.configure(statusItem: statusItem)

        TriggerManager.shared.startAllMonitors()

        // First-run welcome dialog
        if !AppSettings.shared.hasCompletedFirstRun {
            showFirstRunDialog()
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

// Separate class for NSMenuDelegate to avoid MainActor isolation issues
final class MenuDelegateHandler: NSObject, NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        // NSMenuDelegate always runs on the main thread
        MainActor.assumeIsolated {
            menu.removeAllItems()

            let isOptionPressed = NSEvent.modifierFlags.contains(.option)

            if isOptionPressed {
                let prefsItem = NSMenuItem(
                    title: "Settings\u{2026}",
                    action: #selector(openSettings),
                    keyEquivalent: ","
                )
                prefsItem.target = self
                menu.addItem(prefsItem)
                menu.addItem(NSMenuItem.separator())
                let quitItem = NSMenuItem(
                    title: "Quit Busy Light",
                    action: #selector(NSApplication.terminate(_:)),
                    keyEquivalent: "q"
                )
                menu.addItem(quitItem)
            } else {
                MenuBarManager.shared.populateMenu(menu)
            }
        }
    }

    @objc private func openSettings() {
        NotificationCenter.default.post(name: .openSettingsRequest, object: nil)
    }
}
