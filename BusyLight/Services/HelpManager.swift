import AppKit

/// Thin wrapper around `NSHelpManager` for opening Busy Light Help pages.
enum HelpManager {
    static let bookName: NSHelpManager.BookName = "Busy Light Help"

    /// Opens the Help Viewer to the page identified by `anchor`.
    ///
    /// Anchors correspond to `<a name="…">` tags in the Help Book HTML:
    /// - `"busylight-help"` — landing page
    /// - `"getting-started"` — Getting Started
    /// - `"adding-scenes"` — Adding Scenes
    /// - `"using-triggers"` — Using Triggers
    /// - `"troubleshooting"` — Troubleshooting
    @MainActor static func openHelp(anchor: String = "busylight-help") {
        NSHelpManager.shared.openHelpAnchor(
            anchor as NSHelpManager.AnchorName,
            inBook: bookName
        )
    }
}
