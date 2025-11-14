import Foundation
import CoreGraphics

// Function pointer types for DisplayServices
typealias DisplayServicesGetBrightnessFunc = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
typealias DisplayServicesSetBrightnessFunc = @convention(c) (CGDirectDisplayID, Float) -> Int32

class InternalDisplayDriver {
    private var getBrightnessFunc: DisplayServicesGetBrightnessFunc?
    private var setBrightnessFunc: DisplayServicesSetBrightnessFunc?
    private var builtInDisplayID: CGDirectDisplayID?

    init() {
        // Dynamically load DisplayServices functions
        let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
        if let handle = handle {
            if let getPtr = dlsym(handle, "DisplayServicesGetBrightness") {
                getBrightnessFunc = unsafeBitCast(getPtr, to: DisplayServicesGetBrightnessFunc.self)
            }
            if let setPtr = dlsym(handle, "DisplayServicesSetBrightness") {
                setBrightnessFunc = unsafeBitCast(setPtr, to: DisplayServicesSetBrightnessFunc.self)
            }
        } else {
            print("Failed to load DisplayServices framework")
        }

        // Find built-in display
        var displayCount: UInt32 = 0
        var result = CGGetActiveDisplayList(0, nil, &displayCount)

        guard result == .success else { return }

        var activeDisplays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        result = CGGetActiveDisplayList(displayCount, &activeDisplays, &displayCount)

        guard result == .success else { return }

        // Find the built-in display
        for displayID in activeDisplays.prefix(Int(displayCount)) {
            if CGDisplayIsBuiltin(displayID) != 0 {
                builtInDisplayID = displayID
                print("Found built-in display: \(displayID)")
                break
            }
        }
    }

    func getBrightness() -> Float {
        guard let displayID = builtInDisplayID,
              let getFunc = getBrightnessFunc else {
            print("No built-in display found or DisplayServices not loaded")
            return 0.0
        }

        var brightness: Float = 0.0
        let result = getFunc(displayID, &brightness)

        if result != 0 {
            print("Failed to get brightness, error: \(result)")
            return 0.0
        }

        return brightness
    }

    func setBrightness(_ brightness: Float) {
        guard let displayID = builtInDisplayID,
              let setFunc = setBrightnessFunc else {
            print("No built-in display found or DisplayServices not loaded")
            return
        }

        let clampedBrightness = max(0.0, min(1.0, brightness))
        let result = setFunc(displayID, clampedBrightness)

        if result != 0 {
            print("Failed to set brightness to \(clampedBrightness), error: \(result)")
        } else {
            print("Set built-in display brightness to \(clampedBrightness)")
        }
    }
}
