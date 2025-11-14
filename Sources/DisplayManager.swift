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

    func cleanup() {
        brightnessController?.cleanup()
    }
}
