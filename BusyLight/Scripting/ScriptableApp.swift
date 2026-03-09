import AppKit

class ScriptableApp: NSApplication {

    @MainActor
    @objc var currentSceneName: String {
        get {
            AppSettings.shared.activeSceneId ?? ""
        }
        set {
            if newValue.isEmpty {
                AppSettings.shared.activeSceneId = nil
            } else {
                AppSettings.shared.activeSceneId = newValue
            }
            MenuBarManager.shared.updateButtonTitle()

            // If setting a scene, also trigger it via HA
            if !newValue.isEmpty {
                let baseURL = AppSettings.shared.haBaseURL
                let token = AppSettings.shared.haToken
                Task {
                    await HomeAssistantService.shared.activateScene(
                        entityId: newValue, baseURL: baseURL, token: token
                    )
                }
            }
        }
    }

    @MainActor
    @objc var isBusy: Bool {
        AppSettings.shared.activeSceneId != nil
    }

    @MainActor
    @objc var scriptDisplayMode: String {
        get {
            AppSettings.shared.displayMode.rawValue
        }
        set {
            if let mode = DisplayMode(rawValue: newValue) {
                AppSettings.shared.displayMode = mode
                MenuBarManager.shared.updateButtonTitle()
            }
        }
    }

    @MainActor
    @objc var isCameraActive: Bool {
        CameraMonitor.shared.isCameraOn
    }

    @MainActor
    @objc var isMicrophoneActive: Bool {
        MicrophoneMonitor.shared.isMicrophoneOn
    }
}
