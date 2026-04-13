import Foundation

/// Manages scene activation on behalf of the menu bar and other callers
/// (TriggerManager, AppIntents, AppleScript). The visual menu is now owned
/// by MenuBarContentView in the MenuBarExtra scene.
@MainActor
final class MenuBarManager {
    static let shared = MenuBarManager()

    private let settings = AppSettings.shared

    /// Fire-and-forget activation from a `SceneItem`.
    func activateScene(_ scene: SceneItem) {
        activateScene(entityId: scene.entityId)
    }

    /// Fire-and-forget activation by entity ID string.
    /// Sets `activeSceneId` optimistically and reverts if the HA call fails.
    func activateScene(entityId: String) {
        let previousId = settings.activeSceneId
        settings.activeSceneId = entityId
        guard !settings.haBaseURL.isEmpty && !settings.haToken.isEmpty else { return }
        Task {
            let result = await HomeAssistantService.shared.activateScene(
                entityId: entityId,
                baseURL: settings.haBaseURL,
                token: settings.haToken
            )
            if !result.success {
                await MainActor.run {
                    settings.activeSceneId = previousId
                }
            }
        }
    }

    /// Async activation that returns the HA result (for AppIntents that report
    /// success/failure back to Shortcuts).
    func activateSceneWithResult(entityId: String) async -> SceneActivationResult {
        settings.activeSceneId = entityId
        guard !settings.haBaseURL.isEmpty && !settings.haToken.isEmpty else {
            return .success(entities: [])
        }
        return await HomeAssistantService.shared.activateScene(
            entityId: entityId,
            baseURL: settings.haBaseURL,
            token: settings.haToken
        )
    }

    func deactivateScene() {
        settings.activeSceneId = nil
    }
}
