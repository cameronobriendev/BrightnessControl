import AppKit
import CoreGraphics
import Foundation

struct DisplayInfo {
    let id: CGDirectDisplayID
    let name: String
    let frame: CGRect
    let brightness: Float
    let isBuiltIn: Bool
}

class DisplayManager {
    private var displays: [CGDirectDisplayID] = []
    private var brightnessController: BrightnessController?

    init() {
        brightnessController = BrightnessController()
        updateDisplayList()

        // Register for display configuration changes
        setupDisplayReconfigurationCallback()

        // Register for sleep/wake events to restore brightness
        setupSleepWakeNotifications()
    }

    private func setupSleepWakeNotifications() {
        let workspace = NSWorkspace.shared.notificationCenter

        // When screens wake from sleep (including screen lock unlock)
        workspace.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            NSLog("🖥️ Screens WOKE - restoring brightness settings")
            // Multiple attempts - macOS may reset gamma after initial wake
            for delay in [0.5, 1.5, 3.0] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self?.restoreAllBrightness()
                }
            }
        }

        // Also handle system wake (belt and suspenders)
        workspace.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            NSLog("🖥️ System WOKE - restoring brightness settings")
            // Multiple attempts with longer delays for full system wake
            for delay in [1.0, 2.5, 5.0] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self?.restoreAllBrightness()
                }
            }
        }

        NSLog("🖥️ DisplayManager: Registered for sleep/wake notifications")
    }

    private func restoreAllBrightness() {
        for displayID in displays {
            brightnessController?.restoreSavedBrightness(for: displayID)
        }
        NSLog("🖥️ Restored brightness for \(displays.count) display(s)")
    }

    private func setupDisplayReconfigurationCallback() {
        // Create callback closure
        let callback: CGDisplayReconfigurationCallBack = { (display, flags, userInfo) in
            guard let userInfo = userInfo else { return }
            let manager = Unmanaged<DisplayManager>.fromOpaque(userInfo).takeUnretainedValue()

            if flags.contains(.addFlag) {
                NSLog("🖥️ Display \(display) was ADDED")
                manager.updateDisplayList()
            } else if flags.contains(.removeFlag) {
                NSLog("🖥️ Display \(display) was REMOVED")
                manager.updateDisplayList()
            }
        }

        // Register the callback
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        CGDisplayRegisterReconfigurationCallback(callback, selfPointer)

        NSLog("🖥️ DisplayManager: Registered for display changes")
    }

    func updateDisplayList() {
        // Get all active displays
        var displayCount: UInt32 = 0
        var result = CGGetActiveDisplayList(0, nil, &displayCount)

        guard result == .success else {
            print("Failed to get display count")
            return
        }

        var activeDisplays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        result = CGGetActiveDisplayList(displayCount, &activeDisplays, &displayCount)

        guard result == .success else {
            print("Failed to get active displays")
            return
        }

        let newDisplays = Array(activeDisplays.prefix(Int(displayCount)))

        // Restore saved brightness for any new displays
        for displayID in newDisplays where !displays.contains(displayID) {
            brightnessController?.restoreSavedBrightness(for: displayID)
        }

        displays = newDisplays
        print("Found \(displays.count) displays")
    }

    func getDisplayInfo() -> [DisplayInfo] {
        return displays.compactMap { displayID in
            guard let screen = NSScreen.screens.first(where: {
                guard let screenNumber = $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                    return false
                }
                return screenNumber == displayID
            }) else {
                return nil
            }

            let isBuiltIn = CGDisplayIsBuiltin(displayID) != 0
            let name = getDisplayName(for: displayID, isBuiltIn: isBuiltIn)
            let brightness = brightnessController?.getBrightness(for: displayID) ?? 0.0

            return DisplayInfo(
                id: displayID,
                name: name,
                frame: screen.frame,
                brightness: brightness,
                isBuiltIn: isBuiltIn
            )
        }
    }

    func getDisplayUnderMouse() -> CGDirectDisplayID? {
        let mouseLocation = NSEvent.mouseLocation

        // FORCE output to stderr so we can see it
        fputs("🖱️ MOUSE: \(mouseLocation)\n", stderr)
        fputs("🖥️ SCREENS: \(NSScreen.screens.count)\n", stderr)

        // Find display containing this point by checking NSScreen frames
        for (index, screen) in NSScreen.screens.enumerated() {
            let frame = screen.frame
            let contains = frame.contains(mouseLocation)
            fputs("  Screen \(index): \(frame) -> contains: \(contains)\n", stderr)

            if contains {
                // Get the display ID for this screen
                guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                    fputs("  ERROR: No screen number\n", stderr)
                    continue
                }
                let displayType = CGDisplayIsBuiltin(screenNumber) != 0 ? "MacBook" : "External"
                fputs("  ✓ RESULT: Display \(screenNumber) (\(displayType))\n", stderr)
                return screenNumber
            }
        }

        fputs("  ⚠️ FALLBACK: Using first display \(displays.first ?? 0)\n", stderr)
        return displays.first
    }

    private func getDisplayName(for displayID: CGDirectDisplayID, isBuiltIn: Bool) -> String {
        if isBuiltIn {
            return "MacBook"
        }

        // Try to get actual display name from IOKit
        // For now, use a simple fallback
        return "External Display"
    }

    func getBrightnessController() -> BrightnessController? {
        return brightnessController
    }

    func getAllDisplayIDs() -> [CGDirectDisplayID] {
        return displays
    }

    func cleanup() {
        brightnessController?.cleanup()
    }
}
