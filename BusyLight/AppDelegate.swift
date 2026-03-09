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

        // Observe settings open/close requests (replaces the hidden-window workaround)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenSettings(_:)),
            name: .openSettingsRequest,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsWindowClosed),
            name: .settingsWindowClosed,
            object: nil
        )

        // First-run welcome dialog (deferred to next run-loop cycle so the
        // app finishes launching first)
        if !AppSettings.shared.hasCompletedFirstRun {
            DispatchQueue.main.async { [self] in
                showFirstRunDialog()
            }
        }
    }

    @objc private func handleOpenSettings(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)

        // Set the window title after the settings window appears
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

    @objc private func handleSettingsWindowClosed() {
        NSApp.setActivationPolicy(.accessory)
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
