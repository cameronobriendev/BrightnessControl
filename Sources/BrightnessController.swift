import Foundation
import CoreGraphics

class BrightnessController {
    private var internalDriver: InternalDisplayDriver?
    private var externalDriver: ExternalDisplayDriver?
    private var overlayManager: OverlayManager?
    private var persistence: PersistenceManager?

    init() {
        internalDriver = InternalDisplayDriver()
        externalDriver = ExternalDisplayDriver()
        overlayManager = OverlayManager()
        persistence = PersistenceManager()
    }

    func getBrightness(for displayID: CGDirectDisplayID) -> Float {
        let isBuiltIn = CGDisplayIsBuiltin(displayID) != 0

        if isBuiltIn {
            return internalDriver?.getBrightness() ?? 0.0
        } else {
            return externalDriver?.getBrightness(for: displayID) ?? 0.0
        }
    }

    func setBrightness(_ brightness: Float, for displayID: CGDirectDisplayID) {
        let isBuiltIn = CGDisplayIsBuiltin(displayID) != 0
        let clampedBrightness = max(0.0, min(1.0, brightness))

        NSLog("💡 CONTROLLER: setBrightness(\(clampedBrightness)) for display \(displayID) - \(isBuiltIn ? "Internal" : "External")")

        if isBuiltIn {
            NSLog("💡 Routing to InternalDisplayDriver")
            internalDriver?.setBrightness(clampedBrightness)
        } else {
            NSLog("💡 Routing to ExternalDisplayDriver")
            externalDriver?.setBrightness(clampedBrightness, for: displayID)
        }

        // Handle sub-zero dimming if brightness < hardware minimum
        if clampedBrightness < 0.01 {
            // Hardware at minimum (1%), use overlay for extra dimming
            overlayManager?.setOverlayOpacity(1.0 - (clampedBrightness * 100), for: displayID)
        } else {
            // No overlay needed
            overlayManager?.setOverlayOpacity(0.0, for: displayID)
        }

        // Save brightness to persistence
        persistence?.saveBrightness(clampedBrightness, for: displayID)
    }

    func restoreSavedBrightness(for displayID: CGDirectDisplayID) {
        if let savedBrightness = persistence?.loadBrightness(for: displayID) {
            setBrightness(savedBrightness, for: displayID)
        }
    }

    func adjustBrightness(delta: Float, for displayID: CGDirectDisplayID) {
        let currentBrightness = getBrightness(for: displayID)
        let newBrightness = currentBrightness + delta
        debugLog("adjustBrightness: current=\(currentBrightness), delta=\(delta), new=\(newBrightness)")
        setBrightness(newBrightness, for: displayID)
    }

    func toggleWarmTint(for displayID: CGDirectDisplayID) {
        let isBuiltIn = CGDisplayIsBuiltin(displayID) != 0

        if isBuiltIn {
            // Use internal driver's gamma controller if available
            // For now, just log - internal display might not support this
            NSLog("💡 CONTROLLER: Warm tint toggle requested for internal display (not yet supported)")
        } else {
            // Toggle warm tint on external display
            if let enabled = externalDriver?.toggleWarmTint(for: displayID) {
                NSLog("💡 CONTROLLER: Warm tint now \(enabled ? "ENABLED" : "DISABLED") for display \(displayID)")
            }
        }
    }

    func cleanup() {
        overlayManager?.cleanup()
    }
}
