import SwiftUI
import AppKit

// MARK: - EmojiPickerButton

/// A bordered button showing the current emoji.  Clicking opens the system
/// Character Palette immediately — no intermediate text field is visible.
///
/// Because SwiftUI List cells run in a remote-view process, calling
/// orderFrontCharacterPalette from an NSViewRepresentable inside the list fails
/// silently.  EmojiInputProxy works around this by routing input through a
/// hidden, off-screen NSWindow that lives in the normal process context.
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

/// Singleton that owns a hidden, off-screen NSWindow containing a 1×1
/// NSTextField.  When `pick(completion:)` is called:
///   1. The hidden window is made key so its text field can receive input.
///   2. The system Character Palette is opened via orderFrontCharacterPalette.
///   3. The user picks an emoji; controlTextDidChange intercepts it.
///   4. The completion is called, the palette and hidden window are closed,
///      and focus is returned to the Settings window.
@MainActor
final class EmojiInputProxy: NSObject, NSTextFieldDelegate {
    static let shared = EmojiInputProxy()

    private let inputWindow: NSWindow
    private let textField: NSTextField
    private var completion: ((String) -> Void)?
    private weak var characterViewerWindow: NSWindow?
    private weak var previousKeyWindow: NSWindow?

    private override init() {
        // Tiny borderless window placed far off-screen — never visible.
        inputWindow = NSWindow(
            contentRect: NSRect(x: -9999, y: -9999, width: 1, height: 1),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        inputWindow.isOpaque = false
        inputWindow.backgroundColor = .clear
        inputWindow.hasShadow = false
        inputWindow.level = .floating
        inputWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
        textField.isEditable = true
        inputWindow.contentView?.addSubview(textField)

        super.init()
        textField.delegate = self
    }

    /// Open the system Character Palette and call `completion` with the emoji
    /// the user selects.
    func pick(completion: @escaping (String) -> Void) {
        self.completion = completion
        previousKeyWindow = NSApp.keyWindow

        textField.stringValue = ""
        inputWindow.makeKeyAndOrderFront(nil)
        inputWindow.makeFirstResponder(textField)

        // Snapshot the window list so we can identify the palette later.
        let windowsBefore = Set(NSApp.windows.map { ObjectIdentifier($0) })
        NSApp.orderFrontCharacterPalette(nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.characterViewerWindow = NSApp.windows.first {
                !windowsBefore.contains(ObjectIdentifier($0))
            }
        }
    }

    // MARK: NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        guard let tf = obj.object as? NSTextField else { return }
        let text = tf.stringValue

        // Ignore non-emoji keystrokes (e.g. accidental typing).
        guard let first = text.first, first.isEmoji else {
            tf.stringValue = ""
            return
        }

        let picked = String(first)

        // Fire the completion.
        completion?(picked)
        completion = nil

        // Close the Character Palette.
        characterViewerWindow?.orderOut(nil)
        characterViewerWindow = nil

        // Hide the input window and return focus to the Settings window.
        inputWindow.orderOut(nil)
        tf.stringValue = ""
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
