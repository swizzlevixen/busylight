import AppKit

class ScriptableApp: NSApplication {

    @MainActor
    @objc var currentSceneName: String {
        get {
            AppSettings.shared.activeSceneId ?? ""
        }
        set {
            guard !newValue.isEmpty else { return }
            MenuBarManager.shared.activateScene(entityId: newValue)
        }
    }

    @MainActor
    @objc var scriptDisplayMode: String {
        get {
            AppSettings.shared.displayMode.rawValue
        }
        set {
            if let mode = DisplayMode(rawValue: newValue) {
                AppSettings.shared.displayMode = mode
                // MenuBarLabelView updates automatically via @Observable on AppSettings
            }
        }
    }

}
