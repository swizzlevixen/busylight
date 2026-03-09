import XCTest
@testable import BusyLight

@MainActor
final class MenuBarManagerTests: XCTestCase {

    func testDisplayModeEmojiOnly() {
        let settings = AppSettings.shared
        settings.displayMode = .emojiOnly
        settings.menuItems = [
            .scene(SceneItem(entityId: "scene.test", emoji: "\u{1F534}", displayName: "Busy")),
        ]
        settings.activeSceneId = "scene.test"

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let manager = MenuBarManager.shared
        manager.configure(statusItem: statusItem)
        manager.updateButtonTitle()

        XCTAssertEqual(statusItem.button?.title, "\u{1F534}")

        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func testDisplayModeNameOnly() {
        let settings = AppSettings.shared
        settings.displayMode = .nameOnly
        settings.menuItems = [
            .scene(SceneItem(entityId: "scene.test", emoji: "\u{1F534}", displayName: "Busy")),
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
            .scene(SceneItem(entityId: "scene.test", emoji: "\u{1F534}", displayName: "Busy")),
        ]
        settings.activeSceneId = "scene.test"

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let manager = MenuBarManager.shared
        manager.configure(statusItem: statusItem)
        manager.updateButtonTitle()

        XCTAssertEqual(statusItem.button?.title, "\u{1F534} Busy")

        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func testNoActiveSceneDisplayModeBoth() {
        let settings = AppSettings.shared
        settings.displayMode = .both
        settings.activeSceneId = nil

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let manager = MenuBarManager.shared
        manager.configure(statusItem: statusItem)
        manager.updateButtonTitle()

        XCTAssertEqual(statusItem.button?.title, "\u{26AB} No Scene")

        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func testNoActiveSceneDisplayModeEmojiOnly() {
        let settings = AppSettings.shared
        settings.displayMode = .emojiOnly
        settings.activeSceneId = nil

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let manager = MenuBarManager.shared
        manager.configure(statusItem: statusItem)
        manager.updateButtonTitle()

        XCTAssertEqual(statusItem.button?.title, "\u{26AB}")

        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func testNoActiveSceneDisplayModeNameOnly() {
        let settings = AppSettings.shared
        settings.displayMode = .nameOnly
        settings.activeSceneId = nil

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let manager = MenuBarManager.shared
        manager.configure(statusItem: statusItem)
        manager.updateButtonTitle()

        XCTAssertEqual(statusItem.button?.title, "No Scene")

        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func testPopulateMenuWithScenes() {
        let settings = AppSettings.shared
        settings.displayMode = .both
        settings.menuItems = [
            .scene(SceneItem(entityId: "scene.busy", emoji: "\u{1F534}", displayName: "Busy")),
            .newDivider(),
            .scene(SceneItem(entityId: "scene.free", emoji: "\u{1F7E2}", displayName: "Free")),
        ]
        settings.activeSceneId = "scene.busy"

        let menu = NSMenu()
        let manager = MenuBarManager.shared
        manager.populateMenu(menu)

        // 2 scenes + 1 divider = 3 items (No Scene is not shown when scenes exist)
        XCTAssertEqual(menu.items.count, 3)

        // First item should be the first scene
        XCTAssertTrue(menu.items[0].title.contains("Busy"))
        XCTAssertEqual(menu.items[0].state, .on) // Active scene has checkmark

        // Second item should be a separator
        XCTAssertTrue(menu.items[1].isSeparatorItem)

        // Third item should be the second scene
        XCTAssertTrue(menu.items[2].title.contains("Free"))
        XCTAssertEqual(menu.items[2].state, .off)
    }

    func testPopulateMenuEmptyShowsAddScene() {
        let settings = AppSettings.shared
        settings.displayMode = .both
        settings.menuItems = []
        settings.activeSceneId = nil

        let menu = NSMenu()
        let manager = MenuBarManager.shared
        manager.populateMenu(menu)

        // Should have "Add Scene..." item
        XCTAssertGreaterThanOrEqual(menu.items.count, 1)
        let firstItem = menu.items.first!
        XCTAssertTrue(firstItem.title.contains("Add Scene"))
    }
}
