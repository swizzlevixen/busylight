import SwiftUI
import AppKit

// MARK: - EmojiPickerButton

/// A bordered button showing the current emoji.  Clicking opens the system
/// Character Palette immediately — no intermediate text field is visible.
///
/// EmojiInputProxy owns a persistent, off-screen NSWindow containing an
/// EmojiAnchoredTextView.  Using NSTextView (not NSTextField) is critical:
/// NSTextView implements NSTextInputClient directly so the Character Palette's
/// insertText: arrives without any field-editor indirection.  The window is
/// kept off-screen (not inside the SwiftUI hosting view) to avoid the
/// "Adding NSTextView as subview of NSHostingController.view" restriction.
///
/// EmojiAnchoredTextView overrides firstRect(forCharacterRange:actualRange:) —
/// the NSTextInputClient method the Character Palette calls to position itself —
/// so the palette anchors precisely to the clicked button rather than to the
/// input window's frame origin.
struct EmojiPickerButton: View {
    @Binding var emoji: String

    var body: some View {
        Button {
            // Capture the cursor position now (it's right at the button).
            // Pass it directly to the proxy; EmojiAnchoredTextView.firstRect
            // returns this as the palette anchor so it appears just below
            // the button on screen.
            // macOS screen coordinates have y increasing upward, so subtract
            // to place the anchor (and therefore the palette) below the button.
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

// MARK: - EmojiAnchoredTextView

/// NSTextView subclass that overrides firstRect(forCharacterRange:actualRange:)
/// to point the Character Palette to a caller-specified screen location.
///
/// The Character Palette (and other input methods) call firstRect to ask
/// "where on screen is the text insertion point?", then position themselves
/// relative to the returned rect.  By overriding firstRect here, the proxy
/// can direct the palette to appear at the exact screen position of the
/// clicked emoji button rather than relying on the input window's frame,
/// which provides only a coarse anchor.
final class EmojiAnchoredTextView: NSTextView {
    /// Screen-coordinate rect returned from firstRect when non-zero.
    /// Set this before calling orderFrontCharacterPalette so the palette
    /// anchors to the clicked button's location.  Reset to .zero after
    /// the pick completes.
    var paletteAnchorScreenRect: NSRect = .zero

    override func firstRect(forCharacterRange range: NSRange,
                            actualRange: NSRangePointer?) -> NSRect {
        guard paletteAnchorScreenRect != .zero else {
            return super.firstRect(forCharacterRange: range, actualRange: actualRange)
        }
        return paletteAnchorScreenRect
    }
}

// MARK: - EmojiInputProxy

/// Manages a persistent off-screen EmojiInputWindow containing an
/// EmojiAnchoredTextView that acts as the Character Palette's insertion target.
///
/// Flow:
///   1. pick(near:completion:) is called.
///   2. paletteAnchorScreenRect is set on the text view so firstRect returns
///      the exact button location; the input window is moved near the button.
///   3. The input window is made key; EmojiAnchoredTextView becomes first responder.
///   4. orderFrontCharacterPalette opens the system picker, which calls firstRect
///      to position itself — returning the precise button location.
///   5. The user picks an emoji → insertText: lands in EmojiAnchoredTextView →
///      NSTextViewDelegate.textDidChange fires.
///   6. The completion fires, palette windows are closed, the input window is
///      hidden, paletteAnchorScreenRect is reset, and the Settings window
///      regains key focus.
@MainActor
final class EmojiInputProxy: NSObject, NSTextViewDelegate {
    static let shared = EmojiInputProxy()

    private let inputWindow: EmojiInputWindow
    private let textView: EmojiAnchoredTextView

    private var completion: ((String) -> Void)?
    private var windowsBefore: Set<ObjectIdentifier> = []
    private weak var previousKeyWindow: NSWindow?

    private override init() {
        // Off-screen, properly-sized window. EmojiAnchoredTextView requires a
        // real size to properly initialise its text input context; 1×1 is
        // insufficient.  EmojiInputWindow overrides canBecomeKey so
        // makeKeyAndOrderFront works.
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

        let tv = EmojiAnchoredTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 50))
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

    /// - Parameter screenPoint: The screen coordinate to anchor the Character
    ///   Palette to (typically `NSEvent.mouseLocation` offset as desired).
    ///   This point is written to `paletteAnchorScreenRect` so that
    ///   `firstRect(forCharacterRange:actualRange:)` returns it directly,
    ///   giving the palette a precise anchor rather than the coarse one
    ///   provided by `setFrameOrigin` alone.
    func pick(near screenPoint: NSPoint, completion: @escaping (String) -> Void) {
        self.completion = completion
        previousKeyWindow = NSApp.keyWindow

        // Move the input window near the button so it is on-screen and can
        // become key.  The palette's exact position is controlled by firstRect.
        inputWindow.setFrameOrigin(screenPoint)

        // Tell firstRect where to point the palette.  This is the canonical
        // NSTextInputClient mechanism the Character Palette uses for anchoring,
        // and it overrides any effect the window frame position might have.
        textView.paletteAnchorScreenRect = NSRect(
            origin: screenPoint,
            size: NSSize(width: 1, height: 1)
        )

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

        // Hide the input window, reset the anchor, and return focus to
        // the Settings window.
        inputWindow.orderOut(nil)
        textView.string = ""
        textView.paletteAnchorScreenRect = .zero
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
