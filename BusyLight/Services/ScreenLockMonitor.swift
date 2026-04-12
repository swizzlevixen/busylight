import AppKit

extension Notification.Name {
    static let screenLockStateChanged = Notification.Name("BusyLight.screenLockStateChanged")
}

@MainActor
final class ScreenLockMonitor {
    static let shared = ScreenLockMonitor()

    private var lockObserver: NSObjectProtocol?
    private var unlockObserver: NSObjectProtocol?
    private var sleepObserver: NSObjectProtocol?
    private var isMonitoring = false

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        let dnc = DistributedNotificationCenter.default()

        lockObserver = dnc.addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil, queue: .main
        ) { _ in
            NotificationCenter.default.post(
                name: .screenLockStateChanged,
                object: nil,
                userInfo: ["isLocked": true]
            )
        }

        unlockObserver = dnc.addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil, queue: .main
        ) { _ in
            NotificationCenter.default.post(
                name: .screenLockStateChanged,
                object: nil,
                userInfo: ["isLocked": false]
            )
        }

        let workspace = NSWorkspace.shared.notificationCenter

        sleepObserver = workspace.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil, queue: .main
        ) { _ in
            NotificationCenter.default.post(
                name: .screenLockStateChanged,
                object: nil,
                userInfo: ["isLocked": true]
            )
        }

    }

    func stopMonitoring() {
        let dnc = DistributedNotificationCenter.default()
        if let o = lockObserver { dnc.removeObserver(o) }
        if let o = unlockObserver { dnc.removeObserver(o) }

        let workspace = NSWorkspace.shared.notificationCenter
        if let o = sleepObserver { workspace.removeObserver(o) }

        lockObserver = nil
        unlockObserver = nil
        sleepObserver = nil
        isMonitoring = false
    }
}
