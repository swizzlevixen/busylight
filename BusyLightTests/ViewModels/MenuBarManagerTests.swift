import XCTest
@testable import BusyLight

@MainActor
final class MenuBarManagerTests: XCTestCase {

    private let scene = SceneItem(entityId: "scene.test", emoji: "\u{1F534}", displayName: "Busy")

    override func setUp() {
        super.setUp()
        KeychainHelper.testStore = [:]
        let settings = AppSettings.shared
        settings.displayMode = .both
        settings.menuItems = []
        settings.activeSceneId = nil
    }

    override func tearDown() {
        KeychainHelper.testStore = nil
        super.tearDown()
    }

    // MARK: - noSceneLabel

    func testNoSceneLabelBoth() {
        AppSettings.shared.displayMode = .both
        XCTAssertEqual(AppSettings.shared.noSceneLabel, "🚦 Busy Light")
    }

    func testNoSceneLabelEmojiOnly() {
        AppSettings.shared.displayMode = .emojiOnly
        XCTAssertEqual(AppSettings.shared.noSceneLabel, "🚦")
    }

    func testNoSceneLabelNameOnly() {
        AppSettings.shared.displayMode = .nameOnly
        XCTAssertEqual(AppSettings.shared.noSceneLabel, "Busy Light")
    }

    // MARK: - menuBarLabel (no active scene)

    func testMenuBarLabelNoSceneBoth() {
        AppSettings.shared.displayMode = .both
        AppSettings.shared.activeSceneId = nil
        XCTAssertEqual(AppSettings.shared.menuBarLabel, "🚦 Busy Light")
    }

    func testMenuBarLabelNoSceneEmojiOnly() {
        AppSettings.shared.displayMode = .emojiOnly
        AppSettings.shared.activeSceneId = nil
        XCTAssertEqual(AppSettings.shared.menuBarLabel, "🚦")
    }

    func testMenuBarLabelNoSceneNameOnly() {
        AppSettings.shared.displayMode = .nameOnly
        AppSettings.shared.activeSceneId = nil
        XCTAssertEqual(AppSettings.shared.menuBarLabel, "Busy Light")
    }

    // MARK: - menuBarLabel (with active scene)

    func testMenuBarLabelWithSceneBoth() {
        AppSettings.shared.displayMode = .both
        AppSettings.shared.menuItems = [.scene(scene)]
        AppSettings.shared.activeSceneId = scene.entityId
        XCTAssertEqual(AppSettings.shared.menuBarLabel, "\u{1F534} Busy")
    }

    func testMenuBarLabelWithSceneEmojiOnly() {
        AppSettings.shared.displayMode = .emojiOnly
        AppSettings.shared.menuItems = [.scene(scene)]
        AppSettings.shared.activeSceneId = scene.entityId
        XCTAssertEqual(AppSettings.shared.menuBarLabel, "\u{1F534}")
    }

    func testMenuBarLabelWithSceneNameOnly() {
        AppSettings.shared.displayMode = .nameOnly
        AppSettings.shared.menuItems = [.scene(scene)]
        AppSettings.shared.activeSceneId = scene.entityId
        XCTAssertEqual(AppSettings.shared.menuBarLabel, "Busy")
    }

    // menuBarLabel falls back to noSceneLabel when activeSceneId doesn't
    // match any scene in the list (e.g. scene was deleted)
    func testMenuBarLabelUnknownSceneIdFallsBackToNoScene() {
        AppSettings.shared.displayMode = .both
        AppSettings.shared.menuItems = [.scene(scene)]
        AppSettings.shared.activeSceneId = "scene.nonexistent"
        XCTAssertEqual(AppSettings.shared.menuBarLabel, "🚦 Busy Light")
    }

    // MARK: - MenuBarManager activation (SceneItem)

    func testActivateSceneSetsActiveSceneId() {
        AppSettings.shared.menuItems = [.scene(scene)]
        MenuBarManager.shared.activateScene(scene)
        XCTAssertEqual(AppSettings.shared.activeSceneId, scene.entityId)
    }

    func testDeactivateSceneClearsActiveSceneId() {
        AppSettings.shared.activeSceneId = scene.entityId
        MenuBarManager.shared.deactivateScene()
        XCTAssertNil(AppSettings.shared.activeSceneId)
    }

    func testActivateSceneUpdatesMenuBarLabel() {
        AppSettings.shared.displayMode = .both
        AppSettings.shared.menuItems = [.scene(scene)]
        MenuBarManager.shared.activateScene(scene)
        XCTAssertEqual(AppSettings.shared.menuBarLabel, "\u{1F534} Busy")
    }

    func testDeactivateSceneRestoresNoSceneLabel() {
        AppSettings.shared.displayMode = .both
        AppSettings.shared.menuItems = [.scene(scene)]
        AppSettings.shared.activeSceneId = scene.entityId
        MenuBarManager.shared.deactivateScene()
        XCTAssertEqual(AppSettings.shared.menuBarLabel, "🚦 Busy Light")
    }

    // MARK: - MenuBarManager activation (entityId)

    func testActivateSceneByEntityIdSetsActiveSceneId() {
        MenuBarManager.shared.activateScene(entityId: scene.entityId)
        XCTAssertEqual(AppSettings.shared.activeSceneId, scene.entityId)
    }

    func testActivateSceneByEntityIdUpdatesMenuBarLabel() {
        AppSettings.shared.displayMode = .both
        AppSettings.shared.menuItems = [.scene(scene)]
        MenuBarManager.shared.activateScene(entityId: scene.entityId)
        XCTAssertEqual(AppSettings.shared.menuBarLabel, "\u{1F534} Busy")
    }

    func testActivateSceneWithResultSetsActiveSceneId() async {
        let result = await MenuBarManager.shared.activateSceneWithResult(entityId: scene.entityId)
        XCTAssertEqual(AppSettings.shared.activeSceneId, scene.entityId)
        // No HA configured in tests, so returns success with empty entities
        XCTAssertTrue(result.success)
    }
}
