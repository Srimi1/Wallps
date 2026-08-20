import AppKit
import Foundation
import Observation

/// Tracks the states in which nobody can see the desktop: screen locked,
/// screensaver running, displays asleep, or the machine going to sleep.
///
/// Lock and screensaver state are only published as cross-process distributed
/// notifications, and AppKit suspends distributed delivery for inactive apps —
/// which this app always is when the screen locks — so they must be registered
/// with `.deliverImmediately`.
@MainActor
@Observable
final class SystemStateMonitor: NSObject {
    private(set) var screenLocked = false
    private(set) var screensaverActive = false
    private(set) var displaysAsleep = false

    @ObservationIgnored var changed: (() -> Void)?

    /// True whenever the desktop cannot possibly be seen.
    var desktopHidden: Bool {
        screenLocked || screensaverActive || displaysAsleep
    }

    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    func start() {
        let workspace = NSWorkspace.shared.notificationCenter
        let workspaceEvents: [(NSNotification.Name, ReferenceWritableKeyPath<SystemStateMonitor, Bool>, Bool?)] = [
            (NSWorkspace.screensDidSleepNotification, \.displaysAsleep, true),
            (NSWorkspace.screensDidWakeNotification, \.displaysAsleep, false),
            (NSWorkspace.willSleepNotification, \.displaysAsleep, true),
            // On wake, ask the window server rather than trusting the ordering
            // of wake notifications.
            (NSWorkspace.didWakeNotification, \.displaysAsleep, nil),
            // Fast user switching posts neither lock nor sleep notifications.
            (NSWorkspace.sessionDidResignActiveNotification, \.screenLocked, true),
            (NSWorkspace.sessionDidBecomeActiveNotification, \.screenLocked, false),
        ]
        observers = workspaceEvents.map { name, keyPath, value in
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if let value {
                        self.set(keyPath, value)
                    } else {
                        self.refreshDisplaySleep()
                    }
                }
            }
        }

        // Selector-based registration is the form that accepts a suspension
        // behavior; the block-based one does not.
        let distributed = DistributedNotificationCenter.default()
        let distributedEvents: [(String, Selector)] = [
            ("com.apple.screenIsLocked", #selector(screenDidLock)),
            ("com.apple.screenIsUnlocked", #selector(screenDidUnlock)),
            ("com.apple.screensaver.didstart", #selector(screensaverDidStart)),
            ("com.apple.screensaver.didstop", #selector(screensaverDidStop)),
        ]
        for (name, selector) in distributedEvents {
            distributed.addObserver(
                self,
                selector: selector,
                name: Notification.Name(name),
                object: nil,
                suspensionBehavior: .deliverImmediately
            )
        }
    }

    func stop() {
        let workspace = NSWorkspace.shared.notificationCenter
        observers.forEach { workspace.removeObserver($0) }
        observers = []
        DistributedNotificationCenter.default().removeObserver(self)
    }

    /// Notification-independent backstop for a missed wake notification.
    func refreshDisplaySleep() {
        set(\.displaysAsleep, CGDisplayIsAsleep(CGMainDisplayID()) != 0)
    }

    @objc private func screenDidLock() { set(\.screenLocked, true) }
    @objc private func screenDidUnlock() { set(\.screenLocked, false) }
    @objc private func screensaverDidStart() { set(\.screensaverActive, true) }
    @objc private func screensaverDidStop() { set(\.screensaverActive, false) }

    private func set(_ keyPath: ReferenceWritableKeyPath<SystemStateMonitor, Bool>, _ value: Bool) {
        guard self[keyPath: keyPath] != value else { return }
        self[keyPath: keyPath] = value
        changed?()
    }
}
