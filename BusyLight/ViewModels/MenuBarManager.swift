import AppKit
import Foundation

@MainActor
final class MenuBarManager {
    static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?
    private let settings = AppSettings.shared

    func configure(statusItem: NSStatusItem) {
        self.statusItem = statusItem
        updateButtonTitle()
    }

    /// Populates the menu with the scene list for a normal (non-option) click.
    func populateMenu(_ menu: NSMenu) {
        let hasItems = !settings.menuItems.isEmpty

        for item in settings.menuItems {
            switch item {
            case .scene(let scene):
                let title: String
                switch settings.displayMode {
                case .emojiOnly:
                    title = scene.emoji
                case .nameOnly:
                    title = scene.displayName
                case .both:
                    title = "\(scene.emoji) \(scene.displayName)"
                }

                let menuItem = NSMenuItem(
                    title: title,
                    action: #selector(sceneSelected(_:)),
                    keyEquivalent: ""
                )
                menuItem.target = self
                menuItem.representedObject = scene.entityId

                // Show keyboard shortcut if assigned
                if let shortcut = settings.keyboardShortcuts.first(where: { $0.sceneEntityId == scene.entityId }) {
                    menuItem.keyEquivalentModifierMask = NSEvent.ModifierFlags(rawValue: UInt(shortcut.modifiers))
                    if let char = keyCodeToCharacter(shortcut.keyCode) {
                        menuItem.keyEquivalent = String(char)
                    }
                }

                // Check mark on active scene
                if scene.entityId == settings.activeSceneId {
                    menuItem.state = .on
                }

                menu.addItem(menuItem)

            case .divider:
                menu.addItem(NSMenuItem.separator())
            }
        }

        // "No Scene" option
        if hasItems {
            menu.addItem(NSMenuItem.separator())
        }
        let noSceneItem = NSMenuItem(
            title: "\u{26AB} No Scene",
            action: #selector(clearScene),
            keyEquivalent: ""
        )
        noSceneItem.target = self
        if settings.activeSceneId == nil {
            noSceneItem.state = .on
        }
        menu.addItem(noSceneItem)

        // Connection status indicator
        let connectionState = ConnectionState.unknown // Will be updated async
        Task {
            let state = await HomeAssistantService.shared.connectionState
            if state == .disconnected || (state != .connected && state != .unknown) {
                await MainActor.run {
                    menu.addItem(NSMenuItem.separator())
                    let statusItem = NSMenuItem(title: "\u{26A0} HA Disconnected", action: nil, keyEquivalent: "")
                    statusItem.isEnabled = false
                    menu.addItem(statusItem)
                }
            }
        }
    }

    @objc private func sceneSelected(_ sender: NSMenuItem) {
        guard let entityId = sender.representedObject as? String else { return }
        settings.activeSceneId = entityId
        updateButtonTitle()

        guard !settings.haBaseURL.isEmpty && !settings.haToken.isEmpty else { return }

        Task {
            let result = await HomeAssistantService.shared.activateScene(
                entityId: entityId,
                baseURL: settings.haBaseURL,
                token: settings.haToken
            )

            if result.success {
                showStatusFeedback(success: true)
            } else {
                showStatusFeedback(success: false)
            }
        }
    }

    @objc private func clearScene() {
        settings.activeSceneId = nil
        updateButtonTitle()
    }

    func updateButtonTitle() {
        guard let button = statusItem?.button else { return }

        guard let activeId = settings.activeSceneId,
              let scene = settings.scenes.first(where: { $0.entityId == activeId }) else {
            button.title = "\u{26AB} No Scene"
            return
        }

        switch settings.displayMode {
        case .emojiOnly:
            button.title = scene.emoji
        case .nameOnly:
            button.title = scene.displayName
        case .both:
            button.title = "\(scene.emoji) \(scene.displayName)"
        }
    }

    // MARK: - Status Feedback

    private func showStatusFeedback(success: Bool) {
        guard let button = statusItem?.button else { return }
        let originalTitle = button.title

        if success {
            button.title = "\u{2705} \(originalTitle)"
        } else {
            button.title = "\u{274C} \(originalTitle)"
        }

        // Restore original title after brief flash
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            await MainActor.run {
                self.updateButtonTitle()
            }
        }
    }

    // MARK: - Key Code Conversion

    private func keyCodeToCharacter(_ keyCode: UInt16) -> Character? {
        let keyMap: [UInt16: Character] = [
            0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x",
            8: "c", 9: "v", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r",
            16: "y", 17: "t", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "o", 32: "u", 33: "[", 34: "i", 35: "p", 37: "l",
            38: "j", 39: "'", 40: "k", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "n", 46: "m", 47: ".",
        ]
        return keyMap[keyCode]
    }
}
