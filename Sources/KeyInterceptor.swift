import AppKit
import CoreGraphics
import Foundation
import AudioToolbox

// F3/F4/F6 key codes (handle both Mac keyboard and USB keyboard variants)
private let kVK_F3_codes: [Int64] = [99, 160]  // F3: Standard Mac (99) or USB keyboard (160)
private let kVK_F4_codes: [Int64] = [118, 129] // F4: Standard Mac (118) or USB keyboard (129)
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
                return interceptor.handleEvent(proxy: proxy, type: type, event: event)
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

        NSLog("✅ KeyInterceptor: Initialized successfully - ready to capture F3/F4/F6")
        print("Key interceptor initialized successfully")
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent> {
        // Only process key down events
        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        // Get the key code
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        NSLog("🔑 KEY EVENT: keyCode=\(keyCode)")

        // Check if it's F3, F4, or F6 (handle multiple possible keycodes)
        if kVK_F3_codes.contains(keyCode) {
            handleBrightnessDown()
            return Unmanaged.passRetained(CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)!)
        } else if kVK_F4_codes.contains(keyCode) {
            handleBrightnessUp()
            return Unmanaged.passRetained(CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)!)
        } else if kVK_F6_codes.contains(keyCode) {
            handleWarmTintToggle()
            return Unmanaged.passRetained(CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)!)
        }

        return Unmanaged.passUnretained(event)
    }

    private func handleBrightnessUp() {
        // Get display under mouse cursor
        guard let displayID = displayManager?.getDisplayUnderMouse() else {
            NSLog("⚠️ KEY: No display found under mouse")
            return
        }

        NSLog("⌨️ KEY: F4 (Brightness UP) pressed for display \(displayID)")

        // Single beep for feedback
        AudioServicesPlaySystemSound(1000)

        brightnessController?.adjustBrightness(delta: brightnessStep, for: displayID)
    }

    private func handleBrightnessDown() {
        // Get display under mouse cursor
        guard let displayID = displayManager?.getDisplayUnderMouse() else {
            NSLog("⚠️ KEY: No display found under mouse")
            return
        }

        NSLog("⌨️ KEY: F3 (Brightness DOWN) pressed for display \(displayID)")

        // Single beep for feedback
        AudioServicesPlaySystemSound(1000)

        brightnessController?.adjustBrightness(delta: -brightnessStep, for: displayID)
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
