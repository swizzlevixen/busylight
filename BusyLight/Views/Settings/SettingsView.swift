import SwiftUI

struct SettingsView: View {
    @State private var selectedTab: String = "homeassistant"

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home Assistant", systemImage: "house", value: "homeassistant") {
                HomeAssistantTab()
            }
            Tab("Scenes", systemImage: "theatermasks", value: "scenes") {
                ScenesTab()
            }
            Tab("Triggers", systemImage: "bolt.fill", value: "triggers") {
                TriggersTab()
            }
            Tab("General", systemImage: "gear", value: "general") {
                GeneralTab()
            }
        }
        .frame(minWidth: 600, idealWidth: 600, minHeight: 500)
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsRequest)) { notification in
            if let tab = notification.userInfo?["tab"] as? String {
                selectedTab = tab
            }
        }
    }
}
