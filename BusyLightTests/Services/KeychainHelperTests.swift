import XCTest
@testable import BusyLight

final class KeychainHelperTests: XCTestCase {
    private let testKey = "com.mboszko.BusyLightTests.keychainTest"

    override func setUp() {
        super.setUp()
        KeychainHelper.testStore = [:]
    }

    override func tearDown() {
        KeychainHelper.testStore = nil
        super.tearDown()
    }

    func testSaveAndLoad() {
        KeychainHelper.save(key: testKey, value: "test-token-123")
        let loaded = KeychainHelper.load(key: testKey)
        XCTAssertEqual(loaded, "test-token-123")
    }

    func testLoadNonExistent() {
        let loaded = KeychainHelper.load(key: "com.mboszko.nonexistent")
        XCTAssertNil(loaded)
    }

    func testDelete() {
        KeychainHelper.save(key: testKey, value: "to-delete")
        XCTAssertNotNil(KeychainHelper.load(key: testKey))

        KeychainHelper.delete(key: testKey)
        XCTAssertNil(KeychainHelper.load(key: testKey))
    }

    func testUpdate() {
        KeychainHelper.save(key: testKey, value: "original")
        XCTAssertEqual(KeychainHelper.load(key: testKey), "original")

        KeychainHelper.update(key: testKey, value: "updated")
        XCTAssertEqual(KeychainHelper.load(key: testKey), "updated")
    }

    func testSaveOverwrites() {
        KeychainHelper.save(key: testKey, value: "first")
        KeychainHelper.save(key: testKey, value: "second")
        XCTAssertEqual(KeychainHelper.load(key: testKey), "second")
    }

    func testSaveEmptyStringDeletes() {
        KeychainHelper.save(key: testKey, value: "existing")
        XCTAssertNotNil(KeychainHelper.load(key: testKey))

        KeychainHelper.save(key: testKey, value: "")
        XCTAssertNil(KeychainHelper.load(key: testKey))
    }

    func testSpecialCharacters() {
        let specialValue = "token-with-special/chars+and=symbols&more"
        KeychainHelper.save(key: testKey, value: specialValue)
        XCTAssertEqual(KeychainHelper.load(key: testKey), specialValue)
    }

    func testLongValue() {
        let longValue = String(repeating: "a", count: 10000)
        KeychainHelper.save(key: testKey, value: longValue)
        XCTAssertEqual(KeychainHelper.load(key: testKey), longValue)
    }
}
