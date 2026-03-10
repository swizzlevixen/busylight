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
        // Isolate only the modifier flags that were saved during recording so the
        // comparison is identical on both sides (recorder uses the same intersection).
        let recordedModifiers = NSEvent.ModifierFlags(rawValue: shortcut.modifiers)
        let relevantFlags: NSEvent.ModifierFlags = [.command, .control, .option, .shift]

        let matches = { (event: NSEvent) -> Bool in
            event.keyCode == shortcut.keyCode &&
            event.modifierFlags.intersection(relevantFlags) == recordedModifiers
        }

        // Global monitor — fires when ANOTHER app is in the foreground.
        // This is the primary use case: user presses a scene shortcut while
        // working in Zoom, Safari, etc.
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            guard matches(event) else { return }
            Task { @MainActor in self?.handleShortcutActivation(shortcut) }
        }) {
            monitors.append(global)
        }

        // Local monitor — fires when BusyLight itself is the active app
        // (e.g. Settings window is open).  addGlobalMonitorForEvents never
        // fires for the current app's own events, so without this, shortcuts
        // are dead whenever BusyLight has focus.
        if let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            guard matches(event) else { return event }
            Task { @MainActor in self?.handleShortcutActivation(shortcut) }
            return nil  // consume the event
        }) {
            monitors.append(local)
        }
    }

    private func handleShortcutActivation(_ shortcut: KeyboardShortcutConfig) {
        let settings = AppSettings.shared
        let entityId = shortcut.sceneEntityId

        // Toggle: if this scene is already active, deactivate it
        // MenuBarLabelView updates automatically via @Observable on AppSettings
        if settings.activeSceneId == entityId {
            settings.activeSceneId = nil
        } else {
            settings.activeSceneId = entityId

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
