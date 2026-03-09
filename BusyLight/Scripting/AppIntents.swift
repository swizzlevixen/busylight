import AppIntents
import Foundation

// MARK: - Activate Scene Intent

struct ActivateSceneIntent: AppIntent {
    static let title: LocalizedStringResource = "Activate Scene"
    static let description: IntentDescription = "Activate a Home Assistant scene via Busy Light."
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Scene Entity ID", description: "The Home Assistant scene entity ID (e.g., scene.office_busy)")
    var entityId: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let settings = AppSettings.shared
        settings.activeSceneId = entityId
        MenuBarManager.shared.updateButtonTitle()

        guard !settings.haBaseURL.isEmpty && !settings.haToken.isEmpty else {
            return .result(value: "Scene set locally but HA not configured")
        }

        let result = await HomeAssistantService.shared.activateScene(
            entityId: entityId,
            baseURL: settings.haBaseURL,
            token: settings.haToken
        )

        if result.success {
            return .result(value: "Scene '\(entityId)' activated successfully")
        } else {
            return .result(value: "Failed to activate scene: \(result.error?.localizedDescription ?? "Unknown error")")
        }
    }
}

// MARK: - Deactivate Scene Intent

struct DeactivateSceneIntent: AppIntent {
    static let title: LocalizedStringResource = "Deactivate Scene"
    static let description: IntentDescription = "Clear the active scene in Busy Light."
    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        AppSettings.shared.activeSceneId = nil
        MenuBarManager.shared.updateButtonTitle()
        return .result(value: "Scene deactivated")
    }
}

// MARK: - Get Current Scene Intent

struct GetCurrentSceneIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Current Scene"
    static let description: IntentDescription = "Get the currently active scene in Busy Light."
    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let settings = AppSettings.shared
        if let activeId = settings.activeSceneId,
           let scene = settings.scenes.first(where: { $0.entityId == activeId }) {
            return .result(value: "\(scene.emoji) \(scene.displayName) (\(scene.entityId))")
        }
        return .result(value: "No scene active")
    }
}

// MARK: - List Scenes Intent

struct ListScenesIntent: AppIntent {
    static let title: LocalizedStringResource = "List Scenes"
    static let description: IntentDescription = "List all configured scenes in Busy Light."
    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        let scenes = AppSettings.shared.scenes
        let result = scenes.map { "\($0.emoji) \($0.displayName) (\($0.entityId))" }
        return .result(value: result)
    }
}

// MARK: - App Shortcuts Provider

struct BusyLightShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ActivateSceneIntent(),
            phrases: [
                "Activate \(.applicationName) scene",
                "Turn on \(.applicationName) scene",
                "Set \(.applicationName) to busy",
            ],
            shortTitle: "Activate Scene",
            systemImageName: "light.beacon.max.fill"
        )

        AppShortcut(
            intent: DeactivateSceneIntent(),
            phrases: [
                "Deactivate \(.applicationName) scene",
                "Turn off \(.applicationName)",
                "Clear \(.applicationName) scene",
            ],
            shortTitle: "Deactivate Scene",
            systemImageName: "light.beacon.min"
        )

        AppShortcut(
            intent: GetCurrentSceneIntent(),
            phrases: [
                "What scene is \(.applicationName) showing",
                "Get \(.applicationName) status",
            ],
            shortTitle: "Get Current Scene",
            systemImageName: "questionmark.circle"
        )

        AppShortcut(
            intent: ListScenesIntent(),
            phrases: [
                "List \(.applicationName) scenes",
                "Show \(.applicationName) scenes",
            ],
            shortTitle: "List Scenes",
            systemImageName: "list.bullet"
        )
    }
}
