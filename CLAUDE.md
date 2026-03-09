# Busy Light

## Project Overview

macOS menu bar application that connects to Home Assistant to trigger scenes, primarily for controlling a "busy light" outside a room to show whether the user may be disturbed.

## Tech Stack

- **Language**: Swift 6
- **UI**: Hybrid AppKit (menu bar via NSStatusItem/NSMenu) + SwiftUI (Settings window)
- **Frameworks**: CoreMediaIO (camera detection), CoreAudio (mic detection), ServiceManagement (launch at login), AppIntents (Shortcuts.app), Security (Keychain)
- **Minimum Deployment**: macOS 14.0
- **Distribution**: Non-sandboxed (outside App Store)
- **Project Generation**: XcodeGen (`project.yml` → `BusyLight.xcodeproj`)

## Build Commands

```bash
# Generate Xcode project from project.yml
xcodegen generate

# Build
xcodebuild -project BusyLight.xcodeproj -scheme BusyLight build

# Run tests
xcodebuild test -project BusyLight.xcodeproj -scheme BusyLight -destination 'platform=macOS'
```

## Architecture

### Menu Bar (AppKit)
- `AppDelegate`: Owns `NSStatusItem`, implements `NSMenuDelegate` for option-click detection, first-run dialog
- `MenuBarManager`: Builds `NSMenu` dynamically from scene list, handles scene selection and status feedback
- Normal click: scene list with dividers (or "Add Scene…" if empty); Option-click: Settings + Quit
- "No Scene" display respects Display Mode setting (emoji only / name only / both)
- "No Scene" removed from menu when user has scenes; "Add Scene…" shown when empty

### Settings (SwiftUI)
4 tabs: Home Assistant | Scenes | Triggers | General
- Settings window opened via hidden window workaround (activation policy toggle), title always "Settings"
- Tab selection support: can open to a specific tab via notification userInfo `["tab": "scenes"]`
- Token stored in Keychain via `KeychainHelper`
- Scenes tab: emoji picker (system character palette), +/- buttons, keyboard shortcuts per scene, auto-fetch on appear
- Triggers tab: "Revert Scene" option for off-state triggers (reverts to pre-trigger scene)

### Services
- `HomeAssistantService`: Actor with async/await REST API client, exponential backoff retry, connection health checks
- `CameraMonitor`: CoreMediaIO `kCMIODevicePropertyDeviceIsRunningSomewhere` (2s polling)
- `MicrophoneMonitor`: CoreAudio `kAudioDevicePropertyDeviceIsRunningSomewhere` (2s polling)
- `ScreenLockMonitor`: `DistributedNotificationCenter` for lock/unlock/sleep/wake
- `FocusModeMonitor`: Reads `~/Library/DoNotDisturb/DB/Assertions.json` (5s polling, experimental)
- `GlobalHotkeyManager`: `NSEvent.addGlobalMonitorForEvents` for system-wide keyboard shortcuts
- `TriggerManager`: Coordinates all monitors, applies trigger settings, camera > mic priority, "Revert Scene" support via `previousSceneId` tracking

### Automation
- AppleScript via SDEF (`BusyLight.sdef`) + `ScriptableApp` (NSApplication subclass) + `NSScriptCommand` subclasses
- Shortcuts.app via AppIntents framework (`ActivateSceneIntent`, `DeactivateSceneIntent`, etc.)

### Data
- `SceneItem`: Codable model (id, entityId, emoji, displayName)
- `MenuListItem`: Enum `.scene(SceneItem)` | `.divider(UUID)` for heterogeneous list
- `AppSettings`: @Observable, UserDefaults for prefs, Keychain for token, JSON-in-UserDefaults for scene list

## Key File Locations

- `project.yml` - XcodeGen project spec
- `BusyLight/Info.plist` - LSUIElement=YES, AppleScript config
- `BusyLight/BusyLight.sdef` - AppleScript dictionary
- `BusyLight/AppDelegate.swift` - Menu bar NSStatusItem + NSMenuDelegate + first-run dialog
- `BusyLight/Services/HomeAssistantService.swift` - HA REST API client
- `BusyLight/Services/TriggerManager.swift` - Monitor coordination + Revert Scene logic
- `BusyLight/Models/AppSettings.swift` - All settings persistence + `revertSceneId` constant
- `BusyLight/Views/Utility/EmojiPickerButton.swift` - System emoji picker component (NSViewRepresentable)
- `BusyLight/Views/Utility/ShortcutRecorderView.swift` - Keyboard shortcut recorder component

## Home Assistant API

- Auth: `Authorization: Bearer <long-lived-access-token>`
- Health: `GET /api/` → `{"message": "API running."}`
- Scenes: `GET /api/states` → filter `entity_id.hasPrefix("scene.")`
- Activate: `POST /api/services/scene/turn_on` body `{"entity_id": "scene.xxx"}`

## Conventions

- All UI code is `@MainActor`
- `HomeAssistantService` is an `actor` for thread safety
- Notification-based communication between monitors and TriggerManager
- `NSEvent.modifierFlags.contains(.option)` in `menuNeedsUpdate` for alternate menu
