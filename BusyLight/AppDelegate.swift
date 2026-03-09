import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var menuDelegateHandler: MenuDelegateHandler!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "\u{26AB} No Scene"
        }

        menu = NSMenu()
        menuDelegateHandler = MenuDelegateHandler()
        menu.delegate = menuDelegateHandler
        statusItem.menu = menu

        MenuBarManager.shared.configure(statusItem: statusItem)

        TriggerManager.shared.startAllMonitors()
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
                    title: "Preferences\u{2026}",
                    action: #selector(openPreferences),
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

    @objc private func openPreferences() {
        NotificationCenter.default.post(name: .openSettingsRequest, object: nil)
    }
}
