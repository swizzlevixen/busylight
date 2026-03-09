import XCTest
@testable import BusyLight

final class MenuListItemTests: XCTestCase {

    func testSceneItemId() {
        let scene = SceneItem(entityId: "scene.test", displayName: "Test")
        let item = MenuListItem.scene(scene)
        XCTAssertEqual(item.id, scene.id.uuidString)
    }

    func testDividerItemId() {
        let divId = UUID()
        let item = MenuListItem.divider(id: divId)
        XCTAssertEqual(item.id, "divider-\(divId.uuidString)")
    }

    func testNewDivider() {
        let divider1 = MenuListItem.newDivider()
        let divider2 = MenuListItem.newDivider()
        XCTAssertNotEqual(divider1.id, divider2.id) // Unique IDs
    }

    func testSceneItemAccessor() {
        let scene = SceneItem(entityId: "scene.test", displayName: "Test")
        let item = MenuListItem.scene(scene)
        XCTAssertNotNil(item.sceneItem)
        XCTAssertEqual(item.sceneItem?.entityId, "scene.test")
    }

    func testDividerSceneItemAccessorReturnsNil() {
        let item = MenuListItem.newDivider()
        XCTAssertNil(item.sceneItem)
    }

    func testCodableRoundtripScene() throws {
        let scene = SceneItem(entityId: "scene.test", emoji: "🔴", displayName: "Busy")
        let item = MenuListItem.scene(scene)

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(MenuListItem.self, from: data)

        XCTAssertEqual(item.id, decoded.id)
        if case .scene(let decodedScene) = decoded {
            XCTAssertEqual(decodedScene.entityId, "scene.test")
            XCTAssertEqual(decodedScene.emoji, "🔴")
        } else {
            XCTFail("Expected scene, got divider")
        }
    }

    func testCodableRoundtripDivider() throws {
        let divId = UUID()
        let item = MenuListItem.divider(id: divId)

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(MenuListItem.self, from: data)

        XCTAssertEqual(item.id, decoded.id)
        if case .divider(let decodedId) = decoded {
            XCTAssertEqual(decodedId, divId)
        } else {
            XCTFail("Expected divider, got scene")
        }
    }

    func testCodableRoundtripArray() throws {
        let items: [MenuListItem] = [
            .scene(SceneItem(entityId: "scene.busy", emoji: "🔴", displayName: "Busy")),
            .newDivider(),
            .scene(SceneItem(entityId: "scene.free", emoji: "🟢", displayName: "Free")),
        ]

        let data = try JSONEncoder().encode(items)
        let decoded = try JSONDecoder().decode([MenuListItem].self, from: data)

        XCTAssertEqual(decoded.count, 3)
        XCTAssertNotNil(decoded[0].sceneItem)
        XCTAssertNil(decoded[1].sceneItem)
        XCTAssertNotNil(decoded[2].sceneItem)
    }

    func testHashable() {
        let scene = SceneItem(entityId: "scene.test", displayName: "Test")
        let item1 = MenuListItem.scene(scene)
        let item2 = MenuListItem.scene(scene)
        XCTAssertEqual(item1, item2)
    }
}
