# Busy Light

A macOS menu bar application that connects to [Home Assistant](https://www.home-assistant.io) to trigger scenes, designed for controlling a "busy light" outside a room to indicate whether you may be disturbed.

## Features

### Menu Bar
- Displays the currently active scene (emoji, name, or both) in the macOS menu bar
- Click to see your list of configured scenes and switch between them
- Option-click to access Preferences or quit the app
- Visual feedback when a scene is activated or fails

### Home Assistant Integration
- Connect to any Home Assistant instance via its REST API
- Fetch available scenes and configure which ones appear in the menu
- Customize each scene with an emoji and display name
- Scenes can be reordered and separated with dividers
- Connection resilience with automatic retry and health monitoring

### Automatic Triggers
- **Webcam detection** -- Automatically trigger a scene when your camera turns on or off (great for video calls)
- **Microphone detection** -- Trigger scenes for audio-only calls
- **Screen lock/unlock** -- Change scenes when you lock your screen or step away
- **Focus mode** -- React to macOS Focus/Do Not Disturb activation (experimental)

### Automation
- **Keyboard shortcuts** -- Assign global hotkeys to any scene for instant activation
- **AppleScript** -- Full scripting support for integration with other apps and workflows
- **Shortcuts.app** -- Native Shortcuts actions for modern automation

### Other
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

1. **Connect to Home Assistant**: Open Preferences (Option-click the menu bar icon), go to the Home Assistant tab, enter your HA URL and Long-Lived Access Token, and click "Test Connection".

2. **Add Scenes**: Go to the Scenes tab, click "Fetch Scenes from HA", then add scenes to your menu. Customize each with an emoji and display name. Add dividers to organize them.

3. **Configure Triggers** (optional): Go to the Triggers tab to set up automatic scene activation based on webcam, microphone, screen lock, or Focus mode.

4. **Set Display Preferences**: In the General tab, choose how scenes appear in the menu bar (emoji, name, or both), set up keyboard shortcuts, and enable launch at login.

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

### Focus Mode Detection
Focus mode detection reads from macOS system files and is considered experimental. It may not work across all macOS versions and degrades gracefully if the required files are unavailable.

## License

All rights reserved.
