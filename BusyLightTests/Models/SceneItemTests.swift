import XCTest
@testable import BusyLight

final class SceneItemTests: XCTestCase {

    func testInitialization() {
        let scene = SceneItem(entityId: "scene.test", emoji: "🔴", displayName: "Test Scene")
        XCTAssertEqual(scene.entityId, "scene.test")
        XCTAssertEqual(scene.emoji, "🔴")
        XCTAssertEqual(scene.displayName, "Test Scene")
        XCTAssertNotNil(scene.id)
    }

    func testDefaultEmoji() {
        let scene = SceneItem(entityId: "scene.default", displayName: "Default")
        XCTAssertEqual(scene.emoji, "🎬")
    }

    func testCodableRoundtrip() throws {
        let original = SceneItem(entityId: "scene.office", emoji: "🟢", displayName: "Available")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SceneItem.self, from: data)

        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.entityId, decoded.entityId)
        XCTAssertEqual(original.emoji, decoded.emoji)
        XCTAssertEqual(original.displayName, decoded.displayName)
    }

    func testEquality() {
        let id = UUID()
        let scene1 = SceneItem(id: id, entityId: "scene.test", emoji: "🔴", displayName: "Test")
        let scene2 = SceneItem(id: id, entityId: "scene.test", emoji: "🔴", displayName: "Test")
        XCTAssertEqual(scene1, scene2)
    }

    func testInequality() {
        let scene1 = SceneItem(entityId: "scene.test", emoji: "🔴", displayName: "Test")
        let scene2 = SceneItem(entityId: "scene.test", emoji: "🔴", displayName: "Test")
        XCTAssertNotEqual(scene1, scene2) // Different UUIDs
    }

    func testHashable() {
        let scene = SceneItem(entityId: "scene.test", displayName: "Test")
        var set: Set<SceneItem> = []
        set.insert(scene)
        set.insert(scene)
        XCTAssertEqual(set.count, 1)
    }

    func testMutability() {
        var scene = SceneItem(entityId: "scene.test", emoji: "🔴", displayName: "Test")
        scene.emoji = "🟢"
        scene.displayName = "Updated"
        XCTAssertEqual(scene.emoji, "🟢")
        XCTAssertEqual(scene.displayName, "Updated")
    }
}
