import SwiftUI

struct TriggersTab: View {
    @State private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("Webcam") {
                triggerRow(
                    label: "Activate scene when webcam turns on:",
                    isEnabled: $settings.webcamTriggerEnabled,
                    sceneId: $settings.webcamOnSceneId
                )
                triggerRow(
                    label: "Activate scene when webcam turns off:",
                    isEnabled: $settings.webcamOffTriggerEnabled,
                    sceneId: $settings.webcamOffSceneId
                )
            }

            Section("Microphone") {
                triggerRow(
                    label: "Activate scene when microphone turns on:",
                    isEnabled: $settings.micTriggerEnabled,
                    sceneId: $settings.micOnSceneId
                )
                triggerRow(
                    label: "Activate scene when microphone turns off:",
                    isEnabled: $settings.micOffTriggerEnabled,
                    sceneId: $settings.micOffSceneId
                )
            }

            Section("Screen Lock") {
                triggerRow(
                    label: "Activate scene when screen locks:",
                    isEnabled: $settings.screenLockTriggerEnabled,
                    sceneId: $settings.screenLockSceneId
                )
                triggerRow(
                    label: "Activate scene when screen unlocks:",
                    isEnabled: $settings.screenUnlockTriggerEnabled,
                    sceneId: $settings.screenUnlockSceneId
                )
            }

            Section("Focus Mode") {
                triggerRow(
                    label: "Activate scene when Focus turns on:",
                    isEnabled: $settings.focusOnTriggerEnabled,
                    sceneId: $settings.focusOnSceneId
                )
                .disabled(!FocusModeMonitor.shared.isAvailable)
                triggerRow(
                    label: "Activate scene when Focus turns off:",
                    isEnabled: $settings.focusOffTriggerEnabled,
                    sceneId: $settings.focusOffSceneId
                )
                .disabled(!FocusModeMonitor.shared.isAvailable)

                if FocusModeMonitor.shared.isAvailable {
                    Text("Focus mode detection is experimental and may not work on all macOS versions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Focus mode detection is not available on this version of macOS.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    @ViewBuilder
    private func triggerRow(
        label: String,
        isEnabled: Binding<Bool>,
        sceneId: Binding<String>
    ) -> some View {
        HStack {
            Toggle(label, isOn: isEnabled)

            Spacer()

            Picker("", selection: sceneId) {
                Text("None").tag("")
                ForEach(settings.scenes) { scene in
                    Text("\(scene.emoji) \(scene.displayName)").tag(scene.entityId)
                }
            }
            .frame(width: 200)
            .disabled(!isEnabled.wrappedValue)
        }
    }
}
