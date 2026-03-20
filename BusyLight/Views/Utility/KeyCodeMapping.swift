import Foundation

/// Shared macOS virtual key code → symbol mappings used by both the shortcut
/// recorder (Settings UI) and the menu bar shortcut hints.
enum KeyCodeMapping {

    // MARK: - Display strings (Settings UI)

    /// Human-readable display string for a key code.
    /// Letters are uppercase; special keys use their standard Mac symbols.
    static func displayString(for keyCode: UInt16) -> String {
        displayMap[keyCode] ?? "Key\(keyCode)"
    }

    // MARK: - KeyEquivalent characters (menu hints)

    /// Character suitable for SwiftUI `KeyEquivalent`.
    /// Letters are lowercase (SwiftUI uppercases for display automatically).
    /// Returns `nil` for unmappable key codes.
    static func keyEquivalent(for keyCode: UInt16) -> Character? {
        keyEquivalentMap[keyCode]
    }

    // MARK: - Maps

    private static let displayMap: [UInt16: String] = [
        // Letters
        0: "A",  1: "S",  2: "D",  3: "F",  4: "H",  5: "G",  6: "Z",  7: "X",
        8: "C",  9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
       16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
       23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
       30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
       38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
       45: "N", 46: "M", 47: ".", 50: "`",
        // Whitespace & editing
       36: "\u{21A9}",     // Return ↩
       48: "\u{21E5}",     // Tab ⇥
       49: "Space",
       51: "\u{232B}",     // Delete (backspace) ⌫
       53: "\u{238B}",     // Escape ⎋
       71: "\u{2327}",     // Clear ⌧
       76: "\u{2305}",     // Enter (numpad) ⌅
      117: "\u{2326}",     // Forward Delete ⌦
        // Navigation
      115: "\u{2196}",     // Home ↖
      119: "\u{2198}",     // End ↘
      116: "\u{21DE}",     // Page Up ⇞
      121: "\u{21DF}",     // Page Down ⇟
      123: "\u{2190}",     // Left Arrow ←
      124: "\u{2192}",     // Right Arrow →
      125: "\u{2193}",     // Down Arrow ↓
      126: "\u{2191}",     // Up Arrow ↑
        // Function keys
      122: "F1",  120: "F2",   99: "F3",  118: "F4",
       96: "F5",   97: "F6",   98: "F7",  100: "F8",
      101: "F9",  109: "F10", 103: "F11", 111: "F12",
      105: "F13", 107: "F14", 113: "F15",
        // Misc
      114: "Help",
    ]

    private static let keyEquivalentMap: [UInt16: Character] = [
        // Letters (lowercase for KeyEquivalent)
        0: "a",  1: "s",  2: "d",  3: "f",  4: "h",  5: "g",  6: "z",  7: "x",
        8: "c",  9: "v", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r",
       16: "y", 17: "t", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
       23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
       30: "]", 31: "o", 32: "u", 33: "[", 34: "i", 35: "p", 37: "l",
       38: "j", 39: "'", 40: "k", 41: ";", 42: "\\", 43: ",", 44: "/",
       45: "n", 46: "m", 47: ".", 49: " ", 50: "`",
        // Whitespace & editing
       36: "\u{0D}",       // Return
       48: "\u{09}",       // Tab
       51: "\u{08}",       // Delete (backspace)
       53: "\u{1B}",       // Escape
       71: "\u{F739}",     // Clear
       76: "\u{03}",       // Enter (numpad)
      117: "\u{F728}",     // Forward Delete
        // Navigation
      115: "\u{F729}",     // Home
      119: "\u{F72B}",     // End
      116: "\u{F72C}",     // Page Up
      121: "\u{F72D}",     // Page Down
      123: "\u{F702}",     // Left Arrow
      124: "\u{F703}",     // Right Arrow
      125: "\u{F701}",     // Down Arrow
      126: "\u{F700}",     // Up Arrow
        // Function keys
      122: "\u{F704}",     // F1
      120: "\u{F705}",     // F2
       99: "\u{F706}",     // F3
      118: "\u{F707}",     // F4
       96: "\u{F708}",     // F5
       97: "\u{F709}",     // F6
       98: "\u{F70A}",     // F7
      100: "\u{F70B}",     // F8
      101: "\u{F70C}",     // F9
      109: "\u{F70D}",     // F10
      103: "\u{F70E}",     // F11
      111: "\u{F70F}",     // F12
      105: "\u{F710}",     // F13
      107: "\u{F711}",     // F14
      113: "\u{F712}",     // F15
        // Misc
      114: "\u{F746}",     // Help
    ]
}
