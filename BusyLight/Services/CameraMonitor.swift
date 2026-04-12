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
    private var isMonitoring = false

    /// Blocks registered with CMIOObjectAddPropertyListenerBlock, keyed by device ID.
    /// Stored so we can pass the same reference to the remove call.
    private var deviceListenerBlocks: [CMIOObjectID: CMIOObjectPropertyListenerBlock] = [:]

    /// Block registered for system device-list changes.
    private var deviceListBlock: (CMIOObjectPropertyListenerBlock)?

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

        registerDeviceListListener()
        registerPerDeviceListeners()
        checkCameraState()
    }

    func stopMonitoring() {
        removeAllListeners()
        isMonitoring = false
    }

    // MARK: - Listeners

    private func registerDeviceListListener() {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )

        let block: CMIOObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in
                self?.handleDeviceListChanged()
            }
        }
        deviceListBlock = block

        CMIOObjectAddPropertyListenerBlock(
            CMIOObjectID(kCMIOObjectSystemObject),
            &address,
            DispatchQueue.main,
            block
        )
    }

    private func handleDeviceListChanged() {
        removePerDeviceListeners()
        registerPerDeviceListeners()
        checkCameraState()
    }

    private func registerPerDeviceListeners() {
        let devices = enumerateDevices()

        for device in devices {
            var runningProp = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
            )

            let block: CMIOObjectPropertyListenerBlock = { [weak self] _, _ in
                Task { @MainActor in
                    self?.checkCameraState()
                }
            }
            deviceListenerBlocks[device] = block

            CMIOObjectAddPropertyListenerBlock(
                device, &runningProp, DispatchQueue.main, block
            )
        }
    }

    private func removePerDeviceListeners() {
        for (device, block) in deviceListenerBlocks {
            var runningProp = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
            )
            CMIOObjectRemovePropertyListenerBlock(
                device, &runningProp, DispatchQueue.main, block
            )
        }
        deviceListenerBlocks.removeAll()
    }

    private func removeAllListeners() {
        removePerDeviceListeners()

        if let block = deviceListBlock {
            var address = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
            )
            CMIOObjectRemovePropertyListenerBlock(
                CMIOObjectID(kCMIOObjectSystemObject),
                &address, DispatchQueue.main, block
            )
            deviceListBlock = nil
        }
    }

    // MARK: - State Check

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
        let devices = enumerateDevices()

        for device in devices {
            var isRunning: UInt32 = 0
            var runningDataSize = UInt32(MemoryLayout<UInt32>.size)
            var runningProp = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
            )

            let status = CMIOObjectGetPropertyData(
                device, &runningProp, 0, nil,
                runningDataSize, &runningDataSize, &isRunning
            )

            if status == kCMIOHardwareNoError && isRunning == 1 {
                return true
            }
        }
        return false
    }

    // MARK: - Device Enumeration

    private func enumerateDevices() -> [CMIOObjectID] {
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
        guard status == kCMIOHardwareNoError, dataSize > 0 else { return [] }

        let deviceCount = Int(dataSize) / MemoryLayout<CMIOObjectID>.size
        var devices = [CMIOObjectID](repeating: 0, count: deviceCount)
        status = CMIOObjectGetPropertyData(
            CMIOObjectID(kCMIOObjectSystemObject),
            &devicesProp, 0, nil,
            dataSize, &dataSize, &devices
        )
        guard status == kCMIOHardwareNoError else { return [] }

        return devices
    }
}
