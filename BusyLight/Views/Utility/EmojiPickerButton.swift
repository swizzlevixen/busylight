import SwiftUI
import AppKit

// MARK: - EmojiPickerButton

/// A bordered button showing the current emoji.  Clicking opens the system
/// Character Palette immediately — no intermediate text field is visible.
///
/// EmojiInputProxy owns a persistent, off-screen NSWindow containing an
/// NSTextView.  Using NSTextView (not NSTextField) is critical: NSTextView
/// implements NSTextInputClient directly so the Character Palette's
/// insertText: arrives without any field-editor indirection.  The window is
/// kept off-screen (not inside the SwiftUI hosting view) to avoid the
/// "Adding NSTextView as subview of NSHostingController.view" restriction.
struct EmojiPickerButton: View {
    @Binding var emoji: String

    var body: some View {
        Button {
            // Capture the cursor position now (it's right at the button).
            // The proxy moves its input window here so the Character Palette
            // appears attached to this location rather than off-screen.
            // Offset 20 pts below the click so the palette appears just under the button.
            // macOS screen coordinates have y increasing upward, so subtract to go lower.
            let click = NSEvent.mouseLocation
            let clickLocation = NSPoint(x: click.x, y: click.y - 20)
            EmojiInputProxy.shared.pick(near: clickLocation) { picked in
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

// MARK: - EmojiInputWindow

/// Borderless NSWindow subclass that opts into becoming key.
///
/// A plain NSWindow with styleMask [] returns NO from canBecomeKeyWindow,
/// so makeKeyAndOrderFront silently fails, makeFirstResponder has no effect,
/// and the Character Palette never delivers input.  Overriding canBecomeKey
/// here fixes that without needing a visible title bar.
final class EmojiInputWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - EmojiInputProxy

/// Manages a persistent off-screen EmojiInputWindow containing an NSTextView
/// that acts as the Character Palette's insertion target.
///
/// Flow:
///   1. pick(completion:) is called.
///   2. The input window is made key; NSTextView becomes first responder.
///   3. orderFrontCharacterPalette opens the system picker.
///   4. The user picks an emoji → insertText: lands in the NSTextView →
///      NSTextViewDelegate.textDidChange fires.
///   5. The completion fires, new windows are closed (the palette), the input
///      window is hidden, and the Settings window gets key focus back.
@MainActor
final class EmojiInputProxy: NSObject, NSTextViewDelegate {
    static let shared = EmojiInputProxy()

    private let inputWindow: EmojiInputWindow
    private let textView: NSTextView

    private var completion: ((String) -> Void)?
    private var windowsBefore: Set<ObjectIdentifier> = []
    private weak var previousKeyWindow: NSWindow?

    private override init() {
        // Off-screen, properly-sized window. NSTextView requires a real size
        // to properly initialise its text input context; 1×1 is insufficient.
        // EmojiInputWindow overrides canBecomeKey so makeKeyAndOrderFront works.
        let win = EmojiInputWindow(
            contentRect: NSRect(x: -600, y: 200, width: 200, height: 50),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.level = .floating
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let tv = NSTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 50))
        tv.isEditable = true
        tv.isSelectable = true
        tv.backgroundColor = .clear
        tv.drawsBackground = false
        win.contentView?.addSubview(tv)

        inputWindow = win
        textView = tv

        super.init()

        // Delegate set after super.init() since it captures self.
        tv.delegate = self
    }

    /// - Parameter screenPoint: The screen coordinate of the clicked emoji button
    ///   (pass `NSEvent.mouseLocation`).  The input window is repositioned here so
    ///   the Character Palette opens attached to that location.
    func pick(near screenPoint: NSPoint, completion: @escaping (String) -> Void) {
        self.completion = completion
        previousKeyWindow = NSApp.keyWindow

        // Move the input window to the button's screen location so the palette
        // anchors to it instead of to the window's default off-screen position.
        inputWindow.setFrameOrigin(screenPoint)

        textView.string = ""
        inputWindow.makeKeyAndOrderFront(nil)
        inputWindow.makeFirstResponder(textView)

        // Snapshot before opening so we can identify the palette window later.
        windowsBefore = Set(NSApp.windows.map { ObjectIdentifier($0) })
        NSApp.orderFrontCharacterPalette(nil)
    }

    // MARK: NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        let text = textView.string

        guard let first = text.first, first.isEmoji else {
            textView.string = ""   // discard non-emoji keystrokes
            return
        }

        let picked = String(first)

        // Fire the binding update.
        completion?(picked)
        completion = nil

        // Close any windows that appeared after orderFrontCharacterPalette
        // (the palette is hosted in-process and appears in NSApp.windows).
        for window in NSApp.windows where !windowsBefore.contains(ObjectIdentifier(window)) {
            window.orderOut(nil)
        }
        windowsBefore = []

        // Hide the input window and return focus to the Settings window.
        inputWindow.orderOut(nil)
        textView.string = ""
        previousKeyWindow?.makeKeyAndOrderFront(nil)
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
