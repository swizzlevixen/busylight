import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            HomeAssistantTab()
                .tabItem { Label("Home Assistant", systemImage: "house") }
            ScenesTab()
                .tabItem { Label("Scenes", systemImage: "theatermasks") }
            TriggersTab()
                .tabItem { Label("Triggers", systemImage: "bolt.fill") }
            GeneralTab()
                .tabItem { Label("General", systemImage: "gear") }
        }
        .frame(width: 550, height: 450)
    }
}
