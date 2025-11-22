# BrightnessControl

> macOS menu bar app for advanced display brightness control with automatic warm tint

A native Swift-based macOS menu bar application that provides fine-grained control over display brightness for both internal and external displays. Features intuitive keyboard shortcuts, automatic warm tint (f.lux-style), persistent settings across display reconnections, and intelligent per-display control.

## Why No Demo?

This app controls brightness through **gamma table adjustments**—a software-based method that changes how your display renders colors to simulate brightness changes. While you see the screen get brighter or darker with your eyes, gamma changes don't affect the actual pixel values captured in screenshots or screen recordings. Any demo would look identical before/after, even though the perceived brightness is dramatically different when viewing the actual screen.

## Tech Stack

- **Swift 5.9+**
- **macOS 12.0+**
- **System Frameworks:** AppKit, CoreGraphics, IOKit, CoreDisplay
- **Swift Package Manager** - Built as a native executable

## Features

### Core Functionality

- **Intuitive Keyboard Shortcuts** - System-wide hotkeys for quick brightness adjustment
  - `Cmd+Ctrl+Down` - Decrease brightness
  - `Cmd+Ctrl+Up` - Increase brightness
  - Automatically detects which display to adjust based on cursor position

- **Automatic Warm Tint** - Eye-friendly color temperature adjustment applied to all brightness levels
  - Reduces blue light (50% blue, 75% green, 100% red)
  - Similar to f.lux/Night Shift but integrated with brightness control
  - Baked into brightness adjustments for seamless experience

- **Smart Display Management**
  - Automatically detects internal (MacBook) and external displays
  - Cursor-based display targeting (adjusts the display your mouse is on)
  - **Link Displays mode** - Adjust all monitors simultaneously with one hotkey
  - Separate control strategies optimized for each display type

- **Launch at Login** - Optional auto-start after system sleep/restart (macOS 13+)

- **Persistent Settings with Sleep/Wake Memory**
  - Remembers brightness per display across app restarts
  - Automatically restores brightness when external display reconnects
  - Restores brightness after screen lock/unlock and system sleep/wake
  - No jarring brightness resets—settings persist through all display events

- **Zero Dependencies** - Native Swift, no external frameworks required

## Installation

### Prerequisites
- macOS 12.0 or later
- Xcode or Swift toolchain installed
- **Accessibility Permissions** (required for global keyboard shortcuts)

### Build and Install from Source

```bash
# Clone the repository
git clone https://github.com/cameronobriendev/BrightnessControl.git
cd BrightnessControl

# Build and install (includes proper code signing)
./install.sh
```

The `install.sh` script handles:
- Building the release binary
- Installing to your Applications folder
- Code signing to preserve accessibility permissions

### Grant Accessibility Permissions

After first launch, macOS will prompt you to grant Accessibility permissions:

1. Open **System Settings** > **Privacy & Security** > **Accessibility**
2. Enable permissions for BrightnessControl
3. Restart the app

This is required for global keyboard shortcuts (`Cmd+Ctrl+Up/Down`) to function.

### Usage

Once installed and running:
- The app appears in your menu bar with a sun icon
- Press `Cmd+Ctrl+Down` to decrease brightness on the display under your cursor
- Press `Cmd+Ctrl+Up` to increase brightness on the display under your cursor
- Warm tint is automatically applied at all brightness levels

**Menu Bar Options:**
- **Link Displays** - Toggle to adjust all monitors simultaneously
- **Launch at Login** - Toggle to auto-start after system restart (macOS 13+)

## How It Works

### Brightness Control Methods

BrightnessControl uses different strategies optimized for each display type:

**Internal Display (MacBook Screen)**
- Hardware brightness control via DisplayServices framework
- Gamma adjustment for warm color temperature only
- Provides smooth, native-feeling brightness changes
- Preserves screen contrast and color accuracy

**External Displays**
- Software-based gamma table manipulation
- Combines brightness dimming and warm tint in a single operation
- Works with any external display (no special hardware support required)

### Warm Tint Technology

The warm tint feature reduces blue light emission by adjusting the display's color balance:
- **Red channel**: 100% (unchanged)
- **Green channel**: 75% (slightly reduced)
- **Blue channel**: 50% (heavily reduced)

This creates an orange/warm color temperature similar to f.lux or Night Shift, reducing eye strain during evening use.

### Display Persistence Intelligence

BrightnessControl automatically restores your brightness settings in multiple scenarios:

**Display Reconnection**
When you disconnect and reconnect an external display:
1. Detects the display reconnection event via CoreGraphics callbacks
2. Identifies the display by its unique ID
3. Retrieves the saved brightness setting from local storage
4. Automatically restores the previous brightness level

**Sleep/Wake & Screen Lock**
When your Mac wakes from sleep or you unlock after screen lock:
1. Listens for `screensDidWakeNotification` and `didWakeNotification` events
2. Waits briefly for displays to fully initialize
3. Restores saved brightness for all connected displays

No manual adjustment needed—your displays remember their settings through all power events.

## Architecture

For developers interested in the codebase structure:

- **AppDelegate** - Application lifecycle, menu bar setup
- **StatusBarController** - Menu bar UI and interactions
- **DisplayManager** - Display detection and reconnection handling
- **BrightnessController** - Routes commands to appropriate drivers
- **ExternalDisplayDriver** - Gamma-based control for external displays
- **InternalDisplayDriver** - Hardware brightness + gamma warm tint
- **GammaController** - Gamma table manipulation (warmth + brightness)
- **KeyInterceptor** - Global keyboard shortcuts (Cmd+U/I)
- **OverlayManager** - Visual feedback overlay
- **PersistenceManager** - UserDefaults-based settings storage

See `DEVELOPMENT.md` for detailed technical documentation.

## Troubleshooting

### Keyboard shortcuts not working
- Ensure the app has **Accessibility permissions** in System Settings
- Check that you've restarted the app after granting permissions
- Verify the app is running (icon should appear in menu bar)

### Brightness not persisting after sleep/wake or reconnect
- Ensure you're using the latest version with sleep/wake notifications
- Check Console.app for "Screens WOKE" or "Display was ADDED" log messages
- Try manually adjusting brightness once to re-save settings
- If using older version, rebuild with `./install.sh` to get sleep/wake support

### Display appears washed out
- This may indicate a gamma configuration issue
- Try restarting the app to reset gamma tables
- Check that you're running the latest version with separate brightness/warmth handling

### Want to disable warm tint?
- Current version has warm tint always enabled
- To disable: modify `GammaController.swift` warm tint constants to `1.0` and rebuild
- Future versions may include a toggle option

## Development

Interested in contributing? Check out `DEVELOPMENT.md` for:
- Detailed architecture documentation
- Code signing and build process
- How gamma tables work
- Display reconnection implementation details
- Log file locations and debugging tips

## License

MIT
