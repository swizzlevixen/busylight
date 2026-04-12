import Foundation

extension Notification.Name {
    static let focusModeChanged = Notification.Name("BusyLight.focusModeChanged")
}

@MainActor
@Observable
final class FocusModeMonitor {
    static let shared = FocusModeMonitor()

    private(set) var isFocusActive = false
    private var pollingTimer: Timer?
    private var isMonitoring = false
    private(set) var isAvailable = true

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        pollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkFocusState()
            }
        }
        checkFocusState()
    }

    func stopMonitoring() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        isMonitoring = false
    }

    private func checkFocusState() {
        guard isAvailable else { return }

        let wasActive = isFocusActive
        isFocusActive = checkDNDAssertions()
        if wasActive != isFocusActive {
            NotificationCenter.default.post(
                name: .focusModeChanged,
                object: nil,
                userInfo: ["isActive": isFocusActive]
            )
        }
    }

    /// Read DND assertion state from the system database.
    /// This is non-sandboxed only and may break across macOS versions.
    private func checkDNDAssertions() -> Bool {
        let assertionsPath = NSHomeDirectory() + "/Library/DoNotDisturb/DB/Assertions.json"
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: assertionsPath) else {
            // File doesn't exist - Focus mode detection not available on this system
            isAvailable = false
            return false
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: assertionsPath))
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            // Check if there are active assertions
            if let storeData = json?["data"] as? [[String: Any]] {
                for store in storeData {
                    if let assertions = store["storeAssertionRecords"] as? [[String: Any]],
                       !assertions.isEmpty {
                        return true
                    }
                }
            }
            return false
        } catch {
            // If we can't read the file, degrade gracefully
            isAvailable = false
            return false
        }
    }
}
