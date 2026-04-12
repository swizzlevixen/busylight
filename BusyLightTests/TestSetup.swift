import XCTest
@testable import BusyLight

/// Runs before any test class setUp — enables the in-memory keychain
/// store so the app host process doesn't trigger a Keychain dialog
/// when `TriggerManager.startAllMonitors()` reads `AppSettings.haToken`.
final class TestSetup: NSObject {
    override init() {
        KeychainHelper.testStore = [:]
        super.init()
    }
}
