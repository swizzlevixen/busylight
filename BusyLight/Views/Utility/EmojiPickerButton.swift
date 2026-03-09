import SwiftUI
import AppKit

// MARK: - EmojiPickerButton

/// A bordered button showing the current emoji.  Clicking opens the system
/// Character Palette immediately — no intermediate text field is visible.
///
/// EmojiInputProxy injects a transparent 1-pt NSTextView into the existing
/// Settings window (which stays key throughout) and makes it first responder
/// before calling orderFrontCharacterPalette.  Because the Settings window
/// remains key, the palette's insertText: goes directly to our overlay and
/// NSTextViewDelegate.textDidChange fires reliably.
struct EmojiPickerButton: View {
    @Binding var emoji: String

    var body: some View {
        Button {
            EmojiInputProxy.shared.pick { picked in
                emoji = picked
            }
        } label: {
            Text(emoji)
                .font(.system(size: 18))
        }
        .buttonStyle(.bordered)
        .frame(width: 36, height: 28)
    }
}

// MARK: - EmojiInputProxy

/// Manages an invisible NSTextView overlay added to the Settings window.
/// When `pick(completion:)` is called:
///   1. A 1×1, fully-transparent NSTextView is added to the Settings window.
///   2. The Settings window stays key; the overlay becomes first responder.
///   3. The system Character Palette is opened.
///   4. The user picks an emoji; textDidChange intercepts it immediately.
///   5. The completion fires, the palette closes, the overlay is removed, and
///      focus is restored to the previous first responder.
@MainActor
final class EmojiInputProxy: NSObject, NSTextViewDelegate {
    static let shared = EmojiInputProxy()

    private var completion: ((String) -> Void)?
    private weak var characterViewerWindow: NSWindow?
    private weak var overlayView: NSTextView?
    private weak var previousFirstResponder: NSResponder?

    private override init() { super.init() }

    func pick(completion: @escaping (String) -> Void) {
        self.completion = completion

        // The emoji button only appears in the Settings window, so this is
        // always the visible titled window the user is interacting with.
        guard let settingsWindow = NSApp.windows.first(where: {
            $0.isVisible && $0.styleMask.contains(.titled)
        }), let contentView = settingsWindow.contentView else { return }

        previousFirstResponder = settingsWindow.firstResponder

        // 1×1 NSTextView placed in the far corner: completely invisible but
        // within the view hierarchy so it receives insertText: from the palette.
        let tv = NSTextView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
        tv.isEditable = true
        tv.isSelectable = true
        tv.drawsBackground = false
        tv.backgroundColor = .clear
        tv.alphaValue = 0      // invisible; alpha=0 does not block first-responder
        tv.delegate = self
        tv.string = ""
        contentView.addSubview(tv)
        overlayView = tv

        // Settings window stays key; only the first responder changes.
        settingsWindow.makeFirstResponder(tv)

        // Snapshot window list so we can identify the palette window later.
        let windowsBefore = Set(NSApp.windows.map { ObjectIdentifier($0) })
        NSApp.orderFrontCharacterPalette(nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.characterViewerWindow = NSApp.windows.first {
                !windowsBefore.contains(ObjectIdentifier($0))
            }
        }
    }

    // MARK: NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        guard let tv = overlayView else { return }
        let text = tv.string

        guard let first = text.first, first.isEmoji else {
            tv.string = ""   // discard non-emoji keystrokes
            return
        }

        let picked = String(first)

        // Fire callback.
        completion?(picked)
        completion = nil

        // Close the palette and remove the overlay.
        characterViewerWindow?.orderOut(nil)
        characterViewerWindow = nil
        overlayView?.removeFromSuperview()
        overlayView = nil

        // Restore focus to whatever was focused before (usually the button).
        if let prev = previousFirstResponder {
            tv.window?.makeFirstResponder(prev)
        }
        previousFirstResponder = nil
    }
}

// MARK: - Character.isEmoji

extension Character {
    /// True for any emoji character, including multi-scalar sequences (flags, skin tones, ZWJ).
    var isEmoji: Bool {
        guard let first = unicodeScalars.first else { return false }
        if first.properties.isEmoji && first.properties.isEmojiPresentation { return true }
        if unicodeScalars.count > 1 {
            return unicodeScalars.contains { $0.properties.isEmoji }
        }
        return false
    }
}
