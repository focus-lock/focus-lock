//
//  DeviceActivityMonitorExtension.swift
//  FocusLockDeviceActivityMonitor
//

// DeviceActivity gives us DeviceActivityMonitor and DeviceActivityName.
// iOS calls this extension when a registered schedule starts or ends.
import DeviceActivity

// ManagedSettings gives us ManagedSettingsStore.
// That store is how we apply or remove shields.
import ManagedSettings

// This class runs inside the DeviceActivity monitor extension target.
//
// The main app does not directly call these methods.
// iOS calls them when a DeviceActivity schedule boundary happens.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    // The ManagedSettingsStore is the object that actually applies restrictions.
    //
    // Setting store.shield.applications blocks apps.
    // Setting store.shield.applications = nil removes app shields from this store.
    private let store = ManagedSettingsStore()

    // iOS calls this when one of our monitored rule intervals starts.
    //
    // Example:
    // Rule is 9:00 AM - 5:00 PM.
    // At 9:00 AM, iOS calls intervalDidStart.
    override func intervalDidStart(for activity: DeviceActivityName) {
        FocusLockDiagnostics.record("DeviceActivityMonitor intervalDidStart fired for \(activity.rawValue).")

        // Let Apple's base class do any default work first.
        super.intervalDidStart(for: activity)

        // Recompute which apps should be blocked right now.
        refreshShields()
    }

    // iOS calls this when one of our monitored rule intervals ends.
    //
    // Example:
    // Rule is 9:00 AM - 5:00 PM.
    // At 5:00 PM, iOS calls intervalDidEnd.
    override func intervalDidEnd(for activity: DeviceActivityName) {
        FocusLockDiagnostics.record("DeviceActivityMonitor intervalDidEnd fired for \(activity.rawValue).")

        super.intervalDidEnd(for: activity)

        // Recompute instead of blindly clearing everything.
        //
        // This matters if two rules overlap:
        // Rule A ends at 5:00 PM, but Rule B is active until 6:00 PM.
        // We should keep blocking apps from Rule B.
        refreshShields()
    }

    // Shared helper used by both intervalDidStart and intervalDidEnd.
    private func refreshShields() {
        let appGroupAvailable = FocusLockDiagnostics.appGroupContainerURL() != nil
        FocusLockDiagnostics.record("DeviceActivityMonitor refreshing shields. appGroupAvailable=\(appGroupAvailable).")

        // Load the latest saved rules from the App Group container.
        //
        // This works while the app is closed because the extension can read the same
        // shared App Group storage.
        let rules = FocusLockRuleStore.loadRules()
        FocusLockDiagnostics.record("DeviceActivityMonitor loaded \(rules.count) rule(s).")

        // Ask the shared schedule helper which app tokens should be blocked at this moment.
        let activeApplicationTokens = FocusLockSchedule.activeApplicationTokens(from: rules)
        FocusLockDiagnostics.record("DeviceActivityMonitor active token count: \(activeApplicationTokens.count).")

        // If the set is empty, use nil to remove shields.
        // Otherwise, give iOS the exact selected app tokens to block.
        store.shield.applications = activeApplicationTokens.isEmpty ? nil : activeApplicationTokens
        FocusLockDiagnostics.record(activeApplicationTokens.isEmpty ? "DeviceActivityMonitor cleared shields." : "DeviceActivityMonitor applied shields.")
    }
}
