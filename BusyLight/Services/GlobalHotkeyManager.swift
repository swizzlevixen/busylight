import AppKit
import Carbon

@MainActor
final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    private var monitors: [Any] = []
    private var registeredShortcuts: [KeyboardShortcutConfig] = []

    func updateShortcuts(_ shortcuts: [KeyboardShortcutConfig]) {
        unregisterAll()
        registeredShortcuts = shortcuts

        for shortcut in shortcuts {
            registerShortcut(shortcut)
        }
    }

    private func registerShortcut(_ shortcut: KeyboardShortcutConfig) {
        let monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            if event.keyCode == shortcut.keyCode &&
                event.modifierFlags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue == UInt(shortcut.modifiers) {
                Task { @MainActor in
                    self.handleShortcutActivation(shortcut)
                }
            }
        }
        if let monitor {
            monitors.append(monitor)
        }
    }

    private func handleShortcutActivation(_ shortcut: KeyboardShortcutConfig) {
        let settings = AppSettings.shared
        let entityId = shortcut.sceneEntityId

        // Toggle: if this scene is already active, deactivate it
        if settings.activeSceneId == entityId {
            settings.activeSceneId = nil
            MenuBarManager.shared.updateButtonTitle()
        } else {
            settings.activeSceneId = entityId
            MenuBarManager.shared.updateButtonTitle()

            Task {
                await HomeAssistantService.shared.activateScene(
                    entityId: entityId,
                    baseURL: settings.haBaseURL,
                    token: settings.haToken
                )
            }
        }
    }

    func unregisterAll() {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors.removeAll()
        registeredShortcuts.removeAll()
    }
}
