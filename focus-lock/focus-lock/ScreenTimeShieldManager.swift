//
//  ScreenTimeShieldManager.swift
//  focus-lock
//
//  Created by Suraj Modur on 5/8/26.
//

import Foundation
import ManagedSettings
import FamilyControls

final class ScreenTimeShieldManager {
    static let shared = ScreenTimeShieldManager()

    private let store = ManagedSettingsStore()

    // Checks whether the current time falls inside a rule's start/end time.
    // This compares only hour/minute, not the full date, because your rules repeat daily.
    private func isRuleActiveRightNow(_ rule: Rule, now: Date = Date()) -> Bool {
        let calendar = Calendar.current

        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        let startComponents = calendar.dateComponents([.hour, .minute], from: rule.startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: rule.endTime)

        let nowMinutes = (nowComponents.hour ?? 0) * 60 + (nowComponents.minute ?? 0)
        let startMinutes = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
        let endMinutes = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)

        // Normal same-day schedule, like 9:00 AM to 5:00 PM.
        if startMinutes < endMinutes {
            return nowMinutes >= startMinutes && nowMinutes < endMinutes
        }

        // Overnight schedule, like 9:00 PM to 12:00 AM or 10:00 PM to 6:00 AM.
        // In this case, the active window crosses midnight.
        if startMinutes > endMinutes {
            return nowMinutes >= startMinutes || nowMinutes < endMinutes
        }

        // If start and end are the same, treat it as inactive for now.
        // Later you could decide this means "blocked all day" if you want.
        return false
    }

    // Rebuilds the shield list from rules that are enabled and active right now.
    // Apps outside their scheduled time are not shielded.
    //
    // Important limitation:
    // This method only checks the time at the moment it is called.
    // Example: if you create a 9:00 AM - 10:00 AM rule at 8:30 AM,
    // this method will correctly decide not to block yet. But the block will not
    // automatically turn on at 9:00 AM unless something calls syncShields again.
    // Later, DeviceActivityMonitor should handle that automatic start/end behavior.
    func syncShields(for rules: [Rule]) {
        let activeApplicationTokens = rules
            .filter { rule in
                rule.isEnabled && isRuleActiveRightNow(rule)
            }
            .reduce(into: Set<ApplicationToken>()) { selectedApps, rule in
                selectedApps.formUnion(rule.activitySelection.applicationTokens)
            }

        // If no rules are active right now, remove all shields.
        store.shield.applications = activeApplicationTokens.isEmpty ? nil : activeApplicationTokens
    }

    // Applies shields based on all rules instead of blindly shielding one saved rule.
    // Use this after creating, deleting, or toggling a rule.
    func refreshShields(for rules: [Rule]) {
        syncShields(for: rules)
    }

    // Removes all app shields managed by this store.
    func clearShields() {
        store.shield.applications = nil
    }
}
