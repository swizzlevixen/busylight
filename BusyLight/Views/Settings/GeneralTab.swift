import SwiftUI
import ServiceManagement

struct GeneralTab: View {
    @State private var settings = AppSettings.shared
    @State private var launchAtLogin = false

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Display") {
                    Picker("Menu bar shows:", selection: $settings.displayMode) {
                        Text("Emoji only").tag(DisplayMode.emojiOnly)
                        Text("Name only").tag(DisplayMode.nameOnly)
                        Text("Both").tag(DisplayMode.both)
                    }
                    .pickerStyle(.radioGroup)
                    // No manual update needed; MenuBarLabelView reacts automatically
                    // via @Observable on AppSettings.displayMode
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
            }
            .formStyle(.grouped)
            .padding()
            .onAppear {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }

            Divider()

            Link(destination: URL(string: "https://ko-fi.com/swizzlevixen")!) {
                Label("Buy Me a Coffee", systemImage: "heart.fill")
            }
            .buttonStyle(.borderedProminent)
            .help(Text("Support Busy Light on Ko-fi"))
            .tint(.yellow)
            .padding()
        }
    }
}
