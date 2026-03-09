import XCTest
@testable import BusyLight

// MARK: - Character.isEmoji tests

final class CharacterIsEmojiTests: XCTestCase {

    // MARK: Standard emoji (single codepoint with emoji presentation)

    func testRedCircleIsEmoji() {
        XCTAssertTrue(Character("🔴").isEmoji)
    }

    func testGreenCircleIsEmoji() {
        XCTAssertTrue(Character("🟢").isEmoji)
    }

    func testSmileIsEmoji() {
        XCTAssertTrue(Character("😀").isEmoji)
    }

    func testThumbsUpIsEmoji() {
        XCTAssertTrue(Character("👍").isEmoji)
    }

    func testLaptopIsEmoji() {
        XCTAssertTrue(Character("💻").isEmoji)
    }

    func testFireIsEmoji() {
        XCTAssertTrue(Character("🔥").isEmoji)
    }

    // MARK: Multi-scalar emoji sequences

    func testFlagEmojiIsEmoji() {
        // 🇺🇸 = U+1F1FA + U+1F1F8 (regional indicator letters)
        XCTAssertTrue(Character("🇺🇸").isEmoji)
    }

    func testSkinToneModifiedThumbsUpIsEmoji() {
        // 👍🏽 = U+1F44D + U+1F3FD (medium skin tone)
        XCTAssertTrue(Character("👍🏽").isEmoji)
    }

    func testFamilyZWJSequenceIsEmoji() {
        // 👨‍👩‍👧 = ZWJ sequence
        XCTAssertTrue(Character("👨‍👩‍👧").isEmoji)
    }

    func testCheckmarkWithVariationSelectorIsEmoji() {
        // ✅ is single emoji-presentation codepoint
        XCTAssertTrue(Character("✅").isEmoji)
    }

    // MARK: Non-emoji characters

    func testLatinLetterIsNotEmoji() {
        XCTAssertFalse(Character("A").isEmoji)
    }

    func testDigitIsNotEmoji() {
        XCTAssertFalse(Character("5").isEmoji)
    }

    func testSpaceIsNotEmoji() {
        XCTAssertFalse(Character(" ").isEmoji)
    }

    func testPunctuationIsNotEmoji() {
        XCTAssertFalse(Character("!").isEmoji)
    }

    func testNewlineIsNotEmoji() {
        XCTAssertFalse(Character("\n").isEmoji)
    }

    func testCJKCharacterIsNotEmoji() {
        XCTAssertFalse(Character("中").isEmoji)
    }
}

// MARK: - EmojiInputWindow tests

final class EmojiInputWindowTests: XCTestCase {

    func testCanBecomeKey() {
        let win = EmojiInputWindow(
            contentRect: NSRect(x: -600, y: 200, width: 200, height: 50),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        XCTAssertTrue(win.canBecomeKey,
            "EmojiInputWindow must return true from canBecomeKey so makeKeyAndOrderFront succeeds")
    }

    func testCannotBecomeMain() {
        let win = EmojiInputWindow(
            contentRect: NSRect(x: -600, y: 200, width: 200, height: 50),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        XCTAssertFalse(win.canBecomeMain,
            "EmojiInputWindow should not become the main window")
    }

    func testPlainNSWindowCannotBecomeKey() {
        // Confirms the root cause: a plain borderless NSWindow returns NO,
        // which is why EmojiInputWindow is needed.
        let plain = NSWindow(
            contentRect: NSRect(x: -600, y: 200, width: 200, height: 50),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        XCTAssertFalse(plain.canBecomeKey,
            "A plain borderless NSWindow cannot become key — this is the bug EmojiInputWindow fixes")
    }
}

// MARK: - EmojiInputProxy tests

@MainActor
final class EmojiInputProxyTests: XCTestCase {

    func testSharedIsSingleton() {
        let a = EmojiInputProxy.shared
        let b = EmojiInputProxy.shared
        XCTAssertTrue(a === b)
    }

    func testInputWindowIsEmojiInputWindow() {
        // Verify the proxy uses EmojiInputWindow (not plain NSWindow) so it
        // can actually become key and receive Character Palette input.
        let proxy = EmojiInputProxy.shared
        // Access via Mirror since inputWindow is private.
        let mirror = Mirror(reflecting: proxy)
        let windowChild = mirror.children.first { $0.label == "inputWindow" }
        XCTAssertNotNil(windowChild, "EmojiInputProxy should have an inputWindow property")
        if let win = windowChild?.value as? NSWindow {
            XCTAssertTrue(win.canBecomeKey,
                "EmojiInputProxy.inputWindow must be able to become key")
        }
    }

    func testInputWindowIsOffScreen() {
        let proxy = EmojiInputProxy.shared
        let mirror = Mirror(reflecting: proxy)
        let windowChild = mirror.children.first { $0.label == "inputWindow" }
        if let win = windowChild?.value as? NSWindow {
            // Window should be positioned off the visible screen area.
            XCTAssertLessThan(win.frame.origin.x, 0,
                "inputWindow x should be negative (off-screen)")
        }
    }
}
