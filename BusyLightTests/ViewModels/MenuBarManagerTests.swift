import XCTest
@testable import BusyLight

@MainActor
final class MenuBarManagerTests: XCTestCase {

    private let scene = SceneItem(entityId: "scene.test", emoji: "\u{1F534}", displayName: "Busy")

    override func setUp() {
        super.setUp()
        let settings = AppSettings.shared
        settings.displayMode = .both
        settings.menuItems = []
        settings.activeSceneId = nil
    }

    // MARK: - noSceneLabel

    func testNoSceneLabelBoth() {
        AppSettings.shared.displayMode = .both
        XCTAssertEqual(AppSettings.shared.noSceneLabel, "\u{26AB} No Scene")
    }

    func testNoSceneLabelEmojiOnly() {
        AppSettings.shared.displayMode = .emojiOnly
        XCTAssertEqual(AppSettings.shared.noSceneLabel, "\u{26AB}")
    }

    func testNoSceneLabelNameOnly() {
        AppSettings.shared.displayMode = .nameOnly
        XCTAssertEqual(AppSettings.shared.noSceneLabel, "No Scene")
    }

    // MARK: - menuBarLabel (no active scene)

    func testMenuBarLabelNoSceneBoth() {
        AppSettings.shared.displayMode = .both
        AppSettings.shared.activeSceneId = nil
        XCTAssertEqual(AppSettings.shared.menuBarLabel, "\u{26AB} No Scene")
    }

    func testMenuBarLabelNoSceneEmojiOnly() {
        AppSettings.shared.displayMode = .emojiOnly
        AppSettings.shared.activeSceneId = nil
        XCTAssertEqual(AppSettings.shared.menuBarLabel, "\u{26AB}")
    }

    func testMenuBarLabelNoSceneNameOnly() {
        AppSettings.shared.displayMode = .nameOnly
        AppSettings.shared.activeSceneId = nil
        XCTAssertEqual(AppSettings.shared.menuBarLabel, "No Scene")
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
        XCTAssertEqual(AppSettings.shared.menuBarLabel, "\u{26AB} No Scene")
    }

    // MARK: - MenuBarManager activation

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
        XCTAssertEqual(AppSettings.shared.menuBarLabel, "\u{26AB} No Scene")
    }
}
