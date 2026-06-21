//
//  FocusLockSchedule.swift
//  focus-lock
//

// Imports Apple's scheduling types that wake the monitor extension.
import DeviceActivity

// Imports Apple's Screen Time picker selection type.
import FamilyControls

// Imports basic Swift date, calendar, UUID, and collection types.
import Foundation

// Imports Apple's shield token types for apps, categories, and websites.
import ManagedSettings

// Groups all shared schedule helper functions in one place.
enum FocusLockSchedule {
    // Stores the shortest rule duration DeviceActivity should try to monitor.
    static let minimumMonitorDurationMinutes = 15

    // Stores weekdays in the order we want to show them.
    static let weekdayDisplayOrder = [1, 2, 3, 4, 5, 6, 7]

    // Stores short text labels for each weekday number.
    static let weekdayShortLabels: [Int: String] = [
        // Stores the label for Sunday.
        1: "Sun",
        // Stores the label for Monday.
        2: "Mon",
        // Stores the label for Tuesday.
        3: "Tue",
        // Stores the label for Wednesday.
        4: "Wed",
        // Stores the label for Thursday.
        5: "Thu",
        // Stores the label for Friday.
        6: "Fri",
        // Stores the label for Saturday.
        7: "Sat"
    ]

    // Checks whether the user selected any apps, categories, or websites.
    static func hasSelectedActivity(_ selection: FamilyActivitySelection) -> Bool {
        // Checks whether individual apps were selected.
        let hasApps = !selection.applicationTokens.isEmpty

        // Checks whether app categories were selected.
        let hasCategories = !selection.categoryTokens.isEmpty

        // Checks whether websites were selected.
        let hasWebDomains = !selection.webDomainTokens.isEmpty

        // Returns true if any selectable Screen Time item was picked.
        return hasApps || hasCategories || hasWebDomains
    }

    // Checks whether a rule should be registered with DeviceActivity.
    static func isMonitorable(_ rule: Rule, now: Date = Date()) -> Bool {
        // Checks that the rule is turned on.
        let isEnabled = rule.isEnabled

        // Checks that the rule has something to block.
        let hasActivity = hasSelectedActivity(rule.activitySelection)

        // Checks that the rule is long enough for DeviceActivity.
        let hasEnoughDuration = durationMinutes(for: rule) >= minimumMonitorDurationMinutes

        // Usage-limit rules do not use recurrence settings, but they still need a valid limit.
        if rule.ruleKind == .usageLimit {
            return isEnabled && hasActivity && hasEnoughDuration
        }

        // Checks that recurrence data is valid.
        let recurrenceIsValid = hasValidRecurrence(rule)

        // Checks that a one-time rule has not already ended.
        let hasNotCompleted = !isCompletedOneTimeRule(rule, now: now)

        // Returns true only when every required condition is true.
        return isEnabled && hasActivity && hasEnoughDuration && recurrenceIsValid && hasNotCompleted
    }

    // Checks whether the rule has usable recurrence settings.
    static func hasValidRecurrence(_ rule: Rule) -> Bool {
        // Recurring rules are valid when at least one weekday is selected.
        if rule.isRecurring {
            // Tells the caller this recurring rule is valid.
            return true
        }

        // One-time rules are valid only when they have a calendar date.
        return rule.oneTimeDate != nil
    }

    // Checks whether the current time is inside this rule's blocking window.
    static func isActive(_ rule: Rule, now: Date = Date()) -> Bool {
        // Usage-limit rules become active only after iOS tells us today's limit was reached.
        if rule.ruleKind == .usageLimit {
            return hasReachedUsageLimitToday(rule, now: now)
        }

        // Uses exact dates for one-time rules.
        if rule.isOneTime {
            // Returns whether this exact one-time session is active now.
            return isOneTimeRuleActive(rule, now: now)
        }

        // Returns whether this recurring rule is active now.
        return isRecurringRuleActive(rule, now: now)
    }

    // Builds the app tokens that should be blocked right now.
    static func activeApplicationTokens(from rules: [Rule], now: Date = Date()) -> Set<ApplicationToken> {
        // Starts with an empty set so duplicate app tokens collapse into one value.
        var activeTokens = Set<ApplicationToken>()

        // Looks at every saved rule one at a time.
        for rule in rules {
            // Skips rules that should not currently block anything.
            guard isMonitorable(rule, now: now) && isActive(rule, now: now) else {
                // Moves on to the next rule.
                continue
            }

            // Adds this rule's selected apps into the shared active set.
            activeTokens.formUnion(rule.activitySelection.applicationTokens)
        }

        // Gives the caller the full set of apps to shield.
        return activeTokens
    }

    // Builds the category tokens that should be blocked right now.
    static func activeCategoryTokens(from rules: [Rule], now: Date = Date()) -> Set<ActivityCategoryToken> {
        // Starts with an empty set so duplicate categories collapse into one value.
        var activeTokens = Set<ActivityCategoryToken>()

        // Looks at every saved rule one at a time.
        for rule in rules {
            // Skips rules that should not currently block anything.
            guard isMonitorable(rule, now: now) && isActive(rule, now: now) else {
                // Moves on to the next rule.
                continue
            }

            // Adds this rule's selected categories into the shared active set.
            activeTokens.formUnion(rule.activitySelection.categoryTokens)
        }

        // Gives the caller the full set of categories to shield.
        return activeTokens
    }

    // Builds the website tokens that should be blocked right now.
    static func activeWebDomainTokens(from rules: [Rule], now: Date = Date()) -> Set<WebDomainToken> {
        // Starts with an empty set so duplicate websites collapse into one value.
        var activeTokens = Set<WebDomainToken>()

        // Looks at every saved rule one at a time.
        for rule in rules {
            // Skips rules that should not currently block anything.
            guard isMonitorable(rule, now: now) && isActive(rule, now: now) else {
                // Moves on to the next rule.
                continue
            }

            // Adds this rule's selected websites into the shared active set.
            activeTokens.formUnion(rule.activitySelection.webDomainTokens)
        }

        // Gives the caller the full set of websites to shield.
        return activeTokens
    }

    // Builds the DeviceActivity schedule that iOS will monitor.
    static func schedule(for rule: Rule) -> DeviceActivitySchedule {
        // Usage-limit rules count selected activity across the current day.
        if rule.ruleKind == .usageLimit {
            return dailyUsageLimitSchedule()
        }

        // Uses a non-repeating schedule for a one-time rule.
        if rule.isOneTime {
            // Creates one exact calendar interval for iOS to monitor.
            return DeviceActivitySchedule(
                // Sets the exact start date and time.
                intervalStart: oneTimeStartComponents(for: rule),
                // Sets the exact end date and time.
                intervalEnd: oneTimeEndComponents(for: rule),
                // Tells iOS this schedule should happen only once.
                repeats: false
            )
        }

        // Creates a repeating daily schedule for recurring rules.
        return DeviceActivitySchedule(
            // Sets the daily start time.
            intervalStart: timeComponents(from: rule.startTime),
            // Sets the daily end time.
            intervalEnd: timeComponents(from: rule.endTime),
            // Tells iOS this schedule repeats.
            repeats: true
        )
    }

    // Calculates how many minutes the rule lasts.
    static func durationMinutes(for rule: Rule) -> Int {
        // Usage-limit rules store their allowed daily screen time directly.
        if rule.ruleKind == .usageLimit {
            return rule.usageLimitMinutes ?? 0
        }

        // Converts the start time into minutes after midnight.
        let startMinutes = minutesSinceMidnight(rule.startTime)

        // Converts the end time into minutes after midnight.
        let endMinutes = minutesSinceMidnight(rule.endTime)

        // Handles rules that start and end on the same day.
        if startMinutes < endMinutes {
            // Returns the same-day duration.
            return endMinutes - startMinutes
        }

        // Handles rules that pass midnight.
        if startMinutes > endMinutes {
            // Returns the overnight duration.
            return (24 * 60 - startMinutes) + endMinutes
        }

        // Treats matching start and end times as zero minutes.
        return 0
    }

    // Checks whether a one-time rule has already finished.
    static func isCompletedOneTimeRule(_ rule: Rule, now: Date = Date()) -> Bool {
        // Usage-limit rules reset daily instead of completing once.
        guard rule.ruleKind == .scheduled else {
            return false
        }

        // Recurring rules never complete once.
        guard rule.isOneTime else {
            // Tells the caller this is not a completed one-time rule.
            return false
        }

        // Builds the exact one-time interval if possible.
        guard let interval = oneTimeInterval(for: rule) else {
            // Treats invalid one-time data as not completed here.
            return false
        }

        // Returns true when now is at or after the one-time end.
        return now >= interval.end
    }

    // Builds display text that explains how a rule repeats.
    static func recurrenceSummary(for rule: Rule) -> String {
        // Usage-limit rules reset every day.
        if rule.ruleKind == .usageLimit {
            return "Daily usage limit"
        }

        // Handles one-time rules first.
        if rule.isOneTime {
            // Checks whether the one-time rule has a saved date.
            if let oneTimeDate = rule.oneTimeDate {
                // Turns the saved date into readable text.
                let dateText = oneTimeDate.formatted(date: .abbreviated, time: .omitted)
                
                // Returns one-time text with the exact date.
                return "One time: \(dateText)"
            }
            
            // Returns the one-time label.
            return "One time"
        }

        // Checks whether every weekday is selected.
        if rule.repeatWeekdays == Rule.allWeekdays {
            // Returns the daily label.
            return "Daily"
        }

        // Starts with an empty list of selected weekday labels.
        var labels: [String] = []

        // Walks through weekdays in display order.
        for weekday in weekdayDisplayOrder {
            // Skips weekdays this rule does not repeat on.
            guard rule.repeatWeekdays.contains(weekday) else {
                // Moves on to the next weekday.
                continue
            }

            // Safely reads the short label for this weekday number.
            guard let label = weekdayShortLabels[weekday] else {
                // Moves on if the label dictionary is missing a value.
                continue
            }

            // Adds the weekday label to the display list.
            labels.append(label)
        }

        // Joins labels into text like "Mon, Wed, Fri".
        return labels.joined(separator: ", ")
    }

    // Checks whether a usage-limit rule has reached its limit during the current day.
    static func hasReachedUsageLimitToday(_ rule: Rule, now: Date = Date()) -> Bool {
        // Only usage-limit rules use usageLimitReachedAt.
        guard rule.ruleKind == .usageLimit else {
            return false
        }

        // Reads the last threshold date.
        guard let reachedAt = rule.usageLimitReachedAt else {
            return false
        }

        // The rule blocks only for the calendar day when the threshold was reached.
        return Calendar.current.isDate(reachedAt, inSameDayAs: now)
    }

    // Returns a copy of rules with stale usage-limit reached flags cleared.
    static func clearingExpiredUsageLimitState(from rules: [Rule], now: Date = Date()) -> [Rule] {
        rules.map { rule in
            var cleanedRule = rule

            guard cleanedRule.ruleKind == .usageLimit,
                  let reachedAt = cleanedRule.usageLimitReachedAt,
                  !Calendar.current.isDate(reachedAt, inSameDayAs: now) else {
                return cleanedRule
            }

            cleanedRule.usageLimitReachedAt = nil
            return cleanedRule
        }
    }

    // Builds the daily threshold event for a usage-limit rule.
    static func usageLimitEvent(for rule: Rule) -> DeviceActivityEvent? {
        // Usage-limit rules need a positive minute threshold.
        guard rule.ruleKind == .usageLimit,
              let usageLimitMinutes = rule.usageLimitMinutes,
              usageLimitMinutes >= minimumMonitorDurationMinutes else {
            return nil
        }

        return DeviceActivityEvent(
            applications: rule.activitySelection.applicationTokens,
            categories: rule.activitySelection.categoryTokens,
            webDomains: rule.activitySelection.webDomainTokens,
            threshold: DateComponents(minute: usageLimitMinutes)
        )
    }

    // Checks whether a one-time rule is active right now.
    private static func isOneTimeRuleActive(_ rule: Rule, now: Date) -> Bool {
        // Builds the exact one-time interval if possible.
        guard let interval = oneTimeInterval(for: rule) else {
            // Says the rule is inactive if its date data is missing.
            return false
        }

        // Returns true only while now is inside the interval.
        return now >= interval.start && now < interval.end
    }

    // Checks whether a recurring rule is active right now.
    private static func isRecurringRuleActive(_ rule: Rule, now: Date) -> Bool {
        // Converts the current time into minutes after midnight.
        let nowMinutes = minutesSinceMidnight(now)

        // Converts the rule start time into minutes after midnight.
        let startMinutes = minutesSinceMidnight(rule.startTime)

        // Converts the rule end time into minutes after midnight.
        let endMinutes = minutesSinceMidnight(rule.endTime)

        // Gets today's weekday number from the calendar.
        let todayWeekday = Calendar.current.component(.weekday, from: now)

        // Handles rules that start and end on the same day.
        if startMinutes < endMinutes {
            // Checks whether today is one of the selected repeat days.
            let repeatsToday = rule.repeatWeekdays.contains(todayWeekday)

            // Checks whether now is after the start time.
            let isAfterStart = nowMinutes >= startMinutes

            // Checks whether now is before the end time.
            let isBeforeEnd = nowMinutes < endMinutes

            // Returns true only when the day and time both match.
            return repeatsToday && isAfterStart && isBeforeEnd
        }

        // Handles rules that cross midnight.
        if startMinutes > endMinutes {
            // Finds the weekday that came before today.
            let previousWeekday = weekdayBefore(todayWeekday)

            // Checks whether today's late-night start portion applies.
            let isAfterStartOnSelectedDay = rule.repeatWeekdays.contains(todayWeekday) && nowMinutes >= startMinutes

            // Checks whether today's early-morning portion belongs to yesterday's rule.
            let isBeforeEndFromPreviousSelectedDay = rule.repeatWeekdays.contains(previousWeekday) && nowMinutes < endMinutes

            // Returns true if either half of the overnight rule applies.
            return isAfterStartOnSelectedDay || isBeforeEndFromPreviousSelectedDay
        }

        // Treats equal start and end times as inactive.
        return false
    }

    // Builds the exact start and end dates for a one-time rule.
    private static func oneTimeInterval(for rule: Rule) -> DateInterval? {
        // Reads the chosen calendar date for this one-time rule.
        guard let oneTimeDate = rule.oneTimeDate else {
            // Stops if the one-time rule has no date.
            return nil
        }

        // Pulls the hour and minute out of the saved start time.
        let startComponents = Calendar.current.dateComponents([.hour, .minute], from: rule.startTime)

        // Pulls the hour and minute out of the saved end time.
        let endComponents = Calendar.current.dateComponents([.hour, .minute], from: rule.endTime)

        // Combines the one-time date with the start hour and minute.
        guard let startDate = Calendar.current.date(
            // Sets the start hour.
            bySettingHour: startComponents.hour ?? 0,
            // Sets the start minute.
            minute: startComponents.minute ?? 0,
            // Sets seconds to zero.
            second: 0,
            // Uses the selected one-time date.
            of: oneTimeDate
        ) else {
            // Stops if Swift cannot build the start date.
            return nil
        }

        // Combines the one-time date with the end hour and minute.
        guard var endDate = Calendar.current.date(
            // Sets the end hour.
            bySettingHour: endComponents.hour ?? 0,
            // Sets the end minute.
            minute: endComponents.minute ?? 0,
            // Sets seconds to zero.
            second: 0,
            // Uses the selected one-time date.
            of: oneTimeDate
        ) else {
            // Stops if Swift cannot build the end date.
            return nil
        }

        // Checks whether the rule crosses midnight.
        if endDate <= startDate {
            // Moves the end date to the next day for overnight rules.
            guard let nextDayEndDate = Calendar.current.date(byAdding: .day, value: 1, to: endDate) else {
                // Stops if Swift cannot calculate the next day.
                return nil
            }

            // Stores the corrected overnight end date.
            endDate = nextDayEndDate
        }

        // Returns the exact one-time start and end as one interval.
        return DateInterval(start: startDate, end: endDate)
    }

    // Builds the start DateComponents for a one-time DeviceActivity schedule.
    private static func oneTimeStartComponents(for rule: Rule) -> DateComponents {
        // Builds the exact one-time interval if possible.
        guard let interval = oneTimeInterval(for: rule) else {
            // Falls back to time-only components if the interval is missing.
            return timeComponents(from: rule.startTime)
        }

        // Returns full date and time pieces for the start.
        return Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: interval.start)
    }

    // Builds the end DateComponents for a one-time DeviceActivity schedule.
    private static func oneTimeEndComponents(for rule: Rule) -> DateComponents {
        // Builds the exact one-time interval if possible.
        guard let interval = oneTimeInterval(for: rule) else {
            // Falls back to time-only components if the interval is missing.
            return timeComponents(from: rule.endTime)
        }

        // Returns full date and time pieces for the end.
        return Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: interval.end)
    }

    // Finds the weekday number before the given weekday.
    private static func weekdayBefore(_ weekday: Int) -> Int {
        // Checks whether the current weekday is Sunday.
        if weekday == 1 {
            // Returns Saturday as the day before Sunday.
            return 7
        }

        // Returns the previous weekday number.
        return weekday - 1
    }

    // Converts a Date into minutes after midnight.
    private static func minutesSinceMidnight(_ date: Date) -> Int {
        // Pulls the hour and minute out of the Date.
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)

        // Converts the hour into minutes.
        let hourMinutes = (components.hour ?? 0) * 60

        // Reads the minute value, or zero if it is missing.
        let minuteValue = components.minute ?? 0

        // Returns the total minutes after midnight.
        return hourMinutes + minuteValue
    }

    // Converts a Date into hour and minute components.
    private static func timeComponents(from date: Date) -> DateComponents {
        // Pulls the hour and minute out of the Date.
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)

        // Builds the smaller DateComponents value DeviceActivity expects.
        return DateComponents(hour: components.hour, minute: components.minute)
    }

    // Creates a repeating all-day schedule for daily usage limits.
    private static func dailyUsageLimitSchedule() -> DeviceActivitySchedule {
        DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
    }
}

// Adds Focus Lock helpers to Apple's DeviceActivityName type.
extension DeviceActivityName {
    // Stores the prefix used for every Focus Lock activity name.
    private static let focusLockRulePrefix = "focus-lock-rule-"

    // Builds a DeviceActivityName from a rule id.
    init(ruleID: UUID) {
        // Combines our prefix with the rule's unique id.
        self.init(Self.focusLockRulePrefix + ruleID.uuidString)
    }

    // Checks whether this activity name belongs to Focus Lock.
    var isFocusLockRuleActivity: Bool {
        // Returns true when the raw string starts with our prefix.
        rawValue.hasPrefix(Self.focusLockRulePrefix)
    }

    // Pulls the original rule id back out of the activity name.
    var focusLockRuleID: UUID? {
        // Stops if this is not one of our Focus Lock activity names.
        guard isFocusLockRuleActivity else {
            // Returns nothing because this name does not belong to a rule.
            return nil
        }

        // Removes the Focus Lock prefix and leaves only the UUID text.
        let idString = rawValue.replacingOccurrences(of: Self.focusLockRulePrefix, with: "")

        // Converts the UUID text back into a UUID value.
        return UUID(uuidString: idString)
    }
}

// Adds Focus Lock helpers to Apple's DeviceActivityEvent.Name type.
extension DeviceActivityEvent.Name {
    // Stores the prefix used for every Focus Lock usage-limit threshold event.
    private static let focusLockUsageLimitPrefix = "focus-lock-usage-limit-"

    // Builds a DeviceActivityEvent.Name from a rule id.
    init(usageLimitRuleID: UUID) {
        self.init(Self.focusLockUsageLimitPrefix + usageLimitRuleID.uuidString)
    }

    // Checks whether this event belongs to a Focus Lock usage-limit rule.
    var isFocusLockUsageLimitEvent: Bool {
        rawValue.hasPrefix(Self.focusLockUsageLimitPrefix)
    }

    // Pulls the original rule id back out of the event name.
    var focusLockUsageLimitRuleID: UUID? {
        guard isFocusLockUsageLimitEvent else {
            return nil
        }

        let idString = rawValue.replacingOccurrences(of: Self.focusLockUsageLimitPrefix, with: "")
        return UUID(uuidString: idString)
    }
}
