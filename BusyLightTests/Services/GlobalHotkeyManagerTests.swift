import XCTest
@testable import BusyLight

@MainActor
final class GlobalHotkeyManagerTests: XCTestCase {

    func testUpdateShortcuts() {
        let manager = GlobalHotkeyManager.shared
        let shortcuts = [
            KeyboardShortcutConfig(keyCode: 12, modifiers: 256, sceneEntityId: "scene.test"),
        ]
        manager.updateShortcuts(shortcuts)
        manager.unregisterAll()
    }

    func testUnregisterAll() {
        let manager = GlobalHotkeyManager.shared
        // Should be safe to call even with no shortcuts registered
        manager.unregisterAll()
    }

    func testUpdateEmptyShortcuts() {
        let manager = GlobalHotkeyManager.shared
        manager.updateShortcuts([])
        manager.unregisterAll()
    }

    func testMultipleUpdates() {
        let manager = GlobalHotkeyManager.shared

        let shortcuts1 = [
            KeyboardShortcutConfig(keyCode: 12, modifiers: 256, sceneEntityId: "scene.a"),
        ]
        manager.updateShortcuts(shortcuts1)

        let shortcuts2 = [
            KeyboardShortcutConfig(keyCode: 0, modifiers: 768, sceneEntityId: "scene.b"),
            KeyboardShortcutConfig(keyCode: 1, modifiers: 768, sceneEntityId: "scene.c"),
        ]
        manager.updateShortcuts(shortcuts2)

        manager.unregisterAll()
    }
}
