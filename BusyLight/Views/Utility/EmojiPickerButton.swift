import SwiftUI
import AppKit

/// A button that displays the current emoji and opens the system emoji picker when clicked.
/// Only allows a single emoji character to be set.
struct EmojiPickerButton: View {
    @Binding var emoji: String

    var body: some View {
        EmojiFieldRepresentable(emoji: $emoji)
            .frame(width: 36, height: 28)
    }
}

// MARK: - EmojiTextField (NSTextField subclass)

/// NSTextField subclass that opens the system Character Palette whenever the
/// user clicks on it.  The palette sends its chosen character to whatever is
/// currently first-responder — which will be this field's field editor — so
/// the existing `controlTextDidChange` delegate method picks it up normally.
class EmojiTextField: NSTextField {
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        // Defer so the field editor (first responder) is in place before the
        // palette is shown; otherwise the palette has nowhere to send input.
        DispatchQueue.main.async {
            NSApp.orderFrontCharacterPalette(nil)
        }
    }
}

// MARK: - EmojiFieldRepresentable

/// NSViewRepresentable wrapping an EmojiTextField that opens the system Character Palette
/// and restricts input to a single emoji character.
struct EmojiFieldRepresentable: NSViewRepresentable {
    @Binding var emoji: String

    func makeNSView(context: Context) -> EmojiTextField {
        let textField = EmojiTextField()
        textField.stringValue = emoji
        textField.alignment = .center
        textField.font = NSFont.systemFont(ofSize: 18)
        textField.isBordered = true
        textField.isBezeled = true
        textField.bezelStyle = .roundedBezel
        textField.isEditable = true
        textField.isSelectable = true
        textField.delegate = context.coordinator
        textField.setContentHuggingPriority(.required, for: .horizontal)
        return textField
    }

    func updateNSView(_ nsView: EmojiTextField, context: Context) {
        if nsView.stringValue != emoji {
            nsView.stringValue = emoji
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(emoji: $emoji)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var emoji: Binding<String>

        init(emoji: Binding<String>) {
            self.emoji = emoji
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            let text = textField.stringValue

            // Extract only the first emoji character
            if let firstEmoji = text.first, firstEmoji.isEmoji {
                let emojiString = String(firstEmoji)
                if text != emojiString {
                    textField.stringValue = emojiString
                }
                emoji.wrappedValue = emojiString
            } else if text.isEmpty {
                // Allow clearing, but reset to a default emoji
                emoji.wrappedValue = "\u{1F3AC}" // 🎬
                textField.stringValue = "\u{1F3AC}"
            } else {
                // Non-emoji character entered; revert
                textField.stringValue = emoji.wrappedValue
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                // Dismiss on Enter
                control.window?.makeFirstResponder(nil)
                return true
            }
            return false
        }
    }
}

// MARK: - Character emoji detection

extension Character {
    /// Returns true if this character is an emoji (including multi-scalar sequences like flags and skin tones).
    var isEmoji: Bool {
        guard let firstScalar = unicodeScalars.first else { return false }

        // Emoji presentation sequences
        if firstScalar.properties.isEmoji && firstScalar.properties.isEmojiPresentation {
            return true
        }

        // Characters that become emoji with variation selector (e.g., digit + FE0F)
        if unicodeScalars.count > 1 {
            return unicodeScalars.contains(where: { $0.properties.isEmoji })
        }

        return false
    }
}
