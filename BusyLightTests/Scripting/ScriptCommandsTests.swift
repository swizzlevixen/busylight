import XCTest
@testable import BusyLight

@MainActor
final class ScriptCommandsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        KeychainHelper.testStore = [:]
        // Reset state
        AppSettings.shared.activeSceneId = nil
        AppSettings.shared.menuItems = [
            .scene(SceneItem(entityId: "scene.test", emoji: "🔴", displayName: "Test")),
            .scene(SceneItem(entityId: "scene.other", emoji: "🟢", displayName: "Other")),
        ]
    }

    override func tearDown() {
        AppSettings.shared.activeSceneId = nil
        AppSettings.shared.menuItems = []
        KeychainHelper.testStore = nil
        super.tearDown()
    }

    func testScenesComputedProperty() {
        XCTAssertEqual(AppSettings.shared.scenes.count, 2)
        XCTAssertEqual(AppSettings.shared.scenes[0].entityId, "scene.test")
        XCTAssertEqual(AppSettings.shared.scenes[1].entityId, "scene.other")
    }

    func testActiveSceneIdPersistence() {
        AppSettings.shared.activeSceneId = "scene.test"
        XCTAssertEqual(AppSettings.shared.activeSceneId, "scene.test")

        AppSettings.shared.activeSceneId = nil
        XCTAssertNil(AppSettings.shared.activeSceneId)
    }

    func testDisplayModePersistence() {
        AppSettings.shared.displayMode = .emojiOnly
        XCTAssertEqual(AppSettings.shared.displayMode, .emojiOnly)

        AppSettings.shared.displayMode = .nameOnly
        XCTAssertEqual(AppSettings.shared.displayMode, .nameOnly)

        AppSettings.shared.displayMode = .both
        XCTAssertEqual(AppSettings.shared.displayMode, .both)
    }

    func testHAErrorDescriptions() {
        let errors: [(HomeAssistantService.HAError, String)] = [
            (.invalidURL, "Invalid Home Assistant URL"),
            (.unauthorized, "Invalid or expired access token"),
            (.notConfigured, "Home Assistant connection not configured"),
        ]

        for (error, expected) in errors {
            XCTAssertEqual(error.errorDescription, expected)
        }
    }

    func testHAErrorNetworkDescription() {
        let error = HomeAssistantService.HAError.networkError(URLError(.notConnectedToInternet))
        XCTAssertTrue(error.errorDescription?.contains("Network error") ?? false)
    }

    func testHAErrorServerDescription() {
        let error = HomeAssistantService.HAError.serverError(500, "Internal Server Error")
        XCTAssertTrue(error.errorDescription?.contains("500") ?? false)
    }
}
