import AppKit

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    /// A key that survives reboots and display reconnects (the CGDisplay UUID),
    /// falling back to the localized name for virtual/odd displays.
    var wallpsDisplayKey: String {
        guard let id = displayID,
              let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else {
            return localizedName
        }
        return CFUUIDCreateString(nil, uuid) as String
    }
}
