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

        suspendExecution()
        // NSScriptCommand is not Sendable, but performDefaultImplementation
        // and the @MainActor Task both run on the main thread. The command
        // is retained by suspendExecution() until resumeExecution() is called.
        nonisolated(unsafe) let command = self
        Task { @MainActor in
            let result = await MenuBarManager.shared.activateSceneWithResult(entityId: entityId)
            if result.success {
                command.resumeExecution(withResult: "Scene \(entityId) activated." as NSString)
            } else {
                command.scriptErrorNumber = -10000
                command.scriptErrorString = result.error?.localizedDescription
                    ?? "Failed to activate scene \(entityId)."
                command.resumeExecution(withResult: nil)
            }
        }
        return nil
    }
}

@objc(DeactivateSceneCommand)
class DeactivateSceneCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        Task { @MainActor in
            MenuBarManager.shared.deactivateScene()
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
