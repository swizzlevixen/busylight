import Foundation

/// Manages scene activation on behalf of the menu bar and other callers
/// (TriggerManager, AppIntents, AppleScript). The visual menu is now owned
/// by MenuBarContentView in the MenuBarExtra scene.
@MainActor
final class MenuBarManager {
    static let shared = MenuBarManager()

    private let settings = AppSettings.shared

    func activateScene(_ scene: SceneItem) {
        settings.activeSceneId = scene.entityId
        guard !settings.haBaseURL.isEmpty && !settings.haToken.isEmpty else { return }
        Task {
            await HomeAssistantService.shared.activateScene(
                entityId: scene.entityId,
                baseURL: settings.haBaseURL,
                token: settings.haToken
            )
        }
    }

    func deactivateScene() {
        settings.activeSceneId = nil
    }
}
