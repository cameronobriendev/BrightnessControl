import Foundation
import CoreGraphics

class ExternalDisplayDriver {
    private var gammaController: GammaController?

    init() {
        gammaController = GammaController()
        NSLog("🖥️ EXTERNAL: Initialized with GAMMA-ONLY control (no DDC)")
    }

    func getBrightness(for displayID: CGDirectDisplayID) -> Float {
        return gammaController?.getSoftwareBrightness(for: displayID) ?? 1.0
    }

    func setBrightness(_ brightness: Float, for displayID: CGDirectDisplayID) {
        let clampedBrightness = max(0.0, min(1.0, brightness))
        NSLog("🖥️ EXTERNAL: Setting GAMMA brightness to \(clampedBrightness) for display \(displayID)")
        gammaController?.setSoftwareBrightness(clampedBrightness, for: displayID)
    }

    func toggleWarmTint(for displayID: CGDirectDisplayID) -> Bool {
        return gammaController?.toggleWarmTint(for: displayID) ?? false
    }
}
