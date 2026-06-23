//
//  DeviceActivityMonitorExtension.swift
//  FocusLockDeviceActivityMonitor
//

// DeviceActivity gives us DeviceActivityMonitor and DeviceActivityName.
// iOS calls this extension when a registered schedule starts or ends.
import DeviceActivity

// Foundation gives us Date for recording when a usage limit was reached.
import Foundation

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
    
    // DeviceActivityCenter lets the extension stop monitoring a completed one-time rule.
    private let center = DeviceActivityCenter()

    // iOS calls this when one of our monitored rule intervals starts.
    //
    // Example:
    // Rule is 9:00 AM - 5:00 PM.
    // At 9:00 AM, iOS calls intervalDidStart.
    override func intervalDidStart(for activity: DeviceActivityName) {
        FocusLockDiagnostics.record("DeviceActivityMonitor intervalDidStart fired for \(activity.rawValue).")

        // Let Apple's base class do any default work first.
        super.intervalDidStart(for: activity)

        // Usage-limit rules reset when their daily monitoring interval starts.
        clearExpiredUsageLimitStateIfNeeded()

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
        
        // Remove a completed one-time rule before recalculating shields.
        deleteCompletedOneTimeRuleIfNeeded(for: activity)

        // Recompute instead of blindly clearing everything.
        //
        // This matters if two rules overlap:
        // Rule A ends at 5:00 PM, but Rule B is active until 6:00 PM.
        // We should keep blocking apps from Rule B.
        refreshShields()
    }

    // iOS calls this when a monitored usage-limit event reaches its threshold.
    //
    // Example:
    // Rule allows 30 minutes of Instagram today.
    // Once iOS counts 30 minutes of selected activity, this method fires.
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        FocusLockDiagnostics.record("DeviceActivityMonitor eventDidReachThreshold fired for event=\(event.rawValue), activity=\(activity.rawValue).")

        super.eventDidReachThreshold(event, activity: activity)

        markUsageLimitReachedIfNeeded(for: event)
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
        let rules = cleanedRulesFromStorage()
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

    // Loads rules and clears stale usage-limit reached state before using them.
    private func cleanedRulesFromStorage() -> [Rule] {
        let rules = FocusLockRuleStore.loadRules()
        let cleanedRules = FocusLockSchedule.clearingExpiredUsageLimitState(from: rules)

        let didClearAnyUsageLimitState = zip(rules, cleanedRules).contains { oldRule, newRule in
            oldRule.usageLimitReachedAt != newRule.usageLimitReachedAt
        }

        if didClearAnyUsageLimitState {
            FocusLockRuleStore.saveRules(cleanedRules)
            FocusLockDiagnostics.record("DeviceActivityMonitor cleared expired usage-limit state while loading rules.")
        }

        return cleanedRules
    }

    // Clears yesterday's reached flags so usage-limit rules reset for the new day.
    private func clearExpiredUsageLimitStateIfNeeded() {
        _ = cleanedRulesFromStorage()
    }

    // Marks a usage-limit rule as reached after iOS fires its threshold event.
    private func markUsageLimitReachedIfNeeded(for event: DeviceActivityEvent.Name) {
        guard let reachedRuleID = event.focusLockUsageLimitRuleID else {
            FocusLockDiagnostics.record("DeviceActivityMonitor ignored non-Focus-Lock threshold event \(event.rawValue).")
            return
        }

        var rules = FocusLockRuleStore.loadRules()

        guard let index = rules.firstIndex(where: { $0.id == reachedRuleID }) else {
            FocusLockDiagnostics.record("DeviceActivityMonitor found no saved rule for threshold event \(event.rawValue).")
            return
        }

        guard rules[index].ruleKind == .usageLimit else {
            FocusLockDiagnostics.record("DeviceActivityMonitor ignored threshold event for non-usage-limit rule \(rules[index].id).")
            return
        }

        rules[index].usageLimitReachedAt = Date()
        FocusLockRuleStore.saveRules(rules)
        FocusLockDiagnostics.record("DeviceActivityMonitor marked usage-limit rule \(rules[index].id) as reached.")
    }
    
    // Deletes a one-time rule after iOS tells us its interval ended.
    private func deleteCompletedOneTimeRuleIfNeeded(for activity: DeviceActivityName) {
        // Pull the rule id out of the DeviceActivityName.
        guard let endedRuleID = activity.focusLockRuleID else {
            // Record that this activity was not one of our rule schedules.
            FocusLockDiagnostics.record("DeviceActivityMonitor could not find a Focus Lock rule id for \(activity.rawValue).")
            // Stop because there is no rule id to delete.
            return
        }
        
        // Load the latest rules from shared App Group storage.
        let rules = FocusLockRuleStore.loadRules()
        
        // Find the rule whose schedule just ended.
        guard let endedRule = rules.first(where: { $0.id == endedRuleID }) else {
            // Record that the rule may have already been deleted.
            FocusLockDiagnostics.record("DeviceActivityMonitor found no saved rule for ended activity \(activity.rawValue).")
            // Stop because there is no saved rule to delete.
            return
        }
        
        // Only one-time rules should delete themselves after ending.
        guard endedRule.isOneTime else {
            // Record that recurring rules stay saved after each interval ends.
            FocusLockDiagnostics.record("DeviceActivityMonitor leaving recurring rule \(endedRule.id) saved after interval end.")
            // Stop because recurring rules should keep repeating.
            return
        }
        
        // Make sure the one-time rule has truly reached its end time.
        guard FocusLockSchedule.isCompletedOneTimeRule(endedRule) else {
            // Record that iOS called intervalDidEnd but our schedule math does not consider the rule completed yet.
            FocusLockDiagnostics.record("DeviceActivityMonitor did not delete one-time rule \(endedRule.id) because it is not completed yet.")
            // Stop because deleting early would be confusing and risky.
            return
        }
        
        // Build a new rules array without the completed one-time rule.
        let remainingRules = rules.filter { $0.id != endedRuleID }
        
        // Save the updated rules array back to App Group storage.
        FocusLockRuleStore.saveRules(remainingRules)
        
        // Tell iOS to stop monitoring this completed one-time schedule.
        center.stopMonitoring([activity])
        
        // Record that the one-time rule was removed successfully.
        FocusLockDiagnostics.record("DeviceActivityMonitor deleted completed one-time rule \(endedRule.id).")
    }
}
