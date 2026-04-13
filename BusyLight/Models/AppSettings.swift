import Foundation
import SwiftUI

enum DisplayMode: String, Codable, CaseIterable, Sendable {
    case emojiOnly = "emoji"
    case nameOnly = "name"
    case both = "both"
}

struct KeyboardShortcutConfig: Codable, Hashable {
    var keyCode: UInt16
    var modifiers: UInt
    var sceneEntityId: String
}

@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()
    // MARK: - First Run

    var hasCompletedFirstRun: Bool {
        didSet { UserDefaults.standard.set(hasCompletedFirstRun, forKey: "hasCompletedFirstRun") }
    }

    // MARK: - Home Assistant

    var haBaseURL: String {
        didSet { UserDefaults.standard.set(haBaseURL, forKey: "ha_baseURL") }
    }

    var haToken: String {
        get { KeychainHelper.load(key: "com.mboszko.BusyLight.haToken") ?? "" }
        set { KeychainHelper.save(key: "com.mboszko.BusyLight.haToken", value: newValue) }
    }

    // MARK: - Display

    var displayMode: DisplayMode {
        didSet { UserDefaults.standard.set(displayMode.rawValue, forKey: "displayMode") }
    }

    // MARK: - Active Scene

    var activeSceneId: String? {
        didSet { UserDefaults.standard.set(activeSceneId, forKey: "activeSceneId") }
    }

    // MARK: - Connection State (runtime only, not persisted)

    var connectionState: ConnectionState = .unknown

    var isDisconnected: Bool {
        switch connectionState {
        case .disconnected, .error: return true
        default: return false
        }
    }

    // MARK: - Trigger Settings

    var webcamTriggerEnabled: Bool {
        didSet { UserDefaults.standard.set(webcamTriggerEnabled, forKey: "webcamTriggerEnabled") }
    }
    var webcamOnSceneId: String {
        didSet { UserDefaults.standard.set(webcamOnSceneId, forKey: "webcamOnSceneId") }
    }
    var webcamOffTriggerEnabled: Bool {
        didSet { UserDefaults.standard.set(webcamOffTriggerEnabled, forKey: "webcamOffTriggerEnabled") }
    }
    var webcamOffSceneId: String {
        didSet { UserDefaults.standard.set(webcamOffSceneId, forKey: "webcamOffSceneId") }
    }

    var micTriggerEnabled: Bool {
        didSet { UserDefaults.standard.set(micTriggerEnabled, forKey: "micTriggerEnabled") }
    }
    var micOnSceneId: String {
        didSet { UserDefaults.standard.set(micOnSceneId, forKey: "micOnSceneId") }
    }
    var micOffTriggerEnabled: Bool {
        didSet { UserDefaults.standard.set(micOffTriggerEnabled, forKey: "micOffTriggerEnabled") }
    }
    var micOffSceneId: String {
        didSet { UserDefaults.standard.set(micOffSceneId, forKey: "micOffSceneId") }
    }

    var screenLockTriggerEnabled: Bool {
        didSet { UserDefaults.standard.set(screenLockTriggerEnabled, forKey: "screenLockTriggerEnabled") }
    }
    var screenLockSceneId: String {
        didSet { UserDefaults.standard.set(screenLockSceneId, forKey: "screenLockSceneId") }
    }
    var screenUnlockTriggerEnabled: Bool {
        didSet { UserDefaults.standard.set(screenUnlockTriggerEnabled, forKey: "screenUnlockTriggerEnabled") }
    }
    var screenUnlockSceneId: String {
        didSet { UserDefaults.standard.set(screenUnlockSceneId, forKey: "screenUnlockSceneId") }
    }

    var focusOnTriggerEnabled: Bool {
        didSet { UserDefaults.standard.set(focusOnTriggerEnabled, forKey: "focusOnTriggerEnabled") }
    }
    var focusOnSceneId: String {
        didSet { UserDefaults.standard.set(focusOnSceneId, forKey: "focusOnSceneId") }
    }
    var focusOffTriggerEnabled: Bool {
        didSet { UserDefaults.standard.set(focusOffTriggerEnabled, forKey: "focusOffTriggerEnabled") }
    }
    var focusOffSceneId: String {
        didSet { UserDefaults.standard.set(focusOffSceneId, forKey: "focusOffSceneId") }
    }

    // MARK: - Scene List

    var menuItems: [MenuListItem] {
        didSet { saveMenuItems() }
    }

    // MARK: - Keyboard Shortcuts

    var keyboardShortcuts: [KeyboardShortcutConfig] {
        didSet { saveKeyboardShortcuts() }
    }

    // MARK: - Computed

    var scenes: [SceneItem] {
        menuItems.compactMap { $0.sceneItem }
    }

    /// Text shown in the menu bar, reflecting the active scene and display mode.
    var menuBarLabel: String {
        let warning = isDisconnected ? " \u{26A0}\u{FE0F}" : ""
        if let activeId = activeSceneId,
           let scene = scenes.first(where: { $0.entityId == activeId }) {
            switch displayMode {
            case .emojiOnly: return scene.emoji + warning
            case .nameOnly:  return scene.displayName + warning
            case .both:      return "\(scene.emoji) \(scene.displayName)" + warning
            }
        }
        return noSceneLabel
    }

    /// Text shown when no scene is active, respecting the display mode setting.
    var noSceneLabel: String {
        let warning = isDisconnected ? " \u{26A0}\u{FE0F}" : ""
        switch displayMode {
        case .emojiOnly: return "🚦" + warning
        case .nameOnly:  return "Busy Light" + warning
        case .both:      return "🚦 Busy Light" + warning
        }
    }

    // MARK: - Init

    private init() {
        let defaults = UserDefaults.standard
        self.haBaseURL = defaults.string(forKey: "ha_baseURL") ?? "http://homeassistant.local:8123"
        self.displayMode = DisplayMode(rawValue: defaults.string(forKey: "displayMode") ?? "") ?? .both
        self.activeSceneId = defaults.string(forKey: "activeSceneId")
        self.hasCompletedFirstRun = defaults.bool(forKey: "hasCompletedFirstRun")

        self.webcamTriggerEnabled = defaults.bool(forKey: "webcamTriggerEnabled")
        self.webcamOnSceneId = defaults.string(forKey: "webcamOnSceneId") ?? ""
        self.webcamOffTriggerEnabled = defaults.bool(forKey: "webcamOffTriggerEnabled")
        self.webcamOffSceneId = defaults.string(forKey: "webcamOffSceneId") ?? ""

        self.micTriggerEnabled = defaults.bool(forKey: "micTriggerEnabled")
        self.micOnSceneId = defaults.string(forKey: "micOnSceneId") ?? ""
        self.micOffTriggerEnabled = defaults.bool(forKey: "micOffTriggerEnabled")
        self.micOffSceneId = defaults.string(forKey: "micOffSceneId") ?? ""

        self.screenLockTriggerEnabled = defaults.bool(forKey: "screenLockTriggerEnabled")
        self.screenLockSceneId = defaults.string(forKey: "screenLockSceneId") ?? ""
        self.screenUnlockTriggerEnabled = defaults.bool(forKey: "screenUnlockTriggerEnabled")
        self.screenUnlockSceneId = defaults.string(forKey: "screenUnlockSceneId") ?? ""

        self.focusOnTriggerEnabled = defaults.bool(forKey: "focusOnTriggerEnabled")
        self.focusOnSceneId = defaults.string(forKey: "focusOnSceneId") ?? ""
        self.focusOffTriggerEnabled = defaults.bool(forKey: "focusOffTriggerEnabled")
        self.focusOffSceneId = defaults.string(forKey: "focusOffSceneId") ?? ""

        if let data = defaults.data(forKey: "menuItems"),
           let items = try? JSONDecoder().decode([MenuListItem].self, from: data) {
            self.menuItems = items
        } else {
            self.menuItems = []
        }

        if let data = defaults.data(forKey: "keyboardShortcuts"),
           let shortcuts = try? JSONDecoder().decode([KeyboardShortcutConfig].self, from: data) {
            self.keyboardShortcuts = shortcuts
        } else {
            self.keyboardShortcuts = []
        }
    }

    // For testing: allow injecting a different UserDefaults
    init(defaults: UserDefaults) {
        self.haBaseURL = defaults.string(forKey: "ha_baseURL") ?? "http://homeassistant.local:8123"
        self.displayMode = DisplayMode(rawValue: defaults.string(forKey: "displayMode") ?? "") ?? .both
        self.activeSceneId = defaults.string(forKey: "activeSceneId")
        self.hasCompletedFirstRun = defaults.bool(forKey: "hasCompletedFirstRun")

        self.webcamTriggerEnabled = defaults.bool(forKey: "webcamTriggerEnabled")
        self.webcamOnSceneId = defaults.string(forKey: "webcamOnSceneId") ?? ""
        self.webcamOffTriggerEnabled = defaults.bool(forKey: "webcamOffTriggerEnabled")
        self.webcamOffSceneId = defaults.string(forKey: "webcamOffSceneId") ?? ""

        self.micTriggerEnabled = defaults.bool(forKey: "micTriggerEnabled")
        self.micOnSceneId = defaults.string(forKey: "micOnSceneId") ?? ""
        self.micOffTriggerEnabled = defaults.bool(forKey: "micOffTriggerEnabled")
        self.micOffSceneId = defaults.string(forKey: "micOffSceneId") ?? ""

        self.screenLockTriggerEnabled = defaults.bool(forKey: "screenLockTriggerEnabled")
        self.screenLockSceneId = defaults.string(forKey: "screenLockSceneId") ?? ""
        self.screenUnlockTriggerEnabled = defaults.bool(forKey: "screenUnlockTriggerEnabled")
        self.screenUnlockSceneId = defaults.string(forKey: "screenUnlockSceneId") ?? ""

        self.focusOnTriggerEnabled = defaults.bool(forKey: "focusOnTriggerEnabled")
        self.focusOnSceneId = defaults.string(forKey: "focusOnSceneId") ?? ""
        self.focusOffTriggerEnabled = defaults.bool(forKey: "focusOffTriggerEnabled")
        self.focusOffSceneId = defaults.string(forKey: "focusOffSceneId") ?? ""

        if let data = defaults.data(forKey: "menuItems"),
           let items = try? JSONDecoder().decode([MenuListItem].self, from: data) {
            self.menuItems = items
        } else {
            self.menuItems = []
        }

        if let data = defaults.data(forKey: "keyboardShortcuts"),
           let shortcuts = try? JSONDecoder().decode([KeyboardShortcutConfig].self, from: data) {
            self.keyboardShortcuts = shortcuts
        } else {
            self.keyboardShortcuts = []
        }
    }

    private func saveMenuItems() {
        if let data = try? JSONEncoder().encode(menuItems) {
            UserDefaults.standard.set(data, forKey: "menuItems")
        }
    }

    private func saveKeyboardShortcuts() {
        if let data = try? JSONEncoder().encode(keyboardShortcuts) {
            UserDefaults.standard.set(data, forKey: "keyboardShortcuts")
        }
    }
}
