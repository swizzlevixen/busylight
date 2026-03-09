import SwiftUI

struct TriggersTab: View {
    @State private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("Webcam") {
                triggerRow(
                    label: "Enable scene when webcam in use:",
                    isEnabled: $settings.webcamTriggerEnabled,
                    sceneId: $settings.webcamOnSceneId
                )
                triggerRow(
                    label: "Enable scene when webcam turned off:",
                    isEnabled: $settings.webcamOffTriggerEnabled,
                    sceneId: $settings.webcamOffSceneId
                )
            }

            Section("Microphone") {
                triggerRow(
                    label: "Enable scene when microphone in use:",
                    isEnabled: $settings.micTriggerEnabled,
                    sceneId: $settings.micOnSceneId
                )
                triggerRow(
                    label: "Enable scene when microphone turned off:",
                    isEnabled: $settings.micOffTriggerEnabled,
                    sceneId: $settings.micOffSceneId
                )
            }

            Section("Screen Lock") {
                triggerRow(
                    label: "Enable scene when screen is locked:",
                    isEnabled: $settings.screenLockTriggerEnabled,
                    sceneId: $settings.screenLockSceneId
                )
                triggerRow(
                    label: "Enable scene when screen is unlocked:",
                    isEnabled: $settings.screenUnlockTriggerEnabled,
                    sceneId: $settings.screenUnlockSceneId
                )
            }

            Section("Focus Mode") {
                triggerRow(
                    label: "Enable scene when Focus mode activated:",
                    isEnabled: $settings.focusOnTriggerEnabled,
                    sceneId: $settings.focusOnSceneId
                )
                triggerRow(
                    label: "Enable scene when Focus mode deactivated:",
                    isEnabled: $settings.focusOffTriggerEnabled,
                    sceneId: $settings.focusOffSceneId
                )

                Text("Focus mode detection is experimental and may not work on all macOS versions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    @ViewBuilder
    private func triggerRow(label: String, isEnabled: Binding<Bool>, sceneId: Binding<String>) -> some View {
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
