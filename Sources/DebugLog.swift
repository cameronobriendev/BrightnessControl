import Foundation

// Shared debug logging function
func debugLog(_ message: String) {
    let logFile = "/tmp/brightness_mouse_debug.log"
    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    let logMessage = "[\(timestamp)] \(message)\n"

    if let data = logMessage.data(using: .utf8) {
        if let fileHandle = FileHandle(forWritingAtPath: logFile) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            fileHandle.closeFile()
        } else {
            try? logMessage.write(toFile: logFile, atomically: false, encoding: .utf8)
        }
    }
}
