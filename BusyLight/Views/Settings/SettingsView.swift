import SwiftUI

struct SettingsView: View {
    @State private var selectedTab: String = "homeassistant"

    var body: some View {
        // Tab API requires macOS 15; using tabItem() for macOS 14 compatibility.
        TabView(selection: $selectedTab) {
            HomeAssistantTab()
                .tabItem { Label("Home Assistant", systemImage: "house") }
                .tag("homeassistant")
            ScenesTab()
                .tabItem { Label("Scenes", systemImage: "theatermasks") }
                .tag("scenes")
            TriggersTab()
                .tabItem { Label("Triggers", systemImage: "bolt.fill") }
                .tag("triggers")
            GeneralTab()
                .tabItem { Label("General", systemImage: "gear") }
                .tag("general")
        }
        .frame(minWidth: 600, idealWidth: 600, minHeight: 500)
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsRequest)) { notification in
            if let tab = notification.userInfo?["tab"] as? String {
                selectedTab = tab
            }
        }
    }
}
