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
- `AppDelegate`: Owns `NSStatusItem`, implements `NSMenuDelegate` for option-click detection
- `MenuBarManager`: Builds `NSMenu` dynamically from scene list, handles scene selection and status feedback
- Normal click: scene list with dividers; Option-click: Preferences + Quit

### Settings (SwiftUI)
4 tabs: Home Assistant | Scenes | Triggers | General
- Settings window opened via hidden window workaround (activation policy toggle)
- Token stored in Keychain via `KeychainHelper`

### Services
- `HomeAssistantService`: Actor with async/await REST API client, exponential backoff retry, connection health checks
- `CameraMonitor`: CoreMediaIO `kCMIODevicePropertyDeviceIsRunningSomewhere` (2s polling)
- `MicrophoneMonitor`: CoreAudio `kAudioDevicePropertyDeviceIsRunningSomewhere` (2s polling)
- `ScreenLockMonitor`: `DistributedNotificationCenter` for lock/unlock/sleep/wake
- `FocusModeMonitor`: Reads `~/Library/DoNotDisturb/DB/Assertions.json` (5s polling, experimental)
- `GlobalHotkeyManager`: `NSEvent.addGlobalMonitorForEvents` for system-wide keyboard shortcuts
- `TriggerManager`: Coordinates all monitors, applies trigger settings, camera > mic priority

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
- `BusyLight/AppDelegate.swift` - Menu bar NSStatusItem + NSMenuDelegate
- `BusyLight/Services/HomeAssistantService.swift` - HA REST API client
- `BusyLight/Services/TriggerManager.swift` - Monitor coordination
- `BusyLight/Models/AppSettings.swift` - All settings persistence

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
