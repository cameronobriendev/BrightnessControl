import AppKit
import ServiceManagement

class StatusBarController {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var displayManager: DisplayManager?
    private var keyInterceptor: KeyInterceptor?
    private var launchAtLoginItem: NSMenuItem?
    private var linkDisplaysItem: NSMenuItem?

    // UserDefaults key for link displays setting
    private static let linkDisplaysKey = "linkDisplays"

    // Class method for KeyInterceptor to check link mode
    static func isLinkDisplaysEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: linkDisplaysKey)
    }

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

        // Link Displays option
        linkDisplaysItem = NSMenuItem(title: "Link Displays", action: #selector(toggleLinkDisplays), keyEquivalent: "")
        linkDisplaysItem?.target = self
        linkDisplaysItem?.state = StatusBarController.isLinkDisplaysEnabled() ? .on : .off
        menu.addItem(linkDisplaysItem!)

        // Launch at Login option
        launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem?.target = self
        if #available(macOS 13.0, *) {
            launchAtLoginItem?.state = SMAppService.mainApp.status == .enabled ? .on : .off
        } else {
            launchAtLoginItem?.state = .off
            launchAtLoginItem?.isEnabled = false
            launchAtLoginItem?.title = "Launch at Login (requires macOS 13+)"
        }
        menu.addItem(launchAtLoginItem!)

        // Quit option
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc func toggleLinkDisplays() {
        let newValue = !StatusBarController.isLinkDisplaysEnabled()
        UserDefaults.standard.set(newValue, forKey: StatusBarController.linkDisplaysKey)
        linkDisplaysItem?.state = newValue ? .on : .off
        NSLog("🔗 Link Displays: \(newValue ? "enabled" : "disabled")")
    }

    @objc func toggleLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    launchAtLoginItem?.state = .off
                    NSLog("🚀 Disabled launch at login")
                } else {
                    try SMAppService.mainApp.register()
                    launchAtLoginItem?.state = .on
                    NSLog("🚀 Enabled launch at login")
                }
            } catch {
                NSLog("🚀 Failed to toggle launch at login: \(error)")
            }
        }
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
