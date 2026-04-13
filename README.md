# Busy Light Controller for macOS

A macOS menu bar application that connects to [Home Assistant](https://www.home-assistant.io) to trigger scenes, designed for controlling a "busy light" outside a room to indicate whether you may be disturbed.

![A macOS menu bar item. The menu bar says "🟡 Concentrating". Below that is an open menu with a series of red, amber, green, and off emojis and settings names for a busy light, a dividing line, then on and off for webcam lights. Another dividing line, and then Help, Settings…, and Quit.](./ProductionAssets/web/menu-bar-item-clean.png "Busy Light's menu bar item")

_However,_ you can use it to trigger _any_ scene set up in HA, so the possibilities are quite unlimited!

> [!TIP]
>
> #### Busy Light Hardware
>
> Documented [here](./Hardware/Busy%20Light%20Hardware.md), the one that I built is basically some WS2812 LEDs connected to an ESP32 controller and set up with ESPHome using the [ESP32 RMT LED Strip component](https://esphome.io/components/light/esp32_rmt_led_strip/). This clips over a door, powered by a USB battery pack, in a 3D-printed enclosure.

You can use it for anything you have a **Scene** set up for in Home Assistant: an RGB light bulb, a power switch for some other light, or it doesn't even have to be a light at all.

> [!NOTE]
> 
> I am a human developer, but this project was a trial run for working with Claude Code on a project. I designed it, asked Claude to do have a go at some features, sometimes re-wrote it myself, and sometimes had Claude take a shot at rewriting it until it was right. It's a silly little menu bar item, and I've been using it for over a month with only [one little bug](https://github.com/swizzlevixen/busylight/issues/2), but just wanted to mention it, in case an LLM touching it makes a difference to you.

## Screenshots

<img src="./ProductionAssets/web/settings-scenes.png" title="Screenshot of the Scenes tab in Settings" alt="The Scenes tab in Settings. The screenshot shows a list titled Menu Items, and there are several items in the list, each with an emoji representing the scene, a title, a technical ID, and a keyboard shortcut. The items are: Busy, Concentrating, Free, Off, a Divider, Webcam Lights On, and Webcam Lights Off" width="30%"><img src="./ProductionAssets/web/settings-triggers.png" title="Screenshot of the Triggers tab in Settings" alt="The Triggers Tab in Settings. There are several groupings where the user can turn on or off the trigger, and set a separate scene for to be triggered for when the particular trigger turns on or off. The groupings are Webcam, Microphone, Screen Lock, and Focus Mode. Webcam has the scene Busy set for when the webcam turns on, and Concentrating set when the webcam turns off." width="30%"><img src="./ProductionAssets/web/help-getting-started.png" title="Help that is actually helpful" alt="A display of Help Book in-app help for macOS apps. The title is Getting Started, and it displays some basic information about how to get set up with the Busy Light app." width="30%">

## Features

### Menu Bar

- Displays the most recently triggered scene (emoji, name, or both) in the macOS menu bar
- Click to see your list of configured scenes and switch between them
- **Help,** **Settings…,** and **Quit Busy Light** are always available at the bottom of the menu

### Home Assistant Integration

- Connect to any Home Assistant instance via its REST API
- Automatically fetch available scenes and configure which ones appear in the menu
- Customize each scene with an emoji (via the system emoji picker) and a display name
- Scenes can be reordered and separated with dividers
- Add and remove scenes and dividers using +/- buttons
- HA connection resilience with automatic retry and health monitoring
- Scenes automatically refresh when opening the Scenes settings tab

### Automatic Triggers

- **Webcam detection** -- Automatically trigger a scene when your camera turns on or off (great for video calls)
- **Microphone detection** -- Trigger scenes for audio-only calls
- **Screen lock/unlock** -- Change scenes when you lock your screen or step away
- **Focus mode** -- React to macOS Focus/Do Not Disturb activation (experimental)
### Automation

- **Keyboard shortcuts** -- Assign global hotkeys to any scene directly in the Scenes settings tab
- **AppleScript** -- Full scripting support for integration with other apps and workflows
- **Shortcuts.app** -- Native Shortcuts actions for modern automation

> [!CAUTION]
> AppleScript and Shortcuts support is experimental and a work in progress. Something missing or broken? Please file a bug!

### Other

- First-run welcome dialog guides you through initial setup
- Help in Help Book format
- Launch at login support
- Secure HA token storage in macOS Keychain
- No dock icon (runs purely in the menu bar)
- Undo/Redo support in Scenes settings tab
- Usage information in standard macOS Help menu
- ❤️ Tip/donation button in General settings tab, if you feel so moved

## Requirements

- macOS 14.0 (Sonoma) or later
- A Home Assistant instance with a Long-Lived Access Token
- A [Home Assistant scene](https://www.home-assistant.io/integrations/scene/) configured for your busy light

## Installation

### Download

Download [the latest release of the signed app](https://github.com/swizzlevixen/busylight/releases/latest) from the releases tab in this repo, ready to use.

### Build from Source

Follow the build instructions in [CONTRIBUTING](./CONTRIBUTING.md).

## Setup

1. **First Run**: On first launch, a welcome dialog will guide you to configure your Home Assistant connection. Click "Open Settings" to get started.

2. **Connect to Home Assistant**: In the Home Assistant tab, enter your HA URL and Long-Lived Access Token, then click "Test Connection". Help text below the token field explains how to create a token. A common default URL is pre-filled for convenience.

> [!NOTE]
> Busy Light will ask you to unlock you Keychain to save and retrieve the API key for Home Assistant.
> 
> It will also ask you to allow it to find devices on local networks, which is needed to contact Home Assistant.

3. **Add Scenes**: Go to the Scenes tab. Available scenes are automatically fetched from Home Assistant. Use the **➕** button to add scenes from the popup menu, or add a divider to organize your list. Use the **➖** button to remove a selected scene or divider. Customize each scene's emoji (click to open the system emoji picker) and display name. Assign optional keyboard shortcuts directly in each scene row.

4. **Configure Triggers** (optional): Go to the Triggers tab to set up automatic scene activation based on webcam, microphone, screen lock, or Focus mode.

5. **Set Display Preferences**: In the General tab, choose how scenes appear in the menu bar (emoji only, name only, or both) and enable launch at login.

## AppleScript

```applescript
tell application "Busy Light"
    -- Activate a scene
    activate scene "scene.office_busy"

    -- Check current state
    get current scene        -- returns entity ID or ""

    -- Deactivate (set current scene to empty string)
    set current scene to ""

    -- Change display mode
    set display mode to "emoji"  -- "emoji", "name", or "both"

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

## Tech Note

### Resetting the App

The `hasCompletedFirstRun` flag is stored in UserDefaults. To reset it and see the first-run dialog again:

```bash
defaults delete com.mboszko.BusyLight hasCompletedFirstRun
```

To reset _all_ app settings (scenes, triggers, display mode, etc.) back to a clean slate:

```bash
defaults delete com.mboszko.BusyLight
```

Note: The Home Assistant token is stored separately in the macOS Keychain, so `defaults delete` won't clear it. To also remove the token, delete the `com.mboszko.BusyLight.haToken` entry from Keychain Access.
