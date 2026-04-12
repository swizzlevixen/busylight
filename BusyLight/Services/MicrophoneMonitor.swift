import Foundation
import CoreAudio

extension Notification.Name {
    static let microphoneStateChanged = Notification.Name("BusyLight.microphoneStateChanged")
}

@MainActor
@Observable
final class MicrophoneMonitor {
    static let shared = MicrophoneMonitor()

    private(set) var isMicrophoneOn = false
    private var isMonitoring = false

    /// Blocks registered per device for input-running changes, keyed by device ID.
    private var deviceListenerBlocks: [AudioDeviceID: AudioObjectPropertyListenerBlock] = [:]

    /// Block registered for system device-list changes.
    private var deviceListBlock: AudioObjectPropertyListenerBlock?

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        registerDeviceListListener()
        registerPerDeviceListeners()
        checkMicState()
    }

    func stopMonitoring() {
        removeAllListeners()
        isMonitoring = false
    }

    // MARK: - Listeners

    private func registerDeviceListListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in
                self?.handleDeviceListChanged()
            }
        }
        deviceListBlock = block

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main,
            block
        )
    }

    private func handleDeviceListChanged() {
        removePerDeviceListeners()
        registerPerDeviceListeners()
        checkMicState()
    }

    private func registerPerDeviceListeners() {
        let devices = enumerateInputDevices()

        for device in devices {
            var runningAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )

            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                Task { @MainActor in
                    self?.checkMicState()
                }
            }
            deviceListenerBlocks[device] = block

            AudioObjectAddPropertyListenerBlock(
                device, &runningAddress, DispatchQueue.main, block
            )
        }
    }

    private func removePerDeviceListeners() {
        for (device, block) in deviceListenerBlocks {
            var runningAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(
                device, &runningAddress, DispatchQueue.main, block
            )
        }
        deviceListenerBlocks.removeAll()
    }

    private func removeAllListeners() {
        removePerDeviceListeners()

        if let block = deviceListBlock {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDevices,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &address, DispatchQueue.main, block
            )
            deviceListBlock = nil
        }
    }

    // MARK: - State Check

    private func checkMicState() {
        let wasOn = isMicrophoneOn
        isMicrophoneOn = isAnyMicRunning()
        if wasOn != isMicrophoneOn {
            NotificationCenter.default.post(
                name: .microphoneStateChanged,
                object: nil,
                userInfo: ["isOn": isMicrophoneOn]
            )
        }
    }

    private func isAnyMicRunning() -> Bool {
        let devices = enumerateInputDevices()

        for device in devices {
            var isRunning: UInt32 = 0
            var runningSize = UInt32(MemoryLayout<UInt32>.size)
            var runningAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )

            let status = AudioObjectGetPropertyData(
                device, &runningAddress, 0, nil, &runningSize, &isRunning
            )

            if status == noErr && isRunning == 1 {
                return true
            }
        }
        return false
    }

    // MARK: - Device Enumeration

    /// Returns all audio devices that have at least one input stream.
    private func enumerateInputDevices() -> [AudioDeviceID] {
        var propertySize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &propertySize
        )
        guard status == noErr, propertySize > 0 else { return [] }

        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &propertySize, &devices
        )
        guard status == noErr else { return [] }

        // Filter to devices with input streams
        return devices.filter { device in
            var inputStreamSize: UInt32 = 0
            var inputAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            let s = AudioObjectGetPropertyDataSize(device, &inputAddress, 0, nil, &inputStreamSize)
            return s == noErr && inputStreamSize > 0
        }
    }
}
