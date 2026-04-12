import XCTest
@testable import BusyLight

@MainActor
final class TriggerManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        KeychainHelper.testStore = [:]
    }

    override func tearDown() {
        KeychainHelper.testStore = nil
        super.tearDown()
    }

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

    func testConnectionStateEquality() {
        XCTAssertEqual(ConnectionState.connected, ConnectionState.connected)
        XCTAssertEqual(ConnectionState.disconnected, ConnectionState.disconnected)
        XCTAssertEqual(ConnectionState.unknown, ConnectionState.unknown)
        XCTAssertEqual(ConnectionState.error("test"), ConnectionState.error("test"))
        XCTAssertNotEqual(ConnectionState.connected, ConnectionState.disconnected)
        XCTAssertNotEqual(ConnectionState.error("a"), ConnectionState.error("b"))
    }
}
