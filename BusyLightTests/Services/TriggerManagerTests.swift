import XCTest
@testable import BusyLight

@MainActor
final class TriggerManagerTests: XCTestCase {

    func testStartStopMonitors() {
        let manager = TriggerManager.shared
        manager.startAllMonitors()
        manager.stopAllMonitors()
    }

    func testCameraNotificationName() {
        XCTAssertEqual(Notification.Name.cameraStateChanged.rawValue, "BusyLight.cameraStateChanged")
    }

    func testMicrophoneNotificationName() {
        XCTAssertEqual(Notification.Name.microphoneStateChanged.rawValue, "BusyLight.microphoneStateChanged")
    }

    func testScreenLockNotificationName() {
        XCTAssertEqual(Notification.Name.screenLockStateChanged.rawValue, "BusyLight.screenLockStateChanged")
    }

    func testFocusModeNotificationName() {
        XCTAssertEqual(Notification.Name.focusModeChanged.rawValue, "BusyLight.focusModeChanged")
    }

    // MARK: - Revert Scene behavior

    override func tearDown() {
        TriggerManager.shared.stopAllMonitors()
        let settings = AppSettings.shared
        settings.activeSceneId = nil
        settings.webcamTriggerEnabled = false
        settings.webcamOnSceneId = ""
        settings.webcamOffTriggerEnabled = false
        settings.webcamOffSceneId = ""
        super.tearDown()
    }

    /// Helper: post a camera state notification and let observers process it.
    private func postCameraChange(isOn: Bool) async {
        NotificationCenter.default.post(
            name: .cameraStateChanged,
            object: nil,
            userInfo: ["isOn": isOn]
        )
        // Yield to let the notification observer's Task run
        await Task.yield()
        await Task.yield()
    }

    func testRevertSceneNormalBehavior() async {
        let settings = AppSettings.shared
        settings.webcamTriggerEnabled = true
        settings.webcamOnSceneId = "scene.busy"
        settings.webcamOffTriggerEnabled = true
        settings.webcamOffSceneId = AppSettings.revertSceneId
        settings.activeSceneId = "scene.free"

        TriggerManager.shared.startAllMonitors()

        // Camera on → trigger activates "Busy"
        await postCameraChange(isOn: true)
        XCTAssertEqual(settings.activeSceneId, "scene.busy")

        // Camera off → revert to "Free"
        await postCameraChange(isOn: false)
        XCTAssertEqual(settings.activeSceneId, "scene.free",
                       "Should revert to pre-trigger scene when no manual change occurred")
    }

    func testRevertSceneRespectsManualChange() async {
        let settings = AppSettings.shared
        settings.webcamTriggerEnabled = true
        settings.webcamOnSceneId = "scene.busy"
        settings.webcamOffTriggerEnabled = true
        settings.webcamOffSceneId = AppSettings.revertSceneId
        settings.activeSceneId = "scene.free"

        TriggerManager.shared.startAllMonitors()

        // Camera on → trigger activates "Busy"
        await postCameraChange(isOn: true)
        XCTAssertEqual(settings.activeSceneId, "scene.busy")

        // User manually changes scene
        MenuBarManager.shared.activateScene(entityId: "scene.concentrating")
        XCTAssertEqual(settings.activeSceneId, "scene.concentrating")

        // Camera off → revert should keep "Concentrating", not go back to "Free"
        await postCameraChange(isOn: false)
        XCTAssertEqual(settings.activeSceneId, "scene.concentrating",
                       "Should keep user's manual choice, not revert to stale pre-trigger scene")
    }

    func testRevertSceneRespectsMultipleManualChanges() async {
        let settings = AppSettings.shared
        settings.webcamTriggerEnabled = true
        settings.webcamOnSceneId = "scene.busy"
        settings.webcamOffTriggerEnabled = true
        settings.webcamOffSceneId = AppSettings.revertSceneId
        settings.activeSceneId = "scene.free"

        TriggerManager.shared.startAllMonitors()

        // Camera on → trigger activates "Busy"
        await postCameraChange(isOn: true)

        // User changes scene twice
        MenuBarManager.shared.activateScene(entityId: "scene.concentrating")
        MenuBarManager.shared.activateScene(entityId: "scene.available")

        // Camera off → should stay on last manual choice
        await postCameraChange(isOn: false)
        XCTAssertEqual(settings.activeSceneId, "scene.available",
                       "Should keep user's last manual choice")
    }

    func testConnectionStateEquality() {
        XCTAssertEqual(ConnectionState.connected, ConnectionState.connected)
        XCTAssertEqual(ConnectionState.disconnected, ConnectionState.disconnected)
        XCTAssertEqual(ConnectionState.unknown, ConnectionState.unknown)
        XCTAssertEqual(ConnectionState.error("test"), ConnectionState.error("test"))
        XCTAssertNotEqual(ConnectionState.connected, ConnectionState.disconnected)
        XCTAssertNotEqual(ConnectionState.error("a"), ConnectionState.error("b"))
    }
}
