import AppKit

class StatusBarController {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var displayManager: DisplayManager?
    private var keyInterceptor: KeyInterceptor?

    init() {
        // Create status bar item with icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // Use SF Symbol for brightness
            if let image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "Brightness Control") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "☀️"
            }
        }

        // Create menu
        menu = NSMenu()
        statusItem?.menu = menu

        // Initialize display manager
        displayManager = DisplayManager()

        // Initialize key interceptor
        if let dm = displayManager, let bc = dm.getBrightnessController() {
            keyInterceptor = KeyInterceptor(displayManager: dm, brightnessController: bc)
        }

        // Build initial menu
        updateMenu()

        // Update menu periodically to show live brightness
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateMenu()
        }
    }

    func updateMenu() {
        guard let menu = menu else { return }

        menu.removeAllItems()

        // Add brightness info for each display
        if let displays = displayManager?.getDisplayInfo() {
            for display in displays {
                let name = display.name
                let brightness = display.brightness
                let isSubZero = brightness < 1.0

                let brightnessPercent = Int(brightness * 100)
                let suffix = isSubZero ? " (sub-zero)" : ""
                let menuItem = NSMenuItem(title: "\(name): \(brightnessPercent)%\(suffix)", action: nil, keyEquivalent: "")
                menuItem.isEnabled = false
                menu.addItem(menuItem)
            }
        }

        // Separator
        menu.addItem(NSMenuItem.separator())

        // Quit option
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc func quit() {
        cleanup()
        NSApplication.shared.terminate(nil)
    }

    func cleanup() {
        keyInterceptor?.cleanup()
        displayManager?.cleanup()
    }
}
