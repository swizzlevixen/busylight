import AppKit
import Carbon

// MARK: - Carbon event handler (file-scope C callback)

/// Receives Carbon hotkey events and dispatches to GlobalHotkeyManager on the main actor.
///
/// This must be a free function (not an instance method) to satisfy the
/// `EventHandlerUPP` / `@convention(c)` requirement of
/// `InstallApplicationEventHandler`.
///
/// `RegisterEventHotKey` intercepts key events system-wide — including when
/// BusyLight itself is in the foreground — without requiring Input Monitoring
/// or Accessibility permission.  The original key-down event is consumed by
/// Carbon and never reaches the application's normal NSEvent queue.
private func carbonHotkeyCallback(
    _: EventHandlerCallRef?,
    event: EventRef?,
    _: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }

    var hotkeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotkeyID
    )
    guard status == noErr else { return OSStatus(eventNotHandledErr) }

    let id = hotkeyID.id
    Task { @MainActor in
        GlobalHotkeyManager.shared.handleCarbonHotKey(id: id)
    }
    return noErr
}

// MARK: - GlobalHotkeyManager

@MainActor
final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    // MARK: - State

    /// Carbon EventHotKeyRefs; one per successfully registered shortcut.
    private var hotKeyRefs: [EventHotKeyRef] = []

    /// Maps Carbon hotkey IDs → the shortcut config they represent.
    private var shortcutsByHotKeyId: [UInt32: KeyboardShortcutConfig] = [:]

    /// Monotonically-increasing ID handed to each `RegisterEventHotKey` call.
    /// Never reset, so IDs remain unique across `updateShortcuts` cycles.
    private var nextHotKeyId: UInt32 = 1

    /// Cached shortcut list (cleared on `unregisterAll`).
    private var registeredShortcuts: [KeyboardShortcutConfig] = []

    /// Retained Carbon event handler reference (app-lifetime).
    private var carbonHandlerRef: EventHandlerRef?

    // MARK: - Init

    private init() {
        // Install the Carbon event handler once for the app's lifetime.
        // All kEventHotKeyPressed events for any hotkey registered via
        // RegisterEventHotKey will be delivered to carbonHotkeyCallback.
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        // InstallApplicationEventHandler is a C macro and cannot be called
        // directly from Swift.  It expands to:
        //   InstallEventHandler(GetApplicationEventTarget(), handler, ...)
        InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHotkeyCallback,
            1,
            &eventType,
            nil,
            &carbonHandlerRef
        )
    }

    // MARK: - Public API

    func updateShortcuts(_ shortcuts: [KeyboardShortcutConfig]) {
        unregisterAll()
        registeredShortcuts = shortcuts
        for shortcut in shortcuts {
            registerShortcut(shortcut)
        }
    }

    func unregisterAll() {
        for ref in hotKeyRefs { UnregisterEventHotKey(ref) }
        hotKeyRefs.removeAll()
        shortcutsByHotKeyId.removeAll()
        registeredShortcuts.removeAll()
    }

    // MARK: - Carbon dispatch

    /// Called from `carbonHotkeyCallback` when a registered hotkey fires.
    ///
    /// Marked `internal` (not `private`) so the file-scope C callback can
    /// reach it via `GlobalHotkeyManager.shared`.
    func handleCarbonHotKey(id: UInt32) {
        guard let shortcut = shortcutsByHotKeyId[id] else { return }
        handleShortcutActivation(shortcut)
    }

    // MARK: - Private

    private func registerShortcut(_ shortcut: KeyboardShortcutConfig) {
        let currentId = nextHotKeyId
        nextHotKeyId += 1

        let flags = NSEvent.ModifierFlags(rawValue: shortcut.modifiers)

        // `RegisterEventHotKey` fires system-wide — both when BusyLight is in
        // the background (primary use case: user presses a shortcut while in
        // Zoom, Safari, etc.) and when BusyLight is the active app (e.g.
        // Settings window open).  No Input Monitoring permission is required,
        // unlike NSEvent.addGlobalMonitorForEvents.
        //
        // Carbon consumes the original key-down event (returns noErr), so no
        // NSEvent local monitor is needed for the foreground case.
        let idStruct = EventHotKeyID(
            signature: 0x4255_5359, // 'BUSY' — identifies our app's hotkeys
            id: currentId
        )
        var ref: EventHotKeyRef?
        if RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            toCarbonModifiers(flags),
            idStruct,
            GetApplicationEventTarget(),
            0,
            &ref
        ) == noErr, let ref {
            hotKeyRefs.append(ref)
            shortcutsByHotKeyId[currentId] = shortcut
        }
    }

    private func handleShortcutActivation(_ shortcut: KeyboardShortcutConfig) {
        let entityId = shortcut.sceneEntityId

        // Toggle: if this scene is already active, deactivate it.
        if AppSettings.shared.activeSceneId == entityId {
            MenuBarManager.shared.deactivateScene()
        } else {
            MenuBarManager.shared.activateScene(entityId: entityId)
        }
    }

    /// Converts `NSEvent.ModifierFlags` to Carbon modifier flags.
    ///
    /// Carbon and Cocoa use different bit positions for modifier keys:
    /// - `cmdKey`     (`0x0100`) ← `.command`
    /// - `shiftKey`   (`0x0200`) ← `.shift`
    /// - `optionKey`  (`0x0800`) ← `.option`
    /// - `controlKey` (`0x1000`) ← `.control`
    private func toCarbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.shift)   { mods |= UInt32(shiftKey) }
        if flags.contains(.option)  { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        return mods
    }
}
