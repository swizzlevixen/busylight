import Foundation
import CoreMediaIO

extension Notification.Name {
    static let cameraStateChanged = Notification.Name("BusyLight.cameraStateChanged")
}

@MainActor
@Observable
final class CameraMonitor {
    static let shared = CameraMonitor()

    private(set) var isCameraOn = false
    private var pollingTimer: Timer?
    private var isMonitoring = false

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        // Allow discovery of all devices including DAL plugins
        var allow: UInt32 = 1
        var prop = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        CMIOObjectSetPropertyData(
            CMIOObjectID(kCMIOObjectSystemObject),
            &prop, 0, nil,
            UInt32(MemoryLayout<UInt32>.size), &allow
        )

        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkCameraState()
            }
        }
        checkCameraState()
    }

    func stopMonitoring() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        isMonitoring = false
    }

    private func checkCameraState() {
        let wasOn = isCameraOn
        isCameraOn = isAnyCameraRunning()
        if wasOn != isCameraOn {
            NotificationCenter.default.post(
                name: .cameraStateChanged,
                object: nil,
                userInfo: ["isOn": isCameraOn]
            )
        }
    }

    private func isAnyCameraRunning() -> Bool {
        var dataSize: UInt32 = 0
        var devicesProp = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )

        var status = CMIOObjectGetPropertyDataSize(
            CMIOObjectID(kCMIOObjectSystemObject),
            &devicesProp, 0, nil, &dataSize
        )
        guard status == kCMIOHardwareNoError, dataSize > 0 else { return false }

        let deviceCount = Int(dataSize) / MemoryLayout<CMIOObjectID>.size
        var devices = [CMIOObjectID](repeating: 0, count: deviceCount)
        status = CMIOObjectGetPropertyData(
            CMIOObjectID(kCMIOObjectSystemObject),
            &devicesProp, 0, nil,
            dataSize, &dataSize, &devices
        )
        guard status == kCMIOHardwareNoError else { return false }

        for device in devices {
            var isRunning: UInt32 = 0
            var runningDataSize = UInt32(MemoryLayout<UInt32>.size)
            var runningProp = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
            )

            let runStatus = CMIOObjectGetPropertyData(
                device, &runningProp, 0, nil,
                runningDataSize, &runningDataSize, &isRunning
            )

            if runStatus == kCMIOHardwareNoError && isRunning == 1 {
                return true
            }
        }
        return false
    }
}
