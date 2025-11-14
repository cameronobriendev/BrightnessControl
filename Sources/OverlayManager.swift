import AppKit
import CoreGraphics

class OverlayManager {
    private var overlays: [CGDirectDisplayID: NSWindow] = [:]

    init() {
        print("OverlayManager initialized")
    }

    func setOverlayOpacity(_ opacity: Float, for displayID: CGDirectDisplayID) {
        let clampedOpacity = max(0.0, min(1.0, opacity))

        if clampedOpacity > 0.0 {
            // Create or update overlay
            if let overlay = overlays[displayID] {
                overlay.alphaValue = CGFloat(clampedOpacity)
            } else {
                createOverlay(for: displayID, opacity: CGFloat(clampedOpacity))
            }
        } else {
            // Remove overlay
            removeOverlay(for: displayID)
        }
    }

    private func createOverlay(for displayID: CGDirectDisplayID, opacity: CGFloat) {
        let bounds = CGDisplayBounds(displayID)

        // Convert CG coordinates to NSWindow coordinates
        let frame = NSRect(
            x: bounds.origin.x,
            y: bounds.origin.y,
            width: bounds.size.width,
            height: bounds.size.height
        )

        // Create fullscreen window
        let window = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // Configure window for overlay
        window.backgroundColor = .black
        window.alphaValue = opacity
        window.level = .screenSaver  // Stay on top
        window.ignoresMouseEvents = true  // Click-through
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        // Show window
        window.orderFrontRegardless()

        overlays[displayID] = window

        print("Created sub-zero overlay for display \(displayID) with opacity \(opacity)")
    }

    private func removeOverlay(for displayID: CGDirectDisplayID) {
        if let overlay = overlays[displayID] {
            overlay.close()
            overlays.removeValue(forKey: displayID)
            print("Removed sub-zero overlay for display \(displayID)")
        }
    }

    func cleanup() {
        for (_, overlay) in overlays {
            overlay.close()
        }
        overlays.removeAll()
    }
}
