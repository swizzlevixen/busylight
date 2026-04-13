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
        // Connection warning (auto-clears when health check succeeds)
        if settings.isDisconnected {
            Text("\u{26A0}\u{FE0F} Unable to reach Home Assistant")
            Divider()
        }

        // Scene list or empty-state shortcut
        if settings.menuItems.isEmpty {
            Button { postOpen(tab: "scenes") } label: {
                Label("Add Scene\u{2026}", systemImage: "plus")
            }
        } else {
            ForEach(settings.menuItems) { item in
                switch item {
                case .scene(let scene):
                    Button {
                        MenuBarManager.shared.activateScene(scene)
                    } label: {
                        // Label puts the image in the checkmark column;
                        // plain Text leaves it empty — the correct Mac pattern.
                        if scene.entityId == settings.activeSceneId {
                            Label(sceneTitle(scene), systemImage: "checkmark")
                        } else {
                            Text(sceneTitle(scene))
                        }
                    }
                    .keyboardShortcutIfPresent(shortcutForScene(scene.entityId))
                case .divider:
                    Divider()
                }
            }
        }

        Divider()

        // Help submenu — accessible even when Settings window is closed
        Menu {
            Button { HelpManager.openHelp(anchor: "getting-started") } label: {
                Label("Getting Started", systemImage: "play.circle")
            }
            Button { HelpManager.openHelp(anchor: "adding-scenes") } label: {
                Label("Adding Scenes", systemImage: "list.bullet")
            }
            Button { HelpManager.openHelp(anchor: "using-triggers") } label: {
                Label("Using Triggers", systemImage: "bolt.fill")
            }
            Button { HelpManager.openHelp(anchor: "troubleshooting") } label: {
                Label("Troubleshooting", systemImage: "wrench.and.screwdriver")
            }
        } label: {
            Label("Help", systemImage: "questionmark.circle")
        }

        Button { postOpen(tab: nil) } label: {
            Label("Settings\u{2026}", systemImage: "gear")
        }

        Button { NSApp.terminate(nil) } label: {
            Label("Quit Busy Light", systemImage: "power")
        }
    }

    // MARK: - Helpers

    /// Returns a SwiftUI `KeyboardShortcut` for the given scene entity ID,
    /// or `nil` if no shortcut has been configured for it.
    ///
    /// The shortcut is used only for **display** in the menu (the right-aligned
    /// glyph string macOS renders from NSMenuItem.keyEquivalent).  The actual
    /// activation continues to be handled by Carbon `RegisterEventHotKey` in
    /// `GlobalHotkeyManager`, which intercepts at the CGEvent level and
    /// consumes the event before NSMenuItem ever sees it — so there is no
    /// risk of double-activation.
    private func shortcutForScene(_ entityId: String) -> KeyboardShortcut? {
        guard let config = settings.keyboardShortcuts
                .first(where: { $0.sceneEntityId == entityId }),
              let char = keyCodeToCharacter(config.keyCode)
        else { return nil }
        return KeyboardShortcut(KeyEquivalent(char),
                                modifiers: toEventModifiers(config.modifiers))
    }

    /// Maps macOS virtual key codes to the `Character` expected by
    /// `KeyEquivalent`.  Letters are lowercase; SwiftUI / AppKit uppercases
    /// them for display automatically.
    private func keyCodeToCharacter(_ keyCode: UInt16) -> Character? {
        KeyCodeMapping.keyEquivalent(for: keyCode)
    }

    /// Converts `NSEvent.ModifierFlags` raw value (as stored in
    /// `KeyboardShortcutConfig.modifiers`) to SwiftUI `EventModifiers`.
    private func toEventModifiers(_ rawValue: UInt) -> EventModifiers {
        let ns = NSEvent.ModifierFlags(rawValue: rawValue)
        var em: EventModifiers = []
        if ns.contains(.command) { em.insert(.command) }
        if ns.contains(.shift)   { em.insert(.shift) }
        if ns.contains(.option)  { em.insert(.option) }
        if ns.contains(.control) { em.insert(.control) }
        return em
    }

    private func sceneTitle(_ scene: SceneItem) -> String {
        switch settings.displayMode {
        case .emojiOnly: return scene.emoji
        case .nameOnly:  return scene.displayName
        case .both:      return "\(scene.emoji) \(scene.displayName)"
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

// MARK: - View helpers

private extension View {
    /// Applies `.keyboardShortcut(_:)` when `shortcut` is non-nil, otherwise
    /// returns `self` unchanged.  Used to attach an optional display-only
    /// shortcut hint to each scene menu item without duplicating the Button body.
    @ViewBuilder
    func keyboardShortcutIfPresent(_ shortcut: KeyboardShortcut?) -> some View {
        if let shortcut {
            self.keyboardShortcut(shortcut)
        } else {
            self
        }
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
