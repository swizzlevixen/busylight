import XCTest
@testable import BusyLight

@MainActor
final class MenuBarManagerTests: XCTestCase {

    func testDisplayModeEmojiOnly() {
        let settings = AppSettings.shared
        settings.displayMode = .emojiOnly
        settings.menuItems = [
            .scene(SceneItem(entityId: "scene.test", emoji: "🔴", displayName: "Busy")),
        ]
        settings.activeSceneId = "scene.test"

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let manager = MenuBarManager.shared
        manager.configure(statusItem: statusItem)
        manager.updateButtonTitle()

        XCTAssertEqual(statusItem.button?.title, "🔴")

        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func testDisplayModeNameOnly() {
        let settings = AppSettings.shared
        settings.displayMode = .nameOnly
        settings.menuItems = [
            .scene(SceneItem(entityId: "scene.test", emoji: "🔴", displayName: "Busy")),
        ]
        settings.activeSceneId = "scene.test"

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let manager = MenuBarManager.shared
        manager.configure(statusItem: statusItem)
        manager.updateButtonTitle()

        XCTAssertEqual(statusItem.button?.title, "Busy")

        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func testDisplayModeBoth() {
        let settings = AppSettings.shared
        settings.displayMode = .both
        settings.menuItems = [
            .scene(SceneItem(entityId: "scene.test", emoji: "🔴", displayName: "Busy")),
        ]
        settings.activeSceneId = "scene.test"

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let manager = MenuBarManager.shared
        manager.configure(statusItem: statusItem)
        manager.updateButtonTitle()

        XCTAssertEqual(statusItem.button?.title, "🔴 Busy")

        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func testNoActiveScene() {
        let settings = AppSettings.shared
        settings.activeSceneId = nil

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let manager = MenuBarManager.shared
        manager.configure(statusItem: statusItem)
        manager.updateButtonTitle()

        XCTAssertEqual(statusItem.button?.title, "\u{26AB} No Scene")

        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func testPopulateMenuWithScenes() {
        let settings = AppSettings.shared
        settings.menuItems = [
            .scene(SceneItem(entityId: "scene.busy", emoji: "🔴", displayName: "Busy")),
            .newDivider(),
            .scene(SceneItem(entityId: "scene.free", emoji: "🟢", displayName: "Free")),
        ]
        settings.activeSceneId = "scene.busy"

        let menu = NSMenu()
        let manager = MenuBarManager.shared
        manager.populateMenu(menu)

        // 2 scenes + 1 divider + 1 separator before "No Scene" + "No Scene" = 5 items
        XCTAssertGreaterThanOrEqual(menu.items.count, 4)

        // First item should be the first scene
        XCTAssertTrue(menu.items[0].title.contains("Busy"))
        XCTAssertEqual(menu.items[0].state, .on) // Active scene has checkmark

        // Second item should be a separator
        XCTAssertTrue(menu.items[1].isSeparatorItem)

        // Third item should be the second scene
        XCTAssertTrue(menu.items[2].title.contains("Free"))
        XCTAssertEqual(menu.items[2].state, .off)
    }

    func testPopulateMenuEmpty() {
        let settings = AppSettings.shared
        settings.menuItems = []
        settings.activeSceneId = nil

        let menu = NSMenu()
        let manager = MenuBarManager.shared
        manager.populateMenu(menu)

        // Should have at least "No Scene" item
        XCTAssertGreaterThanOrEqual(menu.items.count, 1)
        let lastItem = menu.items.last!
        XCTAssertTrue(lastItem.title.contains("No Scene"))
        XCTAssertEqual(lastItem.state, .on) // No scene active
    }
}
