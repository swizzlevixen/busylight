import XCTest
@testable import BusyLight

@MainActor
final class SceneUndoHandlerTests: XCTestCase {

    private var undoManager: UndoManager!
    private var handler: SceneUndoHandler!

    override func setUp() {
        super.setUp()
        undoManager = UndoManager()
        handler = SceneUndoHandler()
        handler.undoManager = undoManager
        // Reset to clean state
        AppSettings.shared.menuItems = []
        AppSettings.shared.keyboardShortcuts = []
    }

    override func tearDown() {
        AppSettings.shared.menuItems = []
        AppSettings.shared.keyboardShortcuts = []
        super.tearDown()
    }

    // MARK: - Undo Add Scene

    func testUndoAddScene() {
        let scene = SceneItem(entityId: "scene.test", emoji: "🔴", displayName: "Test")

        handler.saveSnapshot(actionName: "Add Scene")
        AppSettings.shared.menuItems.append(.scene(scene))

        XCTAssertEqual(AppSettings.shared.menuItems.count, 1)

        undoManager.undo()

        XCTAssertEqual(AppSettings.shared.menuItems.count, 0, "Undo should remove the added scene")
    }

    // MARK: - Redo Add Scene

    func testRedoAddScene() {
        let scene = SceneItem(entityId: "scene.test", emoji: "🔴", displayName: "Test")

        handler.saveSnapshot(actionName: "Add Scene")
        AppSettings.shared.menuItems.append(.scene(scene))

        undoManager.undo()
        XCTAssertEqual(AppSettings.shared.menuItems.count, 0)

        undoManager.redo()
        XCTAssertEqual(AppSettings.shared.menuItems.count, 1, "Redo should restore the added scene")
        if case .scene(let restored) = AppSettings.shared.menuItems.first {
            XCTAssertEqual(restored.entityId, "scene.test")
        } else {
            XCTFail("Expected a .scene item after redo")
        }
    }

    // MARK: - Undo Remove Scene

    func testUndoRemoveScene() {
        let scene = SceneItem(entityId: "scene.busy", emoji: "🔴", displayName: "Busy")
        AppSettings.shared.menuItems = [.scene(scene)]

        handler.saveSnapshot(actionName: "Remove Item")
        AppSettings.shared.menuItems.removeAll()

        XCTAssertTrue(AppSettings.shared.menuItems.isEmpty)

        undoManager.undo()

        XCTAssertEqual(AppSettings.shared.menuItems.count, 1, "Undo should restore the removed scene")
        if case .scene(let restored) = AppSettings.shared.menuItems.first {
            XCTAssertEqual(restored.entityId, "scene.busy")
            XCTAssertEqual(restored.emoji, "🔴")
        } else {
            XCTFail("Expected a .scene item after undo")
        }
    }

    // MARK: - Undo Reorder

    func testUndoReorder() {
        let sceneA = SceneItem(entityId: "scene.a", emoji: "🅰️", displayName: "A")
        let sceneB = SceneItem(entityId: "scene.b", emoji: "🅱️", displayName: "B")
        AppSettings.shared.menuItems = [.scene(sceneA), .scene(sceneB)]

        handler.saveSnapshot(actionName: "Reorder")
        AppSettings.shared.menuItems.move(fromOffsets: IndexSet(integer: 1), toOffset: 0)

        // After move: B, A
        if case .scene(let first) = AppSettings.shared.menuItems[0] {
            XCTAssertEqual(first.entityId, "scene.b")
        }

        undoManager.undo()

        // After undo: A, B (original order)
        if case .scene(let first) = AppSettings.shared.menuItems[0] {
            XCTAssertEqual(first.entityId, "scene.a", "Undo should restore original order")
        } else {
            XCTFail("Expected a .scene item at index 0")
        }
    }

    // MARK: - Undo Change Emoji

    func testUndoChangeEmoji() {
        let scene = SceneItem(entityId: "scene.test", emoji: "🔴", displayName: "Test")
        AppSettings.shared.menuItems = [.scene(scene)]

        handler.saveSnapshot(actionName: "Change Emoji")
        if case .scene(var s) = AppSettings.shared.menuItems[0] {
            s.emoji = "🟢"
            AppSettings.shared.menuItems[0] = .scene(s)
        }

        if case .scene(let modified) = AppSettings.shared.menuItems[0] {
            XCTAssertEqual(modified.emoji, "🟢")
        }

        undoManager.undo()

        if case .scene(let restored) = AppSettings.shared.menuItems[0] {
            XCTAssertEqual(restored.emoji, "🔴", "Undo should restore original emoji")
        } else {
            XCTFail("Expected a .scene item after undo")
        }
    }

    // MARK: - Undo Change Name

    func testUndoChangeName() {
        let scene = SceneItem(entityId: "scene.test", emoji: "🔴", displayName: "Old Name")
        AppSettings.shared.menuItems = [.scene(scene)]

        handler.saveSnapshot(actionName: "Change Name")
        if case .scene(var s) = AppSettings.shared.menuItems[0] {
            s.displayName = "New Name"
            AppSettings.shared.menuItems[0] = .scene(s)
        }

        undoManager.undo()

        if case .scene(let restored) = AppSettings.shared.menuItems[0] {
            XCTAssertEqual(restored.displayName, "Old Name", "Undo should restore original name")
        } else {
            XCTFail("Expected a .scene item after undo")
        }
    }

    // MARK: - Undo Keyboard Shortcut Change

    func testUndoSetShortcut() {
        AppSettings.shared.keyboardShortcuts = []

        handler.saveSnapshot(actionName: "Set Shortcut")
        AppSettings.shared.keyboardShortcuts = [
            KeyboardShortcutConfig(keyCode: 18, modifiers: 1_048_840, sceneEntityId: "scene.test")
        ]

        XCTAssertEqual(AppSettings.shared.keyboardShortcuts.count, 1)

        undoManager.undo()

        XCTAssertTrue(AppSettings.shared.keyboardShortcuts.isEmpty, "Undo should remove the shortcut")
    }

    // MARK: - Undo Restores Both menuItems and Shortcuts

    func testUndoRestoresBothMenuItemsAndShortcuts() {
        let scene = SceneItem(entityId: "scene.test", emoji: "🔴", displayName: "Test")
        AppSettings.shared.menuItems = [.scene(scene)]
        AppSettings.shared.keyboardShortcuts = [
            KeyboardShortcutConfig(keyCode: 18, modifiers: 1_048_840, sceneEntityId: "scene.test")
        ]

        handler.saveSnapshot(actionName: "Remove Item")
        AppSettings.shared.menuItems = []
        AppSettings.shared.keyboardShortcuts = []

        undoManager.undo()

        XCTAssertEqual(AppSettings.shared.menuItems.count, 1,
                       "Undo should restore menuItems")
        XCTAssertEqual(AppSettings.shared.keyboardShortcuts.count, 1,
                       "Undo should restore keyboard shortcuts")
    }

    // MARK: - Multiple Undo Steps

    func testMultipleUndoSteps() {
        // Disable auto-grouping so we can simulate separate user events.
        // In production, groupsByEvent is true and each click/drag is a
        // separate event that naturally creates its own undo group.
        undoManager.groupsByEvent = false

        // Step 1: add scene A
        undoManager.beginUndoGrouping()
        handler.saveSnapshot(actionName: "Add Scene")
        let sceneA = SceneItem(entityId: "scene.a", emoji: "🅰️", displayName: "A")
        AppSettings.shared.menuItems.append(.scene(sceneA))
        undoManager.endUndoGrouping()

        // Step 2: add scene B
        undoManager.beginUndoGrouping()
        handler.saveSnapshot(actionName: "Add Scene")
        let sceneB = SceneItem(entityId: "scene.b", emoji: "🅱️", displayName: "B")
        AppSettings.shared.menuItems.append(.scene(sceneB))
        undoManager.endUndoGrouping()

        XCTAssertEqual(AppSettings.shared.menuItems.count, 2)

        // Undo step 2 → only scene A
        undoManager.undo()
        XCTAssertEqual(AppSettings.shared.menuItems.count, 1)

        // Undo step 1 → empty
        undoManager.undo()
        XCTAssertEqual(AppSettings.shared.menuItems.count, 0)

        // Redo step 1 → scene A
        undoManager.redo()
        XCTAssertEqual(AppSettings.shared.menuItems.count, 1)

        // Redo step 2 → scenes A and B
        undoManager.redo()
        XCTAssertEqual(AppSettings.shared.menuItems.count, 2)
    }

    // MARK: - Action Names

    func testActionName() {
        handler.saveSnapshot(actionName: "Add Scene")
        AppSettings.shared.menuItems.append(.scene(
            SceneItem(entityId: "scene.test", emoji: "🔴", displayName: "Test")))

        XCTAssertEqual(undoManager.undoActionName, "Add Scene")
    }

    // MARK: - Add Divider

    func testUndoAddDivider() {
        handler.saveSnapshot(actionName: "Add Divider")
        AppSettings.shared.menuItems.append(.newDivider())

        XCTAssertEqual(AppSettings.shared.menuItems.count, 1)

        undoManager.undo()

        XCTAssertTrue(AppSettings.shared.menuItems.isEmpty, "Undo should remove the added divider")
    }

    // MARK: - No UndoManager (nil safety)

    func testSaveSnapshotWithNilUndoManager() {
        let handlerWithoutUM = SceneUndoHandler()
        // undoManager is nil — should not crash
        handlerWithoutUM.saveSnapshot(actionName: "Test")
        AppSettings.shared.menuItems.append(.scene(
            SceneItem(entityId: "scene.test", emoji: "🔴", displayName: "Test")))
        XCTAssertEqual(AppSettings.shared.menuItems.count, 1)
    }
}
