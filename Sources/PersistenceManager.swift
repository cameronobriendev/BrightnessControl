import Foundation
import CoreGraphics

class PersistenceManager {
    private let defaults = UserDefaults.standard
    private let brightnessKeyPrefix = "brightness_"

    func saveBrightness(_ brightness: Float, for displayID: CGDirectDisplayID) {
        let key = brightnessKeyPrefix + String(displayID)
        defaults.set(brightness, forKey: key)
        print("Saved brightness \(brightness) for display \(displayID)")
    }

    func loadBrightness(for displayID: CGDirectDisplayID) -> Float? {
        let key = brightnessKeyPrefix + String(displayID)
        guard defaults.object(forKey: key) != nil else {
            return nil
        }
        let brightness = defaults.float(forKey: key)
        print("Loaded brightness \(brightness) for display \(displayID)")
        return brightness
    }

    func clearBrightness(for displayID: CGDirectDisplayID) {
        let key = brightnessKeyPrefix + String(displayID)
        defaults.removeObject(forKey: key)
    }
}
