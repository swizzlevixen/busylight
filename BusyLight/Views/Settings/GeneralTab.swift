import SwiftUI
import ServiceManagement

struct GeneralTab: View {
    @State private var settings = AppSettings.shared
    @State private var launchAtLogin = false

    var body: some View {
        Form {
            Section("Display") {
                Picker("Menu bar shows:", selection: $settings.displayMode) {
                    Text("Emoji only").tag(DisplayMode.emojiOnly)
                    Text("Name only").tag(DisplayMode.nameOnly)
                    Text("Both").tag(DisplayMode.both)
                }
                .pickerStyle(.radioGroup)
                .onChange(of: settings.displayMode) { _, _ in
                    MenuBarManager.shared.updateButtonTitle()
                }
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            // Revert toggle on failure
                            launchAtLogin = !newValue
                        }
                    }
            }

            Section("Keyboard Shortcuts") {
                if settings.scenes.isEmpty {
                    Text("Add scenes in the Scenes tab to configure keyboard shortcuts.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(settings.scenes) { scene in
                        HStack {
                            Text("\(scene.emoji) \(scene.displayName)")
                            Spacer()
                            ShortcutRecorderView(sceneEntityId: scene.entityId)
                        }
                    }
                }

                Text("Keyboard shortcuts allow you to activate scenes from anywhere, even when the app is not focused.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: - Shortcut Recorder

struct ShortcutRecorderView: View {
    let sceneEntityId: String
    @State private var settings = AppSettings.shared
    @State private var isRecording = false
    @State private var displayText: String = ""

    var body: some View {
        Button(action: {
            isRecording.toggle()
        }) {
            Text(isRecording ? "Press keys\u{2026}" : shortcutDisplayText)
                .frame(width: 120)
                .foregroundStyle(isRecording ? .blue : .primary)
        }
        .buttonStyle(.bordered)
        .onAppear {
            updateDisplayText()
        }
    }

    private var shortcutDisplayText: String {
        if let shortcut = settings.keyboardShortcuts.first(where: { $0.sceneEntityId == sceneEntityId }) {
            return modifiersToString(shortcut.modifiers) + keyCodeToString(shortcut.keyCode)
        }
        return "None"
    }

    private func updateDisplayText() {
        displayText = shortcutDisplayText
    }

    private func modifiersToString(_ modifiers: UInt) -> String {
        var result = ""
        let flags = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        if flags.contains(.control) { result += "\u{2303}" }
        if flags.contains(.option) { result += "\u{2325}" }
        if flags.contains(.shift) { result += "\u{21E7}" }
        if flags.contains(.command) { result += "\u{2318}" }
        return result
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String {
        let keyMap: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 40: "K", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
            49: "Space", 51: "Delete", 53: "Esc",
        ]
        return keyMap[keyCode] ?? "Key\(keyCode)"
    }
}
