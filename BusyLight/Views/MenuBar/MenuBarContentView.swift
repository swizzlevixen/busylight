import SwiftUI

/// The SwiftUI content of the MenuBarExtra menu.
/// Owns @Environment(\.openSettings) — the canonical way to open the Settings
/// window — so there is no need for a separate hidden utility window.
struct MenuBarContentView: View {
    @Environment(\.openSettings) private var openSettings
    private var settings = AppSettings.shared

    var body: some View {
        // Wrap all content so we can attach .onReceive to the root view.
        // MenuBarExtra(.menu) renders the individual items (Button, Divider…)
        // normally; the modifiers are purely lifecycle hooks.
        menuItems
            .onReceive(NotificationCenter.default.publisher(for: .openSettingsRequest)) { _ in
                openSettings()
            }
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
struct MenuBarLabelView: View {
    private var settings = AppSettings.shared

    var body: some View {
        Text(settings.menuBarLabel)
    }
}
