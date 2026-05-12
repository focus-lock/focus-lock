//
//  FocusLockSchedule.swift
//  focus-lock
//

// DeviceActivity provides DeviceActivitySchedule and DeviceActivityName.
// These are the APIs that let iOS wake our extension at schedule boundaries.
import DeviceActivity

// FamilyControls provides FamilyActivitySelection, which is part of Rule.
import FamilyControls

// Foundation provides Date, Calendar, DateComponents, UUID, Set, etc.
import Foundation

// ManagedSettings provides ApplicationToken.
// This is why the earlier build error happened: ApplicationToken was not in scope.
import ManagedSettings

// Shared schedule helpers.
//
// The app and the DeviceActivity extension should agree on schedule behavior.
// So the "is this rule active right now?" logic lives here once instead of being copied.
enum FocusLockSchedule {
    // DeviceActivity can reject very short schedules with an intervalTooShort error.
    // Keeping the minimum in one shared constant makes the UI validation and
    // schedule registration use the same rule.
    static let minimumMonitorDurationMinutes = 15
    
    
    // Returns true when the picker has at least one selected app, category, or website.
    static func hasSelectedActivity(_ selection: FamilyActivitySelection) -> Bool {
        // Counts direct individual app selections.
        let hasApps = !selection.applicationTokens.isEmpty

        // Counts category selections, including category "Select All".
        let hasCategories = !selection.categoryTokens.isEmpty

        // Counts selected web domains if the user picks websites later.
        let hasWebDomains = !selection.webDomainTokens.isEmpty

        // Treat any of those three token sets as a valid saved selection.
        return hasApps || hasCategories || hasWebDomains
    }


    // Decides whether a rule is worth registering with DeviceActivity.
    //
    // A rule is monitorable if:
    // 1. It is enabled.
    // 2. The user selected at least one app.
    // 3. The interval is long enough for DeviceActivity to accept.
    //
    // Apple throws intervalTooShort when we try tiny test windows like 2 minutes.
    // We use 15 minutes as our current development minimum.
    static func isMonitorable(_ rule: Rule) -> Bool {
        // Requires the rule toggle to be on.
            rule.isEnabled &&

            // Allows app, category, or web domain selections to count.
            hasSelectedActivity(rule.activitySelection) &&

            // Requires the schedule to meet Apple's DeviceActivity minimum duration.
            durationMinutes(for: rule) >= minimumMonitorDurationMinutes
    }

    // Decides whether the current time is inside this rule's blocking window.
    //
    // now: Date = Date() means:
    // "If the caller does not pass a time, use the current time."
    static func isActive(_ rule: Rule, now: Date = Date()) -> Bool {

        // Convert all times into minutes since midnight.
        //
        // Example:
        // 9:30 AM becomes 570.
        // 8:41 PM becomes 1241.
        let nowMinutes = minutesSinceMidnight(now)
        let startMinutes = minutesSinceMidnight(rule.startTime)
        let endMinutes = minutesSinceMidnight(rule.endTime)

        // Same-day schedule.
        //
        // Example:
        // start = 9:00 AM
        // end = 5:00 PM
        //
        // Active if now is >= start AND now is < end.
        if startMinutes < endMinutes {
            return nowMinutes >= startMinutes && nowMinutes < endMinutes
        }

        // Overnight schedule.
        //
        // Example:
        // start = 10:00 PM
        // end = 6:00 AM
        //
        // This crosses midnight, so it is active if now is after start OR before end.
        if startMinutes > endMinutes {
            return nowMinutes >= startMinutes || nowMinutes < endMinutes
        }

        // If start and end are the same, we currently treat the rule as inactive.
        // Later we could decide that same start/end means "block all day."
        return false
    }

    // Builds the exact set of app tokens that should be shielded right now.
    //
    // Set<ApplicationToken> means:
    // "A unique collection of selected app tokens."
    //
    // We use a Set instead of an Array because the same app could appear in multiple rules,
    // but we only need to shield it once.
    static func activeApplicationTokens(from rules: [Rule], now: Date = Date()) -> Set<ApplicationToken> {
        rules
            // filter keeps only the rules that should apply right now.
            //
            // $0 means "the current rule in the array."
            .filter { isMonitorable($0) && isActive($0, now: now) }

            // reduce combines many rules into one Set<ApplicationToken>.
            //
            // into: Set<ApplicationToken>() means:
            // "Start with an empty Set of app tokens."
            //
            // selectedApps is the running Set we are building.
            // rule is the current rule from the filtered rules array.
            .reduce(into: Set<ApplicationToken>()) { selectedApps, rule in

                // Add this rule's selected apps into the running Set.
                selectedApps.formUnion(rule.activitySelection.applicationTokens)
            }
    }
    
    // Builds the active category tokens from currently active rules.
    static func activeCategoryTokens(from rules: [Rule], now: Date = Date()) -> Set<ActivityCategoryToken> {
        // Starts with rules that should apply right now.
        rules.filter { isMonitorable($0) && isActive($0, now: now) }

            // Combines all active category token sets into one set.
            .reduce(into: Set<ActivityCategoryToken>()) { selectedCategories, rule in

                // Adds this rule's selected categories.
                selectedCategories.formUnion(rule.activitySelection.categoryTokens)
            }
    }

    // Builds the active web domain tokens from currently active rules.
    static func activeWebDomainTokens(from rules: [Rule], now: Date = Date()) -> Set<WebDomainToken> {
        // Starts with rules that should apply right now.
        rules.filter { isMonitorable($0) && isActive($0, now: now) }

            // Combines all active web domain token sets into one set.
            .reduce(into: Set<WebDomainToken>()) { selectedWebDomains, rule in

                // Adds this rule's selected web domains.
                selectedWebDomains.formUnion(rule.activitySelection.webDomainTokens)
            }
    }

    // Converts one Rule into the schedule object Apple expects.
    //
    // DeviceActivitySchedule tells iOS:
    // "Call my monitor extension at this start time and end time."
    static func schedule(for rule: Rule) -> DeviceActivitySchedule {
        DeviceActivitySchedule(
            intervalStart: timeComponents(from: rule.startTime),
            intervalEnd: timeComponents(from: rule.endTime),
            repeats: true
        )
    }

    // Returns the rule duration in minutes.
    static func durationMinutes(for rule: Rule) -> Int {
        let startMinutes = minutesSinceMidnight(rule.startTime)
        let endMinutes = minutesSinceMidnight(rule.endTime)

        if startMinutes < endMinutes {
            return endMinutes - startMinutes
        }

        if startMinutes > endMinutes {
            return (24 * 60 - startMinutes) + endMinutes
        }

        return 0
    }

    // Converts a Date into an Int representing minutes since midnight.
    //
    // Example:
    // 1:05 AM -> 65
    // 9:00 AM -> 540
    // 8:42 PM -> 1242
    private static func minutesSinceMidnight(_ date: Date) -> Int {

        // Pull just the hour and minute out of the Date.
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)

        // components.hour is optional because Calendar extraction can theoretically fail.
        // ?? 0 means "use 0 if this optional is nil."
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    // DeviceActivitySchedule wants DateComponents, not full Date values.
    //
    // That is because the schedule repeats daily, so Apple only needs hour/minute.
    private static func timeComponents(from date: Date) -> DateComponents {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return DateComponents(hour: components.hour, minute: components.minute)
    }
}

// This extends Apple's DeviceActivityName type with Focus Lock-specific helpers.
//
// An extension lets us add convenience behavior to a type we did not create.
extension DeviceActivityName {

    // Prefix all of our monitor names so we can recognize them later.
    //
    // Example full value:
    // focus-lock-rule-0D0E0B8B-8D6B-4C8E-9C19-...
    private static let focusLockRulePrefix = "focus-lock-rule-"

    // Custom initializer.
    //
    // It lets us write:
    // DeviceActivityName(ruleID: rule.id)
    //
    // instead of manually building the string everywhere.
    init(ruleID: UUID) {
        self.init(Self.focusLockRulePrefix + ruleID.uuidString)
    }

    // Computed property that tells us whether this DeviceActivityName belongs to Focus Lock.
    //
    // rawValue is the underlying string inside DeviceActivityName.
    var isFocusLockRuleActivity: Bool {
        rawValue.hasPrefix(Self.focusLockRulePrefix)
    }
}
