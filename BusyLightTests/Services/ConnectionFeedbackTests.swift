import XCTest
@testable import BusyLight

// MARK: - AppSettings connection state tests

@MainActor
final class ConnectionFeedbackTests: XCTestCase {

    private let scene = SceneItem(entityId: "scene.test", emoji: "🔴", displayName: "Busy")

    override func setUp() {
        super.setUp()
        KeychainHelper.testStore = [:]
        let settings = AppSettings.shared
        settings.displayMode = .both
        settings.menuItems = []
        settings.activeSceneId = nil
        settings.connectionState = .unknown
    }

    override func tearDown() {
        AppSettings.shared.connectionState = .unknown
        KeychainHelper.testStore = nil
        super.tearDown()
    }

    // MARK: - isDisconnected

    func testIsDisconnectedWhenUnknown() {
        AppSettings.shared.connectionState = .unknown
        XCTAssertFalse(AppSettings.shared.isDisconnected)
    }

    func testIsDisconnectedWhenConnected() {
        AppSettings.shared.connectionState = .connected
        XCTAssertFalse(AppSettings.shared.isDisconnected)
    }

    func testIsDisconnectedWhenDisconnected() {
        AppSettings.shared.connectionState = .disconnected
        XCTAssertTrue(AppSettings.shared.isDisconnected)
    }

    func testIsDisconnectedWhenError() {
        AppSettings.shared.connectionState = .error("test error")
        XCTAssertTrue(AppSettings.shared.isDisconnected)
    }

    // MARK: - Menu bar label with warning

    func testMenuBarLabelNoWarningWhenConnected() {
        AppSettings.shared.connectionState = .connected
        AppSettings.shared.displayMode = .both
        AppSettings.shared.activeSceneId = nil
        XCTAssertEqual(AppSettings.shared.menuBarLabel, "🚦 Busy Light")
    }

    func testMenuBarLabelWarningWhenDisconnected() {
        AppSettings.shared.connectionState = .disconnected
        AppSettings.shared.displayMode = .both
        AppSettings.shared.activeSceneId = nil
        XCTAssertTrue(AppSettings.shared.menuBarLabel.contains("⚠️"))
    }

    func testMenuBarLabelWarningWhenError() {
        AppSettings.shared.connectionState = .error("timeout")
        AppSettings.shared.displayMode = .both
        AppSettings.shared.menuItems = [.scene(scene)]
        AppSettings.shared.activeSceneId = scene.entityId
        XCTAssertTrue(AppSettings.shared.menuBarLabel.contains("⚠️"))
        XCTAssertTrue(AppSettings.shared.menuBarLabel.contains("🔴"))
    }

    func testNoSceneLabelWarningWhenDisconnected() {
        AppSettings.shared.connectionState = .disconnected
        AppSettings.shared.displayMode = .nameOnly
        XCTAssertTrue(AppSettings.shared.noSceneLabel.contains("⚠️"))
    }

    func testNoSceneLabelNoWarningWhenConnected() {
        AppSettings.shared.connectionState = .connected
        AppSettings.shared.displayMode = .nameOnly
        XCTAssertEqual(AppSettings.shared.noSceneLabel, "Busy Light")
    }

    // MARK: - Warning clears on reconnect

    func testWarningClearsWhenConnectionRestored() {
        AppSettings.shared.connectionState = .disconnected
        AppSettings.shared.displayMode = .both
        XCTAssertTrue(AppSettings.shared.menuBarLabel.contains("⚠️"))

        AppSettings.shared.connectionState = .connected
        XCTAssertFalse(AppSettings.shared.menuBarLabel.contains("⚠️"))
    }
}

// MARK: - HomeAssistantService notification tests

final class ConnectionStateNotificationTests: XCTestCase {
    var service: HomeAssistantService!
    var session: URLSession!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        service = HomeAssistantService(session: session)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testNotificationPostedOnConnectionSuccess() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = #"{"message": "API running."}"#.data(using: .utf8)!
            return (response, data)
        }

        let expectation = XCTNSNotificationExpectation(
            name: .haConnectionStateChanged,
            object: nil
        )

        _ = try await service.testConnection(baseURL: "http://localhost:8123", token: "token")

        await fulfillment(of: [expectation], timeout: 2)
    }

    func testNotificationPostedOnNetworkError() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let expectation = XCTNSNotificationExpectation(
            name: .haConnectionStateChanged,
            object: nil
        )

        _ = await service.activateScene(
            entityId: "scene.test",
            baseURL: "http://localhost:8123",
            token: "token"
        )

        await fulfillment(of: [expectation], timeout: 2)
    }

    func testNoNotificationOnDuplicateState() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = #"{"message": "API running."}"#.data(using: .utf8)!
            return (response, data)
        }

        // First call sets state to .connected — should post
        _ = try await service.testConnection(baseURL: "http://localhost:8123", token: "token")

        // Second call with same state — should NOT post
        let expectation = XCTNSNotificationExpectation(
            name: .haConnectionStateChanged,
            object: nil
        )
        expectation.isInverted = true

        _ = try await service.testConnection(baseURL: "http://localhost:8123", token: "token")

        await fulfillment(of: [expectation], timeout: 1)
    }
}
