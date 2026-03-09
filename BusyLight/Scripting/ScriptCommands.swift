import Foundation
import AppKit

@objc(ActivateSceneCommand)
class ActivateSceneCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let entityId = directParameter as? String else {
            scriptErrorNumber = -1
            scriptErrorString = "Expected a scene entity ID string (e.g., 'scene.office_busy')."
            return nil
        }

        Task { @MainActor in
            let settings = AppSettings.shared
            settings.activeSceneId = entityId
            // MenuBarLabelView updates automatically via @Observable on AppSettings

            if !settings.haBaseURL.isEmpty && !settings.haToken.isEmpty {
                await HomeAssistantService.shared.activateScene(
                    entityId: entityId,
                    baseURL: settings.haBaseURL,
                    token: settings.haToken
                )
            }
        }
        return nil
    }
}

@objc(DeactivateSceneCommand)
class DeactivateSceneCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        Task { @MainActor in
            AppSettings.shared.activeSceneId = nil
            // MenuBarLabelView updates automatically via @Observable on AppSettings
        }
        return nil
    }
}

@objc(ListScenesCommand)
class ListScenesCommand: NSScriptCommand {
    @MainActor
    private static func getSceneList() -> [String] {
        AppSettings.shared.scenes.map { "\($0.emoji) \($0.displayName) (\($0.entityId))" }
    }

    override func performDefaultImplementation() -> Any? {
        // NSScriptCommand always runs on the main thread
        let scenes: [String] = MainActor.assumeIsolated {
            Self.getSceneList()
        }
        return scenes as NSArray
    }
}
