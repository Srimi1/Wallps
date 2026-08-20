import Foundation
import IOKit.ps
import Observation

/// Tracks battery vs AC power and Low Power Mode, notifying on changes.
@MainActor
@Observable
final class PowerMonitor {
    private(set) var onBattery: Bool
    private(set) var lowPowerMode: Bool
    var changed: (() -> Void)?

    private var powerSource: CFRunLoopSource?
    private var lowPowerObserver: NSObjectProtocol?

    init() {
        onBattery = Self.isOnBattery()
        lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    func start() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        // Delivered on the run loop the source is added to (main), so hopping
        // straight back onto the main actor is safe.
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.refresh() }
        }
        if let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            powerSource = source
        }

        lowPowerObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func stop() {
        if let powerSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSource, .defaultMode)
        }
        powerSource = nil
        if let lowPowerObserver {
            NotificationCenter.default.removeObserver(lowPowerObserver)
        }
        lowPowerObserver = nil
    }

    func refresh() {
        let battery = Self.isOnBattery()
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        guard battery != onBattery || lowPower != lowPowerMode else { return }
        onBattery = battery
        lowPowerMode = lowPower
        changed?()
    }

    nonisolated static func isOnBattery() -> Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(snapshot)?.takeRetainedValue() else {
            return false
        }
        return (type as String) == kIOPSBatteryPowerValue
    }
}
