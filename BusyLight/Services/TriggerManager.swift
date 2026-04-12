import Foundation

@MainActor
final class TriggerManager {
    static let shared = TriggerManager()

    private let settings = AppSettings.shared
    private var observers: [NSObjectProtocol] = []

    func startAllMonitors() {
        CameraMonitor.shared.startMonitoring()
        MicrophoneMonitor.shared.startMonitoring()
        ScreenLockMonitor.shared.startMonitoring()
        FocusModeMonitor.shared.startMonitoring()
        trackAndUpdateHotkeys()

        observers.append(
            NotificationCenter.default.addObserver(
                forName: .cameraStateChanged, object: nil, queue: .main
            ) { [weak self] notification in
                let isOn = notification.userInfo?["isOn"] as? Bool
                Task { @MainActor in
                    self?.handleCameraChange(isOn: isOn)
                }
            }
        )

        observers.append(
            NotificationCenter.default.addObserver(
                forName: .microphoneStateChanged, object: nil, queue: .main
            ) { [weak self] notification in
                let isOn = notification.userInfo?["isOn"] as? Bool
                Task { @MainActor in
                    self?.handleMicChange(isOn: isOn)
                }
            }
        )

        observers.append(
            NotificationCenter.default.addObserver(
                forName: .screenLockStateChanged, object: nil, queue: .main
            ) { [weak self] notification in
                let isLocked = notification.userInfo?["isLocked"] as? Bool
                Task { @MainActor in
                    self?.handleScreenLockChange(isLocked: isLocked)
                }
            }
        )

        observers.append(
            NotificationCenter.default.addObserver(
                forName: .focusModeChanged, object: nil, queue: .main
            ) { [weak self] notification in
                let isActive = notification.userInfo?["isActive"] as? Bool
                Task { @MainActor in
                    self?.handleFocusModeChange(isActive: isActive)
                }
            }
        )

        // Start HA health checks if configured
        if !settings.haBaseURL.isEmpty && !settings.haToken.isEmpty {
            Task {
                await HomeAssistantService.shared.startHealthChecks(
                    baseURL: settings.haBaseURL,
                    token: settings.haToken
                )
            }
        }
    }

    /// Register keyboard shortcuts with GlobalHotkeyManager and re-register
    /// automatically whenever AppSettings.keyboardShortcuts changes.
    ///
    /// `withObservationTracking` reads `settings.keyboardShortcuts` inside its
    /// apply block, which registers an @Observable observation.  When the user
    /// records a new shortcut in ShortcutRecorderView (or deletes one), the
    /// onChange closure fires, hops back to @MainActor, and calls this method
    /// again — re-registering the updated set and re-installing the observation.
    private func trackAndUpdateHotkeys() {
        withObservationTracking {
            GlobalHotkeyManager.shared.updateShortcuts(settings.keyboardShortcuts)
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.trackAndUpdateHotkeys()
            }
        }
    }

    func stopAllMonitors() {
        CameraMonitor.shared.stopMonitoring()
        MicrophoneMonitor.shared.stopMonitoring()
        ScreenLockMonitor.shared.stopMonitoring()
        FocusModeMonitor.shared.stopMonitoring()
        GlobalHotkeyManager.shared.unregisterAll()

        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()

        Task {
            await HomeAssistantService.shared.stopHealthChecks()
        }
    }

    // MARK: - Handlers

    /// Camera triggers take highest priority over microphone triggers.
    /// Suppressed when the screen is locked to avoid false triggers during Power Nap.
    private func handleCameraChange(isOn: Bool?) {
        guard let isOn else { return }
        guard !ScreenLockMonitor.shared.isScreenLocked else { return }

        if isOn && settings.webcamTriggerEnabled && !settings.webcamOnSceneId.isEmpty {
            activateScene(entityId: settings.webcamOnSceneId)
        } else if !isOn && settings.webcamOffTriggerEnabled && !settings.webcamOffSceneId.isEmpty {
            activateScene(entityId: settings.webcamOffSceneId)
        }
    }

    /// Microphone triggers only fire when camera is not active (camera has priority).
    /// Suppressed when the screen is locked to avoid false triggers during Power Nap.
    private func handleMicChange(isOn: Bool?) {
        guard let isOn else { return }
        guard !ScreenLockMonitor.shared.isScreenLocked else { return }

        // Don't override camera trigger
        if CameraMonitor.shared.isCameraOn { return }

        if isOn && settings.micTriggerEnabled && !settings.micOnSceneId.isEmpty {
            activateScene(entityId: settings.micOnSceneId)
        } else if !isOn && settings.micOffTriggerEnabled && !settings.micOffSceneId.isEmpty {
            activateScene(entityId: settings.micOffSceneId)
        }
    }

    private func handleScreenLockChange(isLocked: Bool?) {
        guard let isLocked else { return }

        if isLocked && settings.screenLockTriggerEnabled && !settings.screenLockSceneId.isEmpty {
            activateScene(entityId: settings.screenLockSceneId)
        } else if !isLocked && settings.screenUnlockTriggerEnabled && !settings.screenUnlockSceneId.isEmpty {
            activateScene(entityId: settings.screenUnlockSceneId)
        }
    }

    private func handleFocusModeChange(isActive: Bool?) {
        guard let isActive else { return }

        if isActive && settings.focusOnTriggerEnabled && !settings.focusOnSceneId.isEmpty {
            activateScene(entityId: settings.focusOnSceneId)
        } else if !isActive && settings.focusOffTriggerEnabled && !settings.focusOffSceneId.isEmpty {
            activateScene(entityId: settings.focusOffSceneId)
        }
    }

    // MARK: - Scene Activation

    private func activateScene(entityId: String) {
        MenuBarManager.shared.activateScene(entityId: entityId)
    }
}
