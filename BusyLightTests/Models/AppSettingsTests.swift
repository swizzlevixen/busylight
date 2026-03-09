import XCTest
@testable import BusyLight

@MainActor
final class AppSettingsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Reset settings to defaults for each test
        let settings = AppSettings.shared
        settings.menuItems = []
        settings.activeSceneId = nil
        settings.displayMode = .both
        settings.webcamTriggerEnabled = false
        settings.webcamOnSceneId = ""
        settings.webcamOffTriggerEnabled = false
        settings.webcamOffSceneId = ""
        settings.keyboardShortcuts = []
    }

    override func tearDown() {
        let settings = AppSettings.shared
        settings.menuItems = []
        settings.activeSceneId = nil
        super.tearDown()
    }

    func testDefaultDisplayMode() {
        // After reset
        XCTAssertEqual(AppSettings.shared.displayMode, .both)
    }

    func testDisplayModeValues() {
        XCTAssertEqual(DisplayMode.emojiOnly.rawValue, "emoji")
        XCTAssertEqual(DisplayMode.nameOnly.rawValue, "name")
        XCTAssertEqual(DisplayMode.both.rawValue, "both")
    }

    func testDisplayModeFromRawValue() {
        XCTAssertEqual(DisplayMode(rawValue: "emoji"), .emojiOnly)
        XCTAssertEqual(DisplayMode(rawValue: "name"), .nameOnly)
        XCTAssertEqual(DisplayMode(rawValue: "both"), .both)
        XCTAssertNil(DisplayMode(rawValue: "invalid"))
    }

    func testMenuItemsCRUD() {
        let settings = AppSettings.shared

        // Add scene
        let scene = SceneItem(entityId: "scene.test", emoji: "🔴", displayName: "Test")
        settings.menuItems.append(.scene(scene))
        XCTAssertEqual(settings.menuItems.count, 1)
        XCTAssertEqual(settings.scenes.count, 1)

        // Add divider
        settings.menuItems.append(.newDivider())
        XCTAssertEqual(settings.menuItems.count, 2)
        XCTAssertEqual(settings.scenes.count, 1) // Dividers don't count as scenes

        // Add another scene
        let scene2 = SceneItem(entityId: "scene.test2", emoji: "🟢", displayName: "Test 2")
        settings.menuItems.append(.scene(scene2))
        XCTAssertEqual(settings.menuItems.count, 3)
        XCTAssertEqual(settings.scenes.count, 2)

        // Remove
        settings.menuItems.remove(at: 1) // Remove divider
        XCTAssertEqual(settings.menuItems.count, 2)

        // Reorder
        settings.menuItems.move(fromOffsets: IndexSet(integer: 0), toOffset: 2)
        XCTAssertEqual(settings.menuItems[0].sceneItem?.entityId, "scene.test2")
        XCTAssertEqual(settings.menuItems[1].sceneItem?.entityId, "scene.test")
    }

    func testScenesComputedProperty() {
        let settings = AppSettings.shared
        settings.menuItems = [
            .scene(SceneItem(entityId: "scene.a", displayName: "A")),
            .newDivider(),
            .scene(SceneItem(entityId: "scene.b", displayName: "B")),
            .newDivider(),
            .scene(SceneItem(entityId: "scene.c", displayName: "C")),
        ]

        let scenes = settings.scenes
        XCTAssertEqual(scenes.count, 3)
        XCTAssertEqual(scenes[0].entityId, "scene.a")
        XCTAssertEqual(scenes[1].entityId, "scene.b")
        XCTAssertEqual(scenes[2].entityId, "scene.c")
    }

    func testTriggerSettingsDefaults() {
        let settings = AppSettings.shared
        XCTAssertFalse(settings.webcamTriggerEnabled)
        XCTAssertFalse(settings.webcamOffTriggerEnabled)
        XCTAssertFalse(settings.micTriggerEnabled)
        XCTAssertFalse(settings.micOffTriggerEnabled)
        XCTAssertFalse(settings.screenLockTriggerEnabled)
        XCTAssertFalse(settings.screenUnlockTriggerEnabled)
        XCTAssertFalse(settings.focusOnTriggerEnabled)
        XCTAssertFalse(settings.focusOffTriggerEnabled)
    }

    func testKeyboardShortcutConfig() throws {
        let config = KeyboardShortcutConfig(keyCode: 12, modifiers: 256, sceneEntityId: "scene.test")
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(KeyboardShortcutConfig.self, from: data)
        XCTAssertEqual(decoded.keyCode, 12)
        XCTAssertEqual(decoded.modifiers, 256)
        XCTAssertEqual(decoded.sceneEntityId, "scene.test")
    }

    func testActiveSceneIdPersistence() {
        let settings = AppSettings.shared
        settings.activeSceneId = "scene.test"
        XCTAssertEqual(settings.activeSceneId, "scene.test")

        settings.activeSceneId = nil
        XCTAssertNil(settings.activeSceneId)
    }
}
