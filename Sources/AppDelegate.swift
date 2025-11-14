import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize the status bar controller
        statusBarController = StatusBarController()

        print("BrightnessControl started successfully")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
        statusBarController?.cleanup()
    }
}
