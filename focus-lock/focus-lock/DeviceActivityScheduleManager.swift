//
//  DeviceActivityScheduleManager.swift
//  focus-lock
//

// Imports Apple's DeviceActivity scheduling tools.
import DeviceActivity

// Imports Apple's Screen Time picker types.
import FamilyControls

// Imports basic Swift types like Set, Array, and Calendar.
import Foundation

// Creates one object responsible for registering rule schedules with iOS.
final class DeviceActivityScheduleManager {

    // Creates one shared schedule manager for the whole app.
    static let shared = DeviceActivityScheduleManager()

    // Creates Apple's schedule registration center.
    private let center = DeviceActivityCenter()

    // Makes iOS's registered schedules match the app's saved rules.
    func syncSchedules(for rules: [Rule]) {
        // Records how many total rules were sent into schedule sync.
        FocusLockDiagnostics.record("ScheduleManager sync requested with \(rules.count) total rule(s).")

        // Keeps only rules that are enabled, valid, long enough, and not completed.
        let monitorableRules = rules.filter { FocusLockSchedule.isMonitorable($0) }

        // Records how many rules can actually be monitored.
        FocusLockDiagnostics.record("ScheduleManager found \(monitorableRules.count) monitorable rule(s).")

        // Looks at every rule that cannot currently be monitored.
        for rule in rules where !FocusLockSchedule.isMonitorable(rule) {
            // Records why this rule may have been skipped.
            FocusLockDiagnostics.record(
                "ScheduleManager skipping rule \(rule.id): enabled=\(rule.isEnabled), selectedApps=\(rule.activitySelection.applicationTokens.count), durationMinutes=\(FocusLockSchedule.durationMinutes(for: rule)), minimumDurationMinutes=\(FocusLockSchedule.minimumMonitorDurationMinutes), recurrence=\(FocusLockSchedule.recurrenceSummary(for: rule))."
            )
        }

        // Builds the set of DeviceActivity names iOS should currently monitor.
        let expectedActivities = Set(monitorableRules.map { DeviceActivityName(ruleID: $0.id) })

        // Reads the set of Focus Lock activities iOS is already monitoring.
        let existingFocusLockActivities = Set(center.activities.filter(\.isFocusLockRuleActivity))

        // Finds old iOS schedules that no longer match saved monitorable rules.
        let obsoleteActivities = existingFocusLockActivities.subtracting(expectedActivities)

        // Records the activities iOS is currently monitoring.
        FocusLockDiagnostics.record("ScheduleManager existing activities: \(existingFocusLockActivities.map(\.rawValue).sorted()).")

        // Records the activities Focus Lock expects iOS to monitor.
        FocusLockDiagnostics.record("ScheduleManager expected activities: \(expectedActivities.map(\.rawValue).sorted()).")

        // Checks whether there are old schedules to remove.
        if !obsoleteActivities.isEmpty {
            // Records which old schedules are being stopped.
            FocusLockDiagnostics.record("ScheduleManager stopping obsolete activities: \(obsoleteActivities.map(\.rawValue).sorted()).")

            // Tells iOS to stop monitoring schedules for deleted, disabled, invalid, or completed rules.
            center.stopMonitoring(Array(obsoleteActivities))
        }

        // Registers or updates every rule that should be monitored.
        for rule in monitorableRules {
            // Builds the unique DeviceActivity name for this rule.
            let activityName = DeviceActivityName(ruleID: rule.id)

            // Starts a block that can catch schedule registration errors.
            do {
                if rule.ruleKind == .usageLimit {
                    // Build the daily usage threshold event for this rule.
                    guard let usageLimitEvent = FocusLockSchedule.usageLimitEvent(for: rule) else {
                        FocusLockDiagnostics.record("ScheduleManager could not build usage-limit event for rule \(rule.id).")
                        continue
                    }

                    let eventName = DeviceActivityEvent.Name(usageLimitRuleID: rule.id)

                    FocusLockDiagnostics.record(
                        "ScheduleManager registering usage-limit rule \(rule.id) as \(activityName.rawValue), event=\(eventName.rawValue), limitMinutes=\(rule.usageLimitMinutes ?? 0), selectedApps=\(rule.activitySelection.applicationTokens.count), selectedCategories=\(rule.activitySelection.categoryTokens.count), selectedWebDomains=\(rule.activitySelection.webDomainTokens.count)."
                    )

                    // Tells iOS to count selected activity and call the monitor extension
                    // when the threshold is reached inside the daily schedule.
                    try center.startMonitoring(
                        activityName,
                        during: FocusLockSchedule.schedule(for: rule),
                        events: [eventName: usageLimitEvent]
                    )
                } else {
                    // Pulls the start hour and minute from the rule.
                    let startComponents = Calendar.current.dateComponents([.hour, .minute], from: rule.startTime)

                    // Pulls the end hour and minute from the rule.
                    let endComponents = Calendar.current.dateComponents([.hour, .minute], from: rule.endTime)

                    // Records the schedule registration details for debugging.
                    FocusLockDiagnostics.record(
                        "ScheduleManager registering scheduled rule \(rule.id) as \(activityName.rawValue), start=\(startComponents.hour ?? -1):\(startComponents.minute ?? -1), end=\(endComponents.hour ?? -1):\(endComponents.minute ?? -1), selectedApps=\(rule.activitySelection.applicationTokens.count), recurrence=\(FocusLockSchedule.recurrenceSummary(for: rule))."
                    )

                    // Tells iOS to monitor this rule's schedule.
                    try center.startMonitoring(
                        // Passes the unique name for this rule's schedule.
                        activityName,
                        // Passes either a repeating or one-time schedule.
                        during: FocusLockSchedule.schedule(for: rule)
                    )
                }

                // Records that iOS accepted the schedule.
                FocusLockDiagnostics.record("ScheduleManager successfully registered \(activityName.rawValue).")
            } catch {
                // Records that iOS rejected or failed to register the schedule.
                FocusLockDiagnostics.record("ScheduleManager failed to register \(activityName.rawValue): \(error)")
            }
        }

        // Records all Focus Lock activities after schedule sync finishes.
        FocusLockDiagnostics.record("ScheduleManager center activities after sync: \(center.activities.map(\.rawValue).sorted()).")
    }
}
