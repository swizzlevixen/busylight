import XCTest
@testable import BusyLight

@MainActor
final class CameraMonitorTests: XCTestCase {

    func testInitialState() {
        let monitor = CameraMonitor.shared
        // Camera should not be on by default in test environment
        // (unless some process has it open, which is a valid state)
        // We just test that accessing the property doesn't crash
        _ = monitor.isCameraOn
    }

    func testNotificationPosted() {
        let expectation = XCTestExpectation(description: "Camera state change notification")
        expectation.isInverted = true // We don't expect it since camera state won't change in tests

        let observer = NotificationCenter.default.addObserver(
            forName: .cameraStateChanged,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        // Just verify the notification name exists and observer can be added
        wait(for: [expectation], timeout: 0.5)

        NotificationCenter.default.removeObserver(observer)
    }

    func testStartStopMonitoring() {
        let monitor = CameraMonitor.shared
        monitor.startMonitoring()
        // Starting again should be a no-op (guard check)
        monitor.startMonitoring()
        monitor.stopMonitoring()
        // Stopping again should be safe
        monitor.stopMonitoring()
    }
}
