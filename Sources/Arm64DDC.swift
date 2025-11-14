import Foundation
import CoreGraphics
import IOKit

// IOAVService private API declarations
typealias IOAVServiceRef = AnyObject

@_silgen_name("IOAVServiceCreate")
func IOAVServiceCreate(_ allocator: CFAllocator?) -> IOAVServiceRef?

@_silgen_name("IOAVServiceCreateWithService")
func IOAVServiceCreateWithService(_ allocator: CFAllocator?, _ service: io_service_t) -> IOAVServiceRef?

@_silgen_name("IOAVServiceCopyEDID")
func IOAVServiceCopyEDID(_ service: IOAVServiceRef) -> Unmanaged<CFData>?

@_silgen_name("IOAVServiceReadI2C")
func IOAVServiceReadI2C(
    _ service: IOAVServiceRef,
    _ chipAddress: UInt32,
    _ offset: UInt32,
    _ data: UnsafeMutablePointer<UInt8>,
    _ length: UInt32
) -> kern_return_t

@_silgen_name("IOAVServiceWriteI2C")
func IOAVServiceWriteI2C(
    _ service: IOAVServiceRef,
    _ chipAddress: UInt32,
    _ dataAddress: UInt32,
    _ data: UnsafePointer<UInt8>,
    _ length: UInt32
) -> kern_return_t

class Arm64DDC {
    // DDC/CI constants
    private let DDC_ADDRESS: UInt32 = 0x37
    private let DDC_DATA_ADDRESS: UInt32 = 0x51

    // DDC VCP codes
    private let VCP_BRIGHTNESS: UInt8 = 0x10

    private var serviceCache: [CGDirectDisplayID: IOAVServiceRef] = [:]

    init() {
        print("Arm64DDC initialized")
    }

    // Get EDID from a CGDirectDisplay
    private func getDisplayEDID(for displayID: CGDirectDisplayID) -> Data? {
        // Get the IOService for this display
        let matching = IOServiceMatching("IODisplayConnect")
        var iterator: io_iterator_t = 0

        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }

        defer { IOObjectRelease(iterator) }

        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }

            // Get display attributes
            guard let info = IODisplayCreateInfoDictionary(service, IOOptionBits(kIODisplayOnlyPreferredName)).takeRetainedValue() as? [String: Any] else {
                continue
            }

            // Check if this is our display (vendor/product match)
            if let edidData = info[kIODisplayEDIDKey] as? Data {
                // For now, just return the first EDID we find for external displays
                // A better approach would match vendor/product IDs
                return edidData
            }
        }

        return nil
    }

    // Get IOAVService for a display
    private func getAVService(for displayID: CGDirectDisplayID) -> IOAVServiceRef? {
        // Check cache first
        if let cached = serviceCache[displayID] {
            return cached
        }

        // Get EDID for the target display
        guard let displayEDID = getDisplayEDID(for: displayID) else {
            print("Could not get EDID for display \(displayID)")
            // If we can't get EDID, try to use any available IOAVService (fallback)
            return getFallbackAVService(for: displayID)
        }

        print("Looking for IOAVService matching display \(displayID) EDID")

        // Find the IOAVService for this display
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOAVService")

        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else {
            print("Failed to get IOAVService iterator")
            return nil
        }

        defer { IOObjectRelease(iterator) }

        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }

            // Create AVService
            guard let avService = IOAVServiceCreateWithService(kCFAllocatorDefault, service) else {
                continue
            }

            // Get EDID from this IOAVService
            guard let avEDID = IOAVServiceCopyEDID(avService)?.takeRetainedValue() as Data? else {
                print("No EDID from IOAVService")
                continue
            }

            // Compare EDIDs (first 128 bytes contain vendor/product info)
            let compareLength = min(128, min(displayEDID.count, avEDID.count))
            if displayEDID.prefix(compareLength) == avEDID.prefix(compareLength) {
                print("✓ Found matching IOAVService for display \(displayID)")
                serviceCache[displayID] = avService
                return avService
            }
        }

        print("No matching IOAVService found for display \(displayID)")
        return nil
    }

    // Fallback: Return first available IOAVService (old behavior)
    private func getFallbackAVService(for displayID: CGDirectDisplayID) -> IOAVServiceRef? {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOAVService")

        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }

        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        if service != 0 {
            defer { IOObjectRelease(service) }
            if let avService = IOAVServiceCreateWithService(kCFAllocatorDefault, service) {
                print("Using fallback IOAVService for display \(displayID)")
                serviceCache[displayID] = avService
                return avService
            }
        }

        return nil
    }

    // Read brightness via DDC
    func readBrightness(for displayID: CGDirectDisplayID) -> UInt8? {
        guard let service = getAVService(for: displayID) else {
            return nil
        }

        // DDC read request format
        var request: [UInt8] = [
            0x82,  // Source address | 0x80 (host)
            0x01,  // Length
            VCP_BRIGHTNESS  // VCP code
        ]

        // Calculate checksum
        let checksumBase: UInt8 = 0x6E ^ UInt8(DDC_DATA_ADDRESS & 0xFF)  // 0x6E = 0x50 | 0x02 (destination)
        var checksum = checksumBase
        for byte in request {
            checksum ^= byte
        }
        request.append(checksum)

        // Write request
        let writeResult = IOAVServiceWriteI2C(
            service,
            DDC_ADDRESS,
            DDC_DATA_ADDRESS,
            request,
            UInt32(request.count)
        )

        guard writeResult == KERN_SUCCESS else {
            print("DDC write failed: \(writeResult)")
            return nil
        }

        // Wait for response
        usleep(40000) // 40ms delay

        // Read response (11 bytes for VCP reply)
        var reply = [UInt8](repeating: 0, count: 12)
        let readResult = IOAVServiceReadI2C(
            service,
            DDC_ADDRESS,
            DDC_DATA_ADDRESS,
            &reply,
            UInt32(reply.count)
        )

        guard readResult == KERN_SUCCESS else {
            print("DDC read failed: \(readResult)")
            return nil
        }

        // Parse response
        // Format: [length, type, result, vcp_code, max_hi, max_lo, cur_hi, cur_lo, checksum]
        if reply[1] == 0x02 && reply[3] == VCP_BRIGHTNESS {
            let currentValue = UInt8(reply[9])  // Current value low byte
            print("Read brightness: \(currentValue)")
            return currentValue
        }

        print("Invalid DDC response")
        return nil
    }

    // Write brightness via DDC
    func writeBrightness(_ brightness: UInt8, for displayID: CGDirectDisplayID) -> Bool {
        guard let service = getAVService(for: displayID) else {
            return false
        }

        // DDC write request format
        var request: [UInt8] = [
            0x84,  // Source address | 0x80 (host)
            0x03,  // Length
            VCP_BRIGHTNESS,  // VCP code
            0x00,  // New value high byte
            brightness  // New value low byte
        ]

        // Calculate checksum
        let checksumBase: UInt8 = 0x6E ^ UInt8(DDC_DATA_ADDRESS & 0xFF)
        var checksum = checksumBase
        for byte in request {
            checksum ^= byte
        }
        request.append(checksum)

        // Write request
        let result = IOAVServiceWriteI2C(
            service,
            DDC_ADDRESS,
            DDC_DATA_ADDRESS,
            request,
            UInt32(request.count)
        )

        if result == KERN_SUCCESS {
            print("DDC write successful: brightness set to \(brightness)")
            return true
        } else {
            print("DDC write failed: \(result)")
            return false
        }
    }
}
