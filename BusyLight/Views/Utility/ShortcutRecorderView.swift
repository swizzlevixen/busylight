import SwiftUI
import AppKit

// MARK: - ShortcutRecorderView

/// Bordered button that records a keyboard shortcut for a scene.
///
/// Click to enter recording mode ("Press keys…"). The first key event that
/// contains at least one of ⌘ ⌃ ⌥ is saved as the shortcut. Pressing Escape
/// or clicking the button again cancels recording without saving.
///
/// Key capture uses `NSEvent.addLocalMonitorForEvents(matching: .keyDown)`,
/// which intercepts events in the app's event queue before they reach any
/// responder. This works inside SwiftUI List cells (ViewBridge remote process)
/// because the monitor runs in the host process, not the remote view.
struct ShortcutRecorderView: View {
    let sceneEntityId: String
    var onWillChange: (() -> Void)?
    @State private var settings = AppSettings.shared
    @State private var isRecording = false
    @State private var keyMonitor = LocalKeyEventMonitor()

    var body: some View {
        Button {
            if isRecording {
                keyMonitor.remove()
                isRecording = false
            } else {
                startRecording()
            }
        } label: {
            Text(isRecording ? "Press keys\u{2026}" : shortcutDisplayText)
                .frame(width: 100)
                .foregroundStyle(isRecording ? .blue : .primary)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .onDisappear {
            // Cancel any in-progress recording if the view is removed (e.g.
            // the scene row is deleted while the recorder is active).
            keyMonitor.remove()
            isRecording = false
        }
    }

    // MARK: - Private

    private var shortcutDisplayText: String {
        if let sc = settings.keyboardShortcuts.first(where: { $0.sceneEntityId == sceneEntityId }) {
            return modifiersToString(sc.modifiers) + keyCodeToString(sc.keyCode)
        }
        return "None"
    }

    private func startRecording() {
        isRecording = true
        keyMonitor.install { [sceneEntityId] keyCode, modifiers in
            // Capture undo snapshot before mutating shortcuts.
            onWillChange?()
            // Upsert: remove any existing shortcut for this scene, then add the new one.
            var shortcuts = settings.keyboardShortcuts
            shortcuts.removeAll { $0.sceneEntityId == sceneEntityId }
            shortcuts.append(KeyboardShortcutConfig(
                keyCode: keyCode,
                modifiers: modifiers,
                sceneEntityId: sceneEntityId
            ))
            settings.keyboardShortcuts = shortcuts
            isRecording = false
        } onCancel: {
            isRecording = false
        }
    }

    // MARK: - Display formatting

    private func modifiersToString(_ modifiers: UInt) -> String {
        var result = ""
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        if flags.contains(.control) { result += "\u{2303}" }   // ⌃
        if flags.contains(.option)  { result += "\u{2325}" }   // ⌥
        if flags.contains(.shift)   { result += "\u{21E7}" }   // ⇧
        if flags.contains(.command) { result += "\u{2318}" }   // ⌘
        return result
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String {
        KeyCodeMapping.displayString(for: keyCode)
    }
}

// MARK: - LocalKeyEventMonitor

/// One-shot local NSEvent key monitor used by ShortcutRecorderView.
///
/// `addLocalMonitorForEvents(matching: .keyDown)` intercepts key-down events
/// before they reach the first responder, so no focused NSView is required.
/// The monitor automatically removes itself after recording a valid shortcut
/// or after Escape is pressed.
///
/// Marked `@unchecked Sendable` so it can be stored in `@State`; the monitor
/// token is only ever installed and removed on the main thread.
final class LocalKeyEventMonitor: @unchecked Sendable {
    private var monitor: Any?

    /// Install the monitor, replacing any previously installed one.
    ///
    /// - Parameters:
    ///   - onRecorded: Called on the main actor with `(keyCode, modifiers)` when
    ///     the user presses a valid shortcut (must include ⌘, ⌃, or ⌥).
    ///   - onCancel: Called on the main actor when Escape is pressed.
    func install(
        onRecorded: @escaping @MainActor (UInt16, UInt) -> Void,
        onCancel:   @escaping @MainActor () -> Void
    ) {
        remove()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in

            // Bare modifier keypresses (⇧ ⌘ ⌥ ⌃ Fn CapsLock, right-side variants)
            // are not valid shortcut keys on their own; wait for a character key.
            let modifierOnlyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
            guard !modifierOnlyCodes.contains(event.keyCode) else { return event }

            // Escape cancels recording.
            if event.keyCode == 53 {
                self?.remove()
                Task { @MainActor in onCancel() }
                return nil   // consume; don't let Esc close the window
            }

            // Require at least ⌘, ⌃, or ⌥ so we don't swallow plain keystrokes
            // that might be directed at another field in the Settings window
            // while the user accidentally left recording active.
            let required = event.modifierFlags.intersection([.command, .control, .option])
            guard !required.isEmpty else { return event }

            let keyCode  = event.keyCode
            let modifiers = event.modifierFlags
                .intersection([.command, .control, .option, .shift])
                .rawValue

            self?.remove()
            Task { @MainActor in onRecorded(keyCode, modifiers) }
            return nil   // consume the event
        }
    }

    /// Remove the monitor if one is installed.
    func remove() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }

    deinit {
        if let m = monitor {
            NSEvent.removeMonitor(m)
        }
    }
}
