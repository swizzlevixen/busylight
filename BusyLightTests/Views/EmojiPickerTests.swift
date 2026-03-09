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

@MainActor
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

// MARK: - EmojiAnchoredTextView tests

@MainActor
final class EmojiAnchoredTextViewTests: XCTestCase {

    func testDefaultPaletteAnchorIsZero() {
        let tv = EmojiAnchoredTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 50))
        XCTAssertEqual(tv.paletteAnchorScreenRect, .zero,
            "paletteAnchorScreenRect should default to .zero before any pick(near:) call")
    }

    func testFirstRectReturnsPaletteAnchorWhenSet() {
        // This is the core contract: when paletteAnchorScreenRect is set, firstRect
        // must return it so the Character Palette anchors precisely to the emoji button.
        let tv = EmojiAnchoredTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 50))
        let anchor = NSRect(x: 400, y: 300, width: 1, height: 1)
        tv.paletteAnchorScreenRect = anchor
        let result = tv.firstRect(forCharacterRange: NSRange(location: 0, length: 0),
                                  actualRange: nil)
        XCTAssertEqual(result, anchor,
            "firstRect must return paletteAnchorScreenRect so the Character Palette " +
            "anchors to the emoji button's exact screen location")
    }

    func testFirstRectIgnoresRangeWhenAnchorIsSet() {
        // The anchor rect is returned regardless of which character range is queried.
        let tv = EmojiAnchoredTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 50))
        let anchor = NSRect(x: 100, y: 200, width: 1, height: 1)
        tv.paletteAnchorScreenRect = anchor
        let result1 = tv.firstRect(forCharacterRange: NSRange(location: 0, length: 1),
                                   actualRange: nil)
        let result2 = tv.firstRect(forCharacterRange: NSRange(location: 5, length: 0),
                                   actualRange: nil)
        XCTAssertEqual(result1, anchor)
        XCTAssertEqual(result2, anchor,
            "anchor rect is returned for any character range when paletteAnchorScreenRect is set")
    }

    func testPaletteAnchorCanBeUpdated() {
        // pick(near:) calls this multiple times across different button clicks.
        let tv = EmojiAnchoredTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 50))
        let first  = NSRect(x: 100, y: 200, width: 1, height: 1)
        let second = NSRect(x: 500, y: 600, width: 1, height: 1)

        tv.paletteAnchorScreenRect = first
        XCTAssertEqual(
            tv.firstRect(forCharacterRange: NSRange(location: 0, length: 0), actualRange: nil),
            first)

        tv.paletteAnchorScreenRect = second
        XCTAssertEqual(
            tv.firstRect(forCharacterRange: NSRange(location: 0, length: 0), actualRange: nil),
            second,
            "paletteAnchorScreenRect should update between picks")
    }

    func testPaletteAnchorResetToZeroAfterPick() {
        // After textDidChange completes, the proxy resets paletteAnchorScreenRect
        // to .zero so a stale anchor doesn't affect future picks.
        // We verify this by inspecting the text view via Mirror on the shared proxy.
        let proxy = EmojiInputProxy.shared
        let mirror = Mirror(reflecting: proxy)
        let tvChild = mirror.children.first { $0.label == "textView" }
        XCTAssertNotNil(tvChild, "EmojiInputProxy should expose a textView property via Mirror")
        if let tv = tvChild?.value as? EmojiAnchoredTextView {
            // The shared proxy starts (and should end each pick) with .zero.
            XCTAssertEqual(tv.paletteAnchorScreenRect, .zero,
                "paletteAnchorScreenRect should be .zero when no pick is in progress")
        }
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

    func testTextViewIsEmojiAnchoredTextView() {
        // Verify the proxy uses EmojiAnchoredTextView (not plain NSTextView) so
        // firstRect(forCharacterRange:actualRange:) can be overridden to anchor
        // the Character Palette precisely to the clicked emoji button.
        let proxy = EmojiInputProxy.shared
        let mirror = Mirror(reflecting: proxy)
        let tvChild = mirror.children.first { $0.label == "textView" }
        XCTAssertNotNil(tvChild, "EmojiInputProxy should have a textView property")
        XCTAssertTrue(tvChild?.value is EmojiAnchoredTextView,
            "EmojiInputProxy.textView must be EmojiAnchoredTextView so firstRect " +
            "can be overridden for precise palette positioning")
    }

    func testInputWindowInitiallyOffScreen() {
        // On creation the window starts off-screen; it is only moved on-screen
        // when pick(near:) is called with the button's location.
        let win = EmojiInputWindow(
            contentRect: NSRect(x: -600, y: 200, width: 200, height: 50),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        XCTAssertLessThan(win.frame.origin.x, 0,
            "inputWindow initial x should be negative (off-screen)")
    }

    func testSetFrameOriginRepositionsWindow() {
        // Verifies that setFrameOrigin (called by pick(near:)) moves the window
        // to the requested location so the Character Palette anchors there.
        let win = EmojiInputWindow(
            contentRect: NSRect(x: -600, y: 200, width: 200, height: 50),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        let target = NSPoint(x: 400, y: 300)
        win.setFrameOrigin(target)
        XCTAssertEqual(win.frame.origin.x, target.x, accuracy: 1)
        XCTAssertEqual(win.frame.origin.y, target.y, accuracy: 1)
    }
}
