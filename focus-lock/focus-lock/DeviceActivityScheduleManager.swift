//
//  DeviceActivityScheduleManager.swift
//  focus-lock
//

// DeviceActivity gives us DeviceActivityCenter.
// The center is the object the main app uses to register schedules with iOS.
import DeviceActivity

// FamilyControls defines FamilyActivitySelection.applicationTokens.
// This file reads rule.activitySelection.applicationTokens for diagnostics.
import FamilyControls

// Foundation gives us Set, Array, print, etc.
import Foundation

// This class belongs to the main app target.
//
// Its job is NOT to block apps directly.
// Its job is to tell iOS:
// "Please wake my DeviceActivity monitor extension at these rule start/end times."
final class DeviceActivityScheduleManager {

    // Singleton pattern.
    //
    // This gives the app one shared schedule manager:
    // DeviceActivityScheduleManager.shared
    static let shared = DeviceActivityScheduleManager()

    // DeviceActivityCenter is Apple's schedule registration object.
    private let center = DeviceActivityCenter()

    // Make iOS's registered schedules match our current rules array.
    //
    // We call this after adding, toggling, deleting, and loading rules.
    func syncSchedules(for rules: [Rule]) {
        FocusLockDiagnostics.record("ScheduleManager sync requested with \(rules.count) total rule(s).")

        // Keep only rules that should actually be monitored.
        let monitorableRules = rules.filter(FocusLockSchedule.isMonitorable)
        FocusLockDiagnostics.record("ScheduleManager found \(monitorableRules.count) monitorable rule(s).")

        for rule in rules where !FocusLockSchedule.isMonitorable(rule) {
            FocusLockDiagnostics.record(
                "ScheduleManager skipping rule \(rule.id): enabled=\(rule.isEnabled), selectedApps=\(rule.activitySelection.applicationTokens.count), durationMinutes=\(FocusLockSchedule.durationMinutes(for: rule)), minimumDurationMinutes=\(FocusLockSchedule.minimumMonitorDurationMinutes)."
            )
        }

        // Convert each rule into the DeviceActivityName we expect iOS to know about.
        //
        // map transforms [Rule] into [DeviceActivityName].
        // Set(...) turns it into a unique collection.
        let expectedActivities = Set(monitorableRules.map { DeviceActivityName(ruleID: $0.id) })

        // center.activities is what iOS is currently monitoring for this app.
        //
        // We filter down to only the activities created by Focus Lock.
        // \.isFocusLockRuleActivity is Swift key-path shorthand for:
        // { activity in activity.isFocusLockRuleActivity }
        let existingFocusLockActivities = Set(center.activities.filter(\.isFocusLockRuleActivity))

        // Anything existing in iOS but no longer expected by our rules should be removed.
        //
        // Example:
        // User deletes a rule.
        // We need to stop monitoring that old rule's schedule.
        let obsoleteActivities = existingFocusLockActivities.subtracting(expectedActivities)
        FocusLockDiagnostics.record("ScheduleManager existing activities: \(existingFocusLockActivities.map(\.rawValue).sorted()).")
        FocusLockDiagnostics.record("ScheduleManager expected activities: \(expectedActivities.map(\.rawValue).sorted()).")

        // If there are obsolete activities, ask iOS to stop monitoring them.
        if !obsoleteActivities.isEmpty {
            FocusLockDiagnostics.record("ScheduleManager stopping obsolete activities: \(obsoleteActivities.map(\.rawValue).sorted()).")
            center.stopMonitoring(Array(obsoleteActivities))
        }

        // Register or update every current monitorable rule.
        for rule in monitorableRules {
            let startComponents = Calendar.current.dateComponents([.hour, .minute], from: rule.startTime)
            let endComponents = Calendar.current.dateComponents([.hour, .minute], from: rule.endTime)
            let activityName = DeviceActivityName(ruleID: rule.id)

            FocusLockDiagnostics.record(
                "ScheduleManager registering rule \(rule.id) as \(activityName.rawValue), start=\(startComponents.hour ?? -1):\(startComponents.minute ?? -1), end=\(endComponents.hour ?? -1):\(endComponents.minute ?? -1), selectedApps=\(rule.activitySelection.applicationTokens.count)."
            )

            // startMonitoring can throw an error, so it must be called with try.
            do {
                try center.startMonitoring(
                    activityName,
                    during: FocusLockSchedule.schedule(for: rule)
                )
                FocusLockDiagnostics.record("ScheduleManager successfully registered \(activityName.rawValue).")
            } catch {
                FocusLockDiagnostics.record("ScheduleManager failed to register \(activityName.rawValue): \(error)")
            }
        }

        FocusLockDiagnostics.record("ScheduleManager center activities after sync: \(center.activities.map(\.rawValue).sorted()).")
    }
}
