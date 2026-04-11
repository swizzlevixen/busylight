import AppKit

/// Snapshot-based undo handler for the Scenes tab.
///
/// Captures the full `(menuItems, keyboardShortcuts)` state before each
/// mutation. Restoring a snapshot re-triggers `didSet` on `AppSettings`,
/// which persists to UserDefaults and fires `@Observable` updates to the
/// menu bar and hotkey manager.
@MainActor
final class SceneUndoHandler {
    weak var undoManager: UndoManager?

    /// Call **before** every mutation to capture the current state.
    func saveSnapshot(actionName: String) {
        let savedMenuItems = AppSettings.shared.menuItems
        let savedShortcuts = AppSettings.shared.keyboardShortcuts

        undoManager?.registerUndo(withTarget: self) { handler in
            MainActor.assumeIsolated {
                handler.restoreSnapshot(
                    menuItems: savedMenuItems,
                    shortcuts: savedShortcuts,
                    actionName: actionName
                )
            }
        }
        undoManager?.setActionName(actionName)
    }

    private func restoreSnapshot(
        menuItems: [MenuListItem],
        shortcuts: [KeyboardShortcutConfig],
        actionName: String
    ) {
        // Register current state as redo before restoring.
        saveSnapshot(actionName: actionName)
        // Restore — triggers didSet → UserDefaults save + @Observable.
        AppSettings.shared.menuItems = menuItems
        AppSettings.shared.keyboardShortcuts = shortcuts
    }
}
