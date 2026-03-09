import SwiftUI

// MARK: - SettingsOpener

/// Singleton that captures the SwiftUI `openSettings` environment action from
/// `MenuBarLabelView` (which is always live) so that `AppDelegate` can open the
/// Settings window at any time — even before the menu has ever been opened.
@MainActor
final class SettingsOpener {
    static let shared = SettingsOpener()
    private init() {}

    private var openAction: (() -> Void)?

    func capture(_ action: OpenSettingsAction) {
        openAction = { action() }
    }

    func openSettings() {
        openAction?()
    }
}

// MARK: - MenuBarContentView

/// The SwiftUI content of the MenuBarExtra menu.
/// Owns @Environment(\.openSettings) — the canonical way to open the Settings
/// window — so there is no need for a separate hidden utility window.
struct MenuBarContentView: View {
    @Environment(\.openSettings) private var openSettings
    private var settings = AppSettings.shared

    var body: some View {
        menuItems
            .onReceive(NotificationCenter.default.publisher(for: .settingsWindowClosed)) { _ in
                NSApp.setActivationPolicy(.accessory)
            }
    }

    // MARK: - Menu items

    @ViewBuilder
    private var menuItems: some View {
        // Scene list or empty-state shortcut
        if settings.menuItems.isEmpty {
            Button("Add Scene\u{2026}") {
                postOpen(tab: "scenes")
            }
        } else {
            ForEach(settings.menuItems) { item in
                switch item {
                case .scene(let scene):
                    Button {
                        activateScene(scene)
                    } label: {
                        // Label puts the image in the checkmark column;
                        // plain Text leaves it empty — the correct Mac pattern.
                        if scene.entityId == settings.activeSceneId {
                            Label(sceneTitle(scene), systemImage: "checkmark")
                        } else {
                            Text(sceneTitle(scene))
                        }
                    }
                case .divider:
                    Divider()
                }
            }
        }

        Divider()

        Button("Settings\u{2026}") {
            postOpen(tab: nil)
        }

        Button("Quit Busy Light") {
            NSApp.terminate(nil)
        }
    }

    // MARK: - Helpers

    private func sceneTitle(_ scene: SceneItem) -> String {
        switch settings.displayMode {
        case .emojiOnly: return scene.emoji
        case .nameOnly:  return scene.displayName
        case .both:      return "\(scene.emoji) \(scene.displayName)"
        }
    }

    private func activateScene(_ scene: SceneItem) {
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

    /// Posts the notification that opens Settings (optionally to a specific tab).
    /// AppDelegate's observer handles activation policy + window title in parallel.
    private func postOpen(tab: String?) {
        NotificationCenter.default.post(
            name: .openSettingsRequest,
            object: nil,
            userInfo: tab.map { ["tab": $0] }
        )
    }
}

/// Separate label view so @Observable tracking fires inside a View.body.
/// This view is always live (it renders the menu bar label), so it is the
/// ideal place to capture @Environment(\.openSettings) for use by AppDelegate.
struct MenuBarLabelView: View {
    @Environment(\.openSettings) private var openSettings
    private var settings = AppSettings.shared

    var body: some View {
        Text(settings.menuBarLabel)
            .onAppear {
                SettingsOpener.shared.capture(openSettings)
            }
    }
}
