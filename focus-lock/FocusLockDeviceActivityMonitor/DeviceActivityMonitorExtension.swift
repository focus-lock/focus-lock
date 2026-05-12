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

        // Ask the shared schedule helper which app category tokens should be blocked at this moment.
        let activeCategoryTokens = FocusLockSchedule.activeCategoryTokens(from: rules)

        // Ask the shared schedule helper which web domain tokens should be blocked at this moment.
        let activeWebDomainTokens = FocusLockSchedule.activeWebDomainTokens(from: rules)

        // Record the active token counts so diagnostics show apps, categories, and websites separately.
        FocusLockDiagnostics.record("DeviceActivityMonitor active token counts: apps=\(activeApplicationTokens.count), categories=\(activeCategoryTokens.count), webDomains=\(activeWebDomainTokens.count).")

        // If the app token set is empty, use nil to remove direct app shields.
        // Otherwise, give iOS the exact selected app tokens to block.
        store.shield.applications = activeApplicationTokens.isEmpty ? nil : activeApplicationTokens

        // If the category token set is empty, use nil to remove category shields.
        // Otherwise, give iOS the selected app categories to block.
        store.shield.applicationCategories = activeCategoryTokens.isEmpty ? nil : .specific(activeCategoryTokens)

        // If the web domain token set is empty, use nil to remove website shields.
        // Otherwise, give iOS the exact selected web domains to block.
        store.shield.webDomains = activeWebDomainTokens.isEmpty ? nil : activeWebDomainTokens

        // Check whether any kind of shield is active after this refresh.
        let hasActiveShields = !activeApplicationTokens.isEmpty || !activeCategoryTokens.isEmpty || !activeWebDomainTokens.isEmpty

        // Record whether the monitor cleared every shield or applied at least one shield.
        FocusLockDiagnostics.record(hasActiveShields ? "DeviceActivityMonitor applied shields." : "DeviceActivityMonitor cleared shields.")
    }
}
