import XCTest
@testable import BusyLight

@MainActor
final class MicrophoneMonitorTests: XCTestCase {

    func testInitialState() {
        let monitor = MicrophoneMonitor.shared
        _ = monitor.isMicrophoneOn
    }

    func testNotificationPosted() {
        let expectation = XCTestExpectation(description: "Mic state change notification")
        expectation.isInverted = true

        let observer = NotificationCenter.default.addObserver(
            forName: .microphoneStateChanged,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 0.5)
        NotificationCenter.default.removeObserver(observer)
    }

    func testStartStopMonitoring() {
        let monitor = MicrophoneMonitor.shared
        monitor.startMonitoring()
        monitor.startMonitoring() // No-op
        monitor.stopMonitoring()
        monitor.stopMonitoring() // Safe
    }
}
