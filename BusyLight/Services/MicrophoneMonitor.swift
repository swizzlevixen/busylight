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
    private var pollingTimer: Timer?
    private var isMonitoring = false

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkMicState()
            }
        }
        checkMicState()
    }

    func stopMonitoring() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        isMonitoring = false
    }

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
        // Get all audio devices
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
        guard status == noErr, propertySize > 0 else { return false }

        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &propertySize, &devices
        )
        guard status == noErr else { return false }

        for device in devices {
            // Check if device has input streams (is a microphone)
            var inputStreamSize: UInt32 = 0
            var inputAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )

            status = AudioObjectGetPropertyDataSize(device, &inputAddress, 0, nil, &inputStreamSize)
            guard status == noErr, inputStreamSize > 0 else { continue }

            // Check if this input device is running
            var isRunning: UInt32 = 0
            var runningSize = UInt32(MemoryLayout<UInt32>.size)
            var runningAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )

            let runStatus = AudioObjectGetPropertyData(
                device, &runningAddress, 0, nil, &runningSize, &isRunning
            )

            if runStatus == noErr && isRunning == 1 {
                return true
            }
        }
        return false
    }
}
