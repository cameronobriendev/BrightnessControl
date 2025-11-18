# BrightnessControl

> macOS status bar application for advanced display brightness control

A native Swift-based macOS menu bar app that provides fine-grained control over display brightness for both internal and external displays. Features keyboard shortcuts, visual overlay feedback, and direct DDC/CI hardware control.

## Why No Demo?

This app controls brightness through **gamma table adjustments**—a software-based method that changes how your display renders colors to simulate brightness changes. While you see the screen get brighter or darker with your eyes, gamma changes don't affect the actual pixel values captured in screenshots or screen recordings. Any demo would look identical before/after, even though the perceived brightness is dramatically different when viewing the actual screen.

## Tech Stack

- **Swift 5.9+**
- **macOS 12.0+**
- **System Frameworks:** AppKit, CoreGraphics, IOKit, CoreDisplay
- **Swift Package Manager** - Built as a native executable

## Features

- **Status Bar Menu** - Quick access from macOS menu bar
- **Keyboard Shortcuts** - System-wide hotkeys for brightness control
- **Visual Overlay** - On-screen brightness level indicator
- **External Display Support** - DDC/CI protocol for hardware brightness control (including ARM64 M-series Macs)
- **Internal Display Control** - Native CoreDisplay integration for built-in displays
- **Persistence** - Remembers brightness settings across sessions
- **Zero Dependencies** - Native Swift, no external frameworks

## Setup

### Prerequisites
- macOS 12.0 or later
- Xcode or Swift toolchain installed

### Build from Source

```bash
# Clone the repository
git clone https://github.com/cameronobriendev/BrightnessControl.git
cd BrightnessControl

# Build the executable
swift build -c release

# Run the app
.build/release/BrightnessControl
```

The app will launch and appear in your menu bar. Configure keyboard shortcuts and preferences from the menu.

## Architecture

- **AppDelegate** - Application lifecycle management
- **StatusBarController** - Menu bar UI and menu items
- **DisplayManager** - Manages internal and external display detection
- **BrightnessController** - Core brightness adjustment logic
- **ExternalDisplayDriver** - DDC/CI communication for external displays
- **InternalDisplayDriver** - CoreDisplay integration for built-in displays
- **Arm64DDC** - ARM-specific DDC/CI implementation for M-series Macs
- **GammaController** - Software-based brightness via gamma tables (fallback)
- **KeyInterceptor** - Global keyboard shortcut handling
- **OverlayManager** - Visual feedback overlay rendering
- **PersistenceManager** - Settings and state storage

## License

MIT
