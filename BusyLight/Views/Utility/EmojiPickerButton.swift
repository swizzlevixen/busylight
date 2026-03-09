import SwiftUI
import AppKit

// MARK: - EmojiPickerButton

/// A bordered button showing the current emoji.  Clicking opens a small popover
/// that hosts a focused text field and immediately launches the system Character
/// Palette.  Picking an emoji closes both the palette and the popover.
struct EmojiPickerButton: View {
    @Binding var emoji: String
    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover = true
        } label: {
            Text(emoji)
                .font(.system(size: 18))
        }
        .buttonStyle(.bordered)
        .frame(width: 36, height: 28)
        // Popover lives in a normal NSWindow — outside the SwiftUI List remote
        // view process — so orderFrontCharacterPalette works correctly there.
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            EmojiPickerPopover(emoji: $emoji) { showPopover = false }
        }
    }
}

// MARK: - EmojiPickerPopover

/// Content of the popover: a single focused field wired to the Character Palette.
private struct EmojiPickerPopover: View {
    @Binding var emoji: String
    let dismiss: () -> Void

    var body: some View {
        EmojiAutoFieldRepresentable(emoji: $emoji, onPicked: dismiss)
            .frame(width: 52, height: 36)
            .padding(8)
    }
}

// MARK: - EmojiAutoTextField

/// NSTextField subclass that:
///   • Becomes first responder as soon as it enters a window
///   • Opens the system Character Palette immediately
///   • Tracks the palette window so it can close it after one emoji is chosen
class EmojiAutoTextField: NSTextField {
    weak var characterViewerWindow: NSWindow?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let w = window else { return }
        w.makeFirstResponder(self)

        DispatchQueue.main.async { [weak self] in
            // Snapshot the window list so we can identify the new palette window
            let before = Set(NSApp.windows.map { ObjectIdentifier($0) })
            NSApp.orderFrontCharacterPalette(nil)
            // Give the palette a moment to appear, then capture its window
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.characterViewerWindow = NSApp.windows.first {
                    !before.contains(ObjectIdentifier($0))
                }
            }
        }
    }

    /// Dismiss the Character Palette that was opened when this field appeared.
    func closeCharacterViewer() {
        characterViewerWindow?.orderOut(nil)
        characterViewerWindow = nil
    }
}

// MARK: - EmojiAutoFieldRepresentable

struct EmojiAutoFieldRepresentable: NSViewRepresentable {
    @Binding var emoji: String
    let onPicked: () -> Void

    func makeNSView(context: Context) -> EmojiAutoTextField {
        let field = EmojiAutoTextField()
        field.stringValue = emoji
        field.alignment = .center
        field.font = NSFont.systemFont(ofSize: 18)
        field.isBordered = true
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.isEditable = true
        field.isSelectable = true
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ nsView: EmojiAutoTextField, context: Context) {
        if nsView.stringValue != emoji {
            nsView.stringValue = emoji
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(emoji: $emoji, onPicked: onPicked) }

    // MARK: Coordinator

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var emoji: Binding<String>
        let onPicked: () -> Void

        init(emoji: Binding<String>, onPicked: @escaping () -> Void) {
            self.emoji = emoji
            self.onPicked = onPicked
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? EmojiAutoTextField else { return }
            let text = field.stringValue

            if let first = text.first, first.isEmoji {
                let single = String(first)
                if text != single { field.stringValue = single }
                emoji.wrappedValue = single
                // Close the palette then the popover
                field.closeCharacterViewer()
                onPicked()
            } else if text.isEmpty {
                field.stringValue = emoji.wrappedValue   // revert — don't allow blank
            } else {
                field.stringValue = emoji.wrappedValue   // non-emoji typed — revert
            }
        }

        func control(_ control: NSControl, textView: NSTextView,
                     doCommandBy sel: Selector) -> Bool {
            if sel == #selector(NSResponder.insertNewline(_:)) {
                control.window?.makeFirstResponder(nil)
                return true
            }
            return false
        }
    }
}

// MARK: - Character.isEmoji

extension Character {
    /// True for any emoji character, including multi-scalar sequences (flags, skin tones, ZWJ).
    var isEmoji: Bool {
        guard let first = unicodeScalars.first else { return false }
        if first.properties.isEmoji && first.properties.isEmojiPresentation { return true }
        // Digits + variation selector, keycap sequences, etc.
        if unicodeScalars.count > 1 {
            return unicodeScalars.contains { $0.properties.isEmoji }
        }
        return false
    }
}
