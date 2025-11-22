import AppKit
import CoreGraphics
import Foundation
import AudioToolbox

// Keyboard shortcut key codes
private let kVK_UpArrow: Int64 = 126    // Up arrow (Cmd+Ctrl+Up for brightness up)
private let kVK_DownArrow: Int64 = 125  // Down arrow (Cmd+Ctrl+Down for brightness down)
private let kVK_F6_codes: [Int64] = [97, 105]  // F6: Standard Mac (97) or USB keyboard (might vary)

class KeyInterceptor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var displayManager: DisplayManager?
    private var brightnessController: BrightnessController?

    // Brightness adjustment step (5% per key press)
    private let brightnessStep: Float = 0.05

    init(displayManager: DisplayManager, brightnessController: BrightnessController) {
        self.displayManager = displayManager
        self.brightnessController = brightnessController

        NSLog("🎹 KeyInterceptor: Starting initialization...")
        setupEventTap()
    }

    private func setupEventTap() {
        NSLog("🎹 KeyInterceptor: Checking Accessibility permissions...")

        // Check for Accessibility permissions
        let trusted = AXIsProcessTrusted()
        NSLog("🎹 KeyInterceptor: AXIsProcessTrusted() returned: \(trusted)")

        if !trusted {
            NSLog("⚠️ Accessibility permissions NOT granted!")
            print("⚠️ Accessibility permissions not granted!")
            print("Please grant Accessibility access in System Preferences > Privacy & Security > Accessibility")

            // Show alert to user
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = "BrightnessControl needs Accessibility access to intercept brightness keys.\n\nPlease grant permission in:\nSystem Preferences > Privacy & Security > Accessibility"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open System Preferences")
                alert.addButton(withTitle: "Cancel")

                if alert.runModal() == .alertFirstButtonReturn {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }

            return
        }

        // Create event tap
        NSLog("🎹 KeyInterceptor: Creating event tap...")
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let interceptor = Unmanaged<KeyInterceptor>.fromOpaque(refcon).takeUnretainedValue()
                // Return nil to consume event, or pass through
                if let result = interceptor.handleEvent(proxy: proxy, type: type, event: event) {
                    return result
                }
                return nil  // Consume the event
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            NSLog("❌ KeyInterceptor: FAILED to create event tap!")
            print("Failed to create event tap")
            return
        }

        NSLog("🎹 KeyInterceptor: Event tap created successfully")
        eventTap = tap

        // Add to run loop
        NSLog("🎹 KeyInterceptor: Adding to run loop...")
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)

        // Enable tap
        CGEvent.tapEnable(tap: tap, enable: true)

        NSLog("✅ KeyInterceptor: Initialized successfully - ready to capture Cmd+Ctrl+Up/Down/F6")
        print("Key interceptor initialized successfully - Cmd+Ctrl+Down (down), Cmd+Ctrl+Up (up), F6 (warm tint)")
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Only process key down events
        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        // Get the key code and modifier flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        NSLog("🔑 KEY EVENT: keyCode=\(keyCode), flags=\(flags.rawValue)")

        // Check for Command+Control modifiers (no other modifiers)
        let cmdCtrlPressed = flags.contains(.maskCommand) && flags.contains(.maskControl)

        // Check for Cmd+Ctrl+Down (brightness down) or Cmd+Ctrl+Up (brightness up)
        if cmdCtrlPressed && keyCode == kVK_DownArrow {
            NSLog("🔑 Detected: Cmd+Ctrl+Down (Brightness Down)")
            handleBrightnessDown()
            return nil  // Consume the event
        } else if cmdCtrlPressed && keyCode == kVK_UpArrow {
            NSLog("🔑 Detected: Cmd+Ctrl+Up (Brightness Up)")
            handleBrightnessUp()
            return nil  // Consume the event
        } else if kVK_F6_codes.contains(keyCode) {
            handleWarmTintToggle()
            return nil  // Consume the event
        }

        return Unmanaged.passUnretained(event)
    }

    private func handleBrightnessUp() {
        // Single beep for feedback
        AudioServicesPlaySystemSound(1000)

        // Check if link mode is enabled
        if StatusBarController.isLinkDisplaysEnabled() {
            guard let allDisplays = displayManager?.getAllDisplayIDs(), !allDisplays.isEmpty else {
                NSLog("⚠️ KEY: No displays found")
                return
            }
            NSLog("⌨️ KEY: Brightness UP (linked) for \(allDisplays.count) displays")
            for displayID in allDisplays {
                brightnessController?.adjustBrightness(delta: brightnessStep, for: displayID)
            }
        } else {
            // Get display under mouse cursor
            guard let displayID = displayManager?.getDisplayUnderMouse() else {
                NSLog("⚠️ KEY: No display found under mouse")
                return
            }
            NSLog("⌨️ KEY: Brightness UP for display \(displayID)")
            brightnessController?.adjustBrightness(delta: brightnessStep, for: displayID)
        }
    }

    private func handleBrightnessDown() {
        // Single beep for feedback
        AudioServicesPlaySystemSound(1000)

        // Check if link mode is enabled
        if StatusBarController.isLinkDisplaysEnabled() {
            guard let allDisplays = displayManager?.getAllDisplayIDs(), !allDisplays.isEmpty else {
                NSLog("⚠️ KEY: No displays found")
                return
            }
            NSLog("⌨️ KEY: Brightness DOWN (linked) for \(allDisplays.count) displays")
            for displayID in allDisplays {
                brightnessController?.adjustBrightness(delta: -brightnessStep, for: displayID)
            }
        } else {
            // Get display under mouse cursor
            guard let displayID = displayManager?.getDisplayUnderMouse() else {
                NSLog("⚠️ KEY: No display found under mouse")
                return
            }
            NSLog("⌨️ KEY: Brightness DOWN for display \(displayID)")
            brightnessController?.adjustBrightness(delta: -brightnessStep, for: displayID)
        }
    }

    private func handleWarmTintToggle() {
        // Get display under mouse cursor
        guard let displayID = displayManager?.getDisplayUnderMouse() else {
            NSLog("⚠️ KEY: No display found under mouse")
            return
        }

        NSLog("⌨️ KEY: F6 (Warm Tint Toggle) pressed for display \(displayID)")

        // Double beep for feedback (different from brightness)
        AudioServicesPlaySystemSound(1000)
        usleep(80000)
        AudioServicesPlaySystemSound(1000)

        brightnessController?.toggleWarmTint(for: displayID)
    }

    func cleanup() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
        }
    }
}
