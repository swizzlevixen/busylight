import Foundation

/// Raw state object from GET /api/states
struct HAStateObject: Decodable, Sendable {
    let entity_id: String
    let state: String
    let attributes: HAAttributes
}

struct HAAttributes: Decodable, Sendable {
    let friendly_name: String?
}

/// Parsed scene from Home Assistant
struct HAScene: Identifiable, Hashable, Sendable {
    let id: String
    let entityId: String
    let friendlyName: String

    init(entityId: String, friendlyName: String) {
        self.id = entityId
        self.entityId = entityId
        self.friendlyName = friendlyName
    }
}

/// Result of activating a scene
struct SceneActivationResult: Sendable {
    let success: Bool
    let affectedEntities: [String]
    let error: (any Error)?

    static func success(entities: [String]) -> SceneActivationResult {
        SceneActivationResult(success: true, affectedEntities: entities, error: nil)
    }

    static func failure(_ error: any Error) -> SceneActivationResult {
        SceneActivationResult(success: false, affectedEntities: [], error: error)
    }
}

/// Connection state for UI observation
enum ConnectionState: Sendable, Equatable {
    case unknown
    case connected
    case disconnected
    case error(String)

    static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown), (.connected, .connected), (.disconnected, .disconnected):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

actor HomeAssistantService {
    static let shared = HomeAssistantService()

    private let session: URLSession
    private var healthCheckTask: Task<Void, Never>?
    private var healthCheckGeneration: Int = 0

    private(set) var connectionState: ConnectionState = .unknown

    enum HAError: LocalizedError {
        case invalidURL
        case unauthorized
        case networkError(any Error)
        case decodingError(any Error)
        case serverError(Int, String)
        case notConfigured

        var errorDescription: String? {
            switch self {
            case .invalidURL: "Invalid Home Assistant URL"
            case .unauthorized: "Invalid or expired access token"
            case .networkError(let e): "Network error: \(e.localizedDescription)"
            case .decodingError(let e): "Data error: \(e.localizedDescription)"
            case .serverError(let code, let msg): "Server error \(code): \(msg)"
            case .notConfigured: "Home Assistant connection not configured"
            }
        }
    }

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Health Check

    func startHealthChecks(baseURL: String, token: String) {
        stopHealthChecks()
        healthCheckGeneration += 1
        let myGeneration = healthCheckGeneration
        healthCheckTask = Task {
            while !Task.isCancelled {
                do {
                    _ = try await self.testConnection(baseURL: baseURL, token: token)
                } catch {
                    self.connectionState = .disconnected
                }
                // Exit if a newer health check loop has started
                guard myGeneration == self.healthCheckGeneration else { break }
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    func stopHealthChecks() {
        healthCheckGeneration += 1
        healthCheckTask?.cancel()
        healthCheckTask = nil
    }

    // MARK: - API Methods

    func testConnection(baseURL: String, token: String) async throws -> Bool {
        let data = try await request(method: "GET", path: "/api/", baseURL: baseURL, token: token)
        struct HealthResponse: Decodable { let message: String }
        let response = try JSONDecoder().decode(HealthResponse.self, from: data)
        let success = response.message == "API running."
        connectionState = success ? .connected : .error("Unexpected response")
        return success
    }

    func fetchScenes(baseURL: String, token: String) async throws -> [HAScene] {
        let data = try await request(method: "GET", path: "/api/states", baseURL: baseURL, token: token)
        let allStates = try JSONDecoder().decode([HAStateObject].self, from: data)
        return allStates
            .filter { $0.entity_id.hasPrefix("scene.") }
            .map { HAScene(entityId: $0.entity_id, friendlyName: $0.attributes.friendly_name ?? $0.entity_id) }
    }

    @discardableResult
    func activateScene(entityId: String, baseURL: String, token: String) async -> SceneActivationResult {
        do {
            let body = ["entity_id": entityId]
            let bodyData = try JSONEncoder().encode(body)
            let data = try await requestWithRetry(
                method: "POST",
                path: "/api/services/scene/turn_on",
                baseURL: baseURL,
                token: token,
                body: bodyData
            )
            // Response is array of affected entity states
            if let affected = try? JSONDecoder().decode([HAStateObject].self, from: data) {
                return .success(entities: affected.map(\.entity_id))
            }
            return .success(entities: [])
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Request with Retry

    private func requestWithRetry(
        method: String, path: String, baseURL: String,
        token: String, body: Data? = nil, maxRetries: Int = 3
    ) async throws -> Data {
        var lastError: (any Error)?
        var delay: Duration = .seconds(1)

        for attempt in 0..<maxRetries {
            do {
                return try await request(method: method, path: path, baseURL: baseURL, token: token, body: body)
            } catch let error as HAError {
                switch error {
                case .networkError, .serverError(500..., _):
                    lastError = error
                    if attempt < maxRetries - 1 {
                        try? await Task.sleep(for: delay)
                        delay *= 2
                    }
                default:
                    throw error
                }
            }
        }
        throw lastError ?? HAError.networkError(URLError(.unknown))
    }

    // MARK: - Base Request

    private func request(
        method: String, path: String, baseURL: String,
        token: String, body: Data? = nil
    ) async throws -> Data {
        let trimmedURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: trimmedURL + path) else {
            throw HAError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        req.timeoutInterval = 10
        req.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            connectionState = .disconnected
            throw HAError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HAError.networkError(URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200...299:
            connectionState = .connected
            return data
        case 401:
            throw HAError.unauthorized
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown"
            throw HAError.serverError(httpResponse.statusCode, message)
        }
    }
}
