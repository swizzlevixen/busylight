import XCTest
@testable import BusyLight

// MARK: - Mock URL Protocol

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Tests

final class HomeAssistantServiceTests: XCTestCase {
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

    // MARK: - Test Connection

    func testTestConnectionSuccess() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url?.absoluteString.contains("/api/") ?? false)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = #"{"message": "API running."}"#.data(using: .utf8)!
            return (response, data)
        }

        let result = try await service.testConnection(baseURL: "http://localhost:8123", token: "test-token")
        XCTAssertTrue(result)
    }

    func testTestConnectionUnauthorized() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            _ = try await service.testConnection(baseURL: "http://localhost:8123", token: "bad-token")
            XCTFail("Should have thrown")
        } catch {
            XCTAssertTrue(error is HomeAssistantService.HAError)
        }
    }

    func testTestConnectionInvalidURL() async {
        // Empty base URL results in a network error since URL("/api/") is technically valid but not reachable
        do {
            _ = try await service.testConnection(baseURL: "not a valid url with spaces", token: "token")
            XCTFail("Should have thrown")
        } catch {
            // Should throw either invalidURL or networkError
            XCTAssertTrue(error is HomeAssistantService.HAError)
        }
    }

    // MARK: - Fetch Scenes

    func testFetchScenes() async throws {
        let statesJSON = """
        [
            {"entity_id": "scene.movie_night", "state": "2024-01-01T00:00:00", "attributes": {"friendly_name": "Movie Night"}},
            {"entity_id": "scene.office_busy", "state": "2024-01-01T00:00:00", "attributes": {"friendly_name": "Office Busy"}},
            {"entity_id": "light.living_room", "state": "on", "attributes": {"friendly_name": "Living Room Light"}},
            {"entity_id": "scene.relax", "state": "2024-01-01T00:00:00", "attributes": {}}
        ]
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/states")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, statesJSON)
        }

        let scenes = try await service.fetchScenes(baseURL: "http://localhost:8123", token: "token")
        XCTAssertEqual(scenes.count, 3) // Only scene.* entities
        XCTAssertEqual(scenes[0].entityId, "scene.movie_night")
        XCTAssertEqual(scenes[0].friendlyName, "Movie Night")
        XCTAssertEqual(scenes[1].entityId, "scene.office_busy")
        XCTAssertEqual(scenes[2].entityId, "scene.relax")
        XCTAssertEqual(scenes[2].friendlyName, "scene.relax") // Falls back to entity_id when no friendly_name
    }

    // MARK: - Activate Scene

    func testActivateSceneSuccess() async {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/services/scene/turn_on")
            XCTAssertEqual(request.httpMethod, "POST")

            // Verify body
            if let body = request.httpBody {
                let dict = try? JSONSerialization.jsonObject(with: body) as? [String: String]
                XCTAssertEqual(dict?["entity_id"], "scene.test")
            }

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = "[]".data(using: .utf8)!
            return (response, data)
        }

        let result = await service.activateScene(
            entityId: "scene.test",
            baseURL: "http://localhost:8123",
            token: "token"
        )
        XCTAssertTrue(result.success)
    }

    func testActivateSceneWithAffectedEntities() async {
        let responseJSON = """
        [
            {"entity_id": "light.desk", "state": "on", "attributes": {"friendly_name": "Desk Light"}},
            {"entity_id": "light.overhead", "state": "off", "attributes": {"friendly_name": "Overhead"}}
        ]
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, responseJSON)
        }

        let result = await service.activateScene(
            entityId: "scene.test",
            baseURL: "http://localhost:8123",
            token: "token"
        )
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.affectedEntities.count, 2)
        XCTAssertTrue(result.affectedEntities.contains("light.desk"))
    }

    func testActivateSceneNetworkError() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let result = await service.activateScene(
            entityId: "scene.test",
            baseURL: "http://localhost:8123",
            token: "token"
        )
        XCTAssertFalse(result.success)
        XCTAssertNotNil(result.error)
    }

    // MARK: - URL Handling

    func testURLTrailingSlashHandling() async throws {
        MockURLProtocol.requestHandler = { request in
            // Should not have double slashes
            XCTAssertFalse(request.url!.absoluteString.contains("//api"))
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = #"{"message": "API running."}"#.data(using: .utf8)!
            return (response, data)
        }

        _ = try await service.testConnection(baseURL: "http://localhost:8123/", token: "token")
    }

    // MARK: - Connection State

    func testConnectionStateAfterSuccess() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = #"{"message": "API running."}"#.data(using: .utf8)!
            return (response, data)
        }

        _ = try await service.testConnection(baseURL: "http://localhost:8123", token: "token")
        let state = await service.connectionState
        XCTAssertEqual(state, .connected)
    }

    func testConnectionStateAfterNetworkError() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        _ = await service.activateScene(entityId: "scene.test", baseURL: "http://localhost:8123", token: "token")
        let state = await service.connectionState
        XCTAssertEqual(state, .disconnected)
    }

    // MARK: - HAScene

    func testHASceneIdentifiable() {
        let scene = HAScene(entityId: "scene.test", friendlyName: "Test")
        XCTAssertEqual(scene.id, "scene.test")
        XCTAssertEqual(scene.entityId, "scene.test")
    }

    // MARK: - SceneActivationResult

    func testSceneActivationResultSuccess() {
        let result = SceneActivationResult.success(entities: ["light.desk"])
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.affectedEntities, ["light.desk"])
        XCTAssertNil(result.error)
    }

    func testSceneActivationResultFailure() {
        let result = SceneActivationResult.failure(URLError(.timedOut))
        XCTAssertFalse(result.success)
        XCTAssertTrue(result.affectedEntities.isEmpty)
        XCTAssertNotNil(result.error)
    }
}
