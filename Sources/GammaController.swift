import Foundation
import CoreGraphics

// Software brightness control using gamma curves
// Works with any external monitor (HDMI, DisplayPort, etc.)
class GammaController {
    private var savedGammaValues: [CGDirectDisplayID: (red: Float, green: Float, blue: Float)] = [:]
    private var warmTintEnabled: [CGDirectDisplayID: Bool] = [:]

    // Warm tint multipliers (flux-like) - reduces blue, slightly reduces green
    private let warmTintRed: Float = 1.0      // Keep red at 100%
    private let warmTintGreen: Float = 0.75   // Reduce green to 75%
    private let warmTintBlue: Float = 0.5     // Reduce blue to 50% (very warm/orange tint)

    // Set software brightness (0.0 - 1.0) using gamma curves
    func setSoftwareBrightness(_ brightness: Float, for displayID: CGDirectDisplayID) {
        let clampedBrightness = max(0.0, min(1.0, brightness))

        // Check if warm tint is enabled for this display
        let tintEnabled = warmTintEnabled[displayID] ?? false

        NSLog("🎨 GAMMA: setSoftwareBrightness(\(clampedBrightness)) for display \(displayID), warmTint=\(tintEnabled)")

        // Calculate RGB max values: brightness * tint multiplier
        let redMax = clampedBrightness * (tintEnabled ? warmTintRed : 1.0)
        let greenMax = clampedBrightness * (tintEnabled ? warmTintGreen : 1.0)
        let blueMax = clampedBrightness * (tintEnabled ? warmTintBlue : 1.0)

        // Apply to RGB channels with optional warm tint
        let result = CGSetDisplayTransferByFormula(
            displayID,
            0.0, redMax, 1.0,      // Red channel
            0.0, greenMax, 1.0,    // Green channel
            0.0, blueMax, 1.0      // Blue channel
        )

        if result == .success {
            NSLog("🎨 GAMMA SUCCESS: brightness=\(clampedBrightness), RGB=(\(redMax), \(greenMax), \(blueMax))")
            savedGammaValues[displayID] = (redMax, greenMax, blueMax)
        } else {
            NSLog("🎨 GAMMA FAILED: Error \(result.rawValue) for display \(displayID)")
        }
    }

    // Toggle warm tint on/off (flux-like)
    func toggleWarmTint(for displayID: CGDirectDisplayID) -> Bool {
        let currentState = warmTintEnabled[displayID] ?? false
        let newState = !currentState
        warmTintEnabled[displayID] = newState

        NSLog("🌅 TINT: Toggled warm tint \(newState ? "ON" : "OFF") for display \(displayID)")

        // Re-apply current brightness with new tint state
        let currentBrightness = getSoftwareBrightness(for: displayID)
        setSoftwareBrightness(currentBrightness, for: displayID)

        return newState
    }

    // Get warm tint state
    func isWarmTintEnabled(for displayID: CGDirectDisplayID) -> Bool {
        return warmTintEnabled[displayID] ?? false
    }

    // Get current software brightness
    func getSoftwareBrightness(for displayID: CGDirectDisplayID) -> Float {
        var redMin: CGGammaValue = 0.0, redMax: CGGammaValue = 0.0, redGamma: CGGammaValue = 0.0
        var greenMin: CGGammaValue = 0.0, greenMax: CGGammaValue = 0.0, greenGamma: CGGammaValue = 0.0
        var blueMin: CGGammaValue = 0.0, blueMax: CGGammaValue = 0.0, blueGamma: CGGammaValue = 0.0

        let result = CGGetDisplayTransferByFormula(
            displayID,
            &redMin, &redMax, &redGamma,
            &greenMin, &greenMax, &greenGamma,
            &blueMin, &blueMax, &blueGamma
        )

        if result == .success {
            // Return RED max value (which represents base brightness)
            // We use red channel because it's always at 100% even with warm tint
            NSLog("🎨 GAMMA: getSoftwareBrightness() = \(redMax) for display \(displayID)")
            return Float(redMax)
        }

        return 1.0  // Default to full brightness
    }

    // Reset gamma to default
    func resetGamma(for displayID: CGDirectDisplayID) {
        CGDisplayRestoreColorSyncSettings()
        savedGammaValues.removeValue(forKey: displayID)
        print("Reset gamma for display \(displayID)")
    }

    func cleanup() {
        // Restore all displays to default gamma
        for (displayID, _) in savedGammaValues {
            resetGamma(for: displayID)
        }
    }
}
