# Busy Light

A macOS menu bar application that connects to [Home Assistant](https://www.home-assistant.io) to trigger scenes, designed for controlling a "busy light" outside a room to indicate whether you may be disturbed.

## Features

### Menu Bar
- Displays the currently active scene (emoji, name, or both) in the macOS menu bar
- Click to see your list of configured scenes and switch between them
- Option-click to access Settings or quit the app
- Visual feedback when a scene is activated or fails
- Dynamic menu: "Add Scene\u{2026}" shown when no scenes are configured; "No Scene" hidden once scenes are added

### Home Assistant Integration
- Connect to any Home Assistant instance via its REST API
- Default URL pre-populated for quick setup (`http://homeassistant.local:8123`)
- Fetch available scenes and configure which ones appear in the menu
- Customize each scene with an emoji (via the system emoji picker) and display name
- Scenes can be reordered and separated with dividers using +/\u{2212} buttons
- Connection resilience with automatic retry and health monitoring
- Scenes automatically refresh when opening the Scenes settings tab

### Automatic Triggers
- **Webcam detection** -- Automatically trigger a scene when your camera turns on or off (great for video calls)
- **Microphone detection** -- Trigger scenes for audio-only calls
- **Screen lock/unlock** -- Change scenes when you lock your screen or step away
- **Focus mode** -- React to macOS Focus/Do Not Disturb activation (experimental)
- **Revert Scene** -- For any "off" trigger (webcam off, mic off, screen unlocked, focus deactivated), choose "Revert Scene" to automatically return to whatever scene was active before the trigger fired

### Automation
- **Keyboard shortcuts** -- Assign global hotkeys to any scene directly in the Scenes settings tab
- **AppleScript** -- Full scripting support for integration with other apps and workflows
- **Shortcuts.app** -- Native Shortcuts actions for modern automation

### Other
- First-run welcome dialog guides you through initial setup
- Launch at login support
- Secure token storage in macOS Keychain
- No dock icon (runs purely in the menu bar)

## Requirements

- macOS 14.0 (Sonoma) or later
- A Home Assistant instance with a Long-Lived Access Token
- A [Home Assistant scene](https://www.home-assistant.io/integrations/scene/) configured for your busy light

## Installation

### From Source

1. Clone the repository:
   ```bash
   git clone https://github.com/mboszko/busylight.git
   cd busylight
   ```

2. Generate the Xcode project:
   ```bash
   brew install xcodegen  # if not already installed
   xcodegen generate
   ```

3. Build and run:
   ```bash
   xcodebuild -project BusyLight.xcodeproj -scheme BusyLight build
   ```

   Or open `BusyLight.xcodeproj` in Xcode and press Run.

4. The app will appear in your menu bar (no dock icon).

## Setup

1. **First Run**: On first launch, a welcome dialog will guide you to configure your Home Assistant connection. Click "Open Settings" to get started.

2. **Connect to Home Assistant**: In the Home Assistant tab, enter your HA URL and Long-Lived Access Token, then click "Test Connection". Help text below the token field explains how to create a token. The default URL (`http://homeassistant.local:8123`) is pre-filled for convenience.

3. **Add Scenes**: Go to the Scenes tab. Available scenes are automatically fetched from Home Assistant. Use the **+** button to add scenes from the popup menu, or add a divider to organize your list. Use the **\u{2212}** button to remove a selected scene. Customize each scene's emoji (click to open the system emoji picker) and display name. Assign optional keyboard shortcuts directly in each scene row.

4. **Configure Triggers** (optional): Go to the Triggers tab to set up automatic scene activation based on webcam, microphone, screen lock, or Focus mode. For "off" triggers, you can select "Revert Scene" to automatically switch back to whatever scene was active before the trigger fired.

5. **Set Display Preferences**: In the General tab, choose how scenes appear in the menu bar (emoji only, name only, or both) and enable launch at login.

## AppleScript

```applescript
tell application "Busy Light"
    -- Activate a scene
    activate scene "scene.office_busy"

    -- Check current state
    get current scene        -- returns entity ID or ""
    get is busy              -- returns true/false
    get camera active        -- returns true/false
    get microphone active    -- returns true/false

    -- Change display mode
    set display mode to "emoji"  -- "emoji", "name", or "both"

    -- Deactivate
    deactivate scene

    -- List configured scenes
    list scenes
end tell
```

## Shortcuts.app

The following actions are available in Shortcuts.app:
- **Activate Scene** -- Trigger a Home Assistant scene
- **Deactivate Scene** -- Clear the active scene
- **Get Current Scene** -- Check what scene is active
- **List Scenes** -- Get all configured scenes

## How It Works

### Camera/Microphone Detection
The app uses macOS system APIs (CoreMediaIO and CoreAudio) to detect when any application is using your camera or microphone. This works with Zoom, Teams, FaceTime, Discord, Google Meet, and any other application -- no app-specific integration needed.

The detection checks a system property (`DeviceIsRunningSomewhere`) that reports whether any process has the camera/microphone open. This does **not** require camera or microphone permission, as it only reads metadata rather than accessing the actual device stream.

### Revert Scene
When a trigger's "off" action is set to "Revert Scene", the app remembers which scene was active before the trigger fired. When the trigger turns off, it restores that previous scene. If multiple triggers fire in sequence, the app reverts to the scene that was active before the first trigger in the chain.

### Focus Mode Detection
Focus mode detection reads from macOS system files and is considered experimental. It may not work across all macOS versions and degrades gracefully if the required files are unavailable.

## Tech Note

### Resetting the App

The `hasCompletedFirstRun` flag is stored in UserDefaults. To reset it and see the first-run dialog again:

```bash
defaults delete com.mboszko.BusyLight hasCompletedFirstRun
```

To reset *all* app settings (scenes, triggers, display mode, etc.) back to a clean slate:

```bash
defaults delete com.mboszko.BusyLight
```

Note: The Home Assistant token is stored separately in the macOS Keychain, so `defaults delete` won't clear it. To also remove the token, delete the `com.mboszko.BusyLight.haToken` entry from Keychain Access.

## License

All rights reserved.
