//
//  HomeView.swift
//
//
//  Created by Suraj Modur on 1/11/26.
//

import SwiftUI

// HomeView is the first tab in the app.
//
// Its job is to answer the user's most important questions quickly:
// - Am I being protected right now?
// - If not, when is the next block?
// - How many rules are active/enabled/scheduled today?
// - Where do I go to create a new rule?
struct HomeView: View {
    // AppState is the shared source of truth for saved rules.
    //
    // focus_lockApp creates AppState once and injects it into the view tree.
    // HomeView reads it here so the dashboard can be based on real rules instead of fake stats.
    @EnvironmentObject var appState: AppState

    // Controls whether the CreateRuleView sheet is open.
    //
    // When this becomes true, SwiftUI presents the sheet attached below.
    @State private var showCreateSheet = false

    var body: some View {
        // TimelineView refreshes the dashboard every 60 seconds.
        //
        // We need this because a rule can become active or inactive just because time passed,
        // even if the user did not tap anything.
        TimelineView(.periodic(from: Date(), by: 60)) { timeline in
            // The Home screen can grow taller than the phone, especially once we add real insights.
            // ScrollView keeps everything reachable on smaller devices.
            ScrollView {
                // One vertical stack owns the dashboard layout.
                //
                // Each section below is split into a helper property/function so body stays readable.
                VStack(alignment: .leading, spacing: 20) {
                    // Date + "Focus dashboard" title.
                    header

                    // The big top status card: active now, next scheduled, or no active block.
                    protectionStatusSection(now: timeline.date)

                    // Main action button for creating a new blocking rule.
                    primaryAction

                    // Small stat tiles based on saved rules.
                    todaySummarySection(now: timeline.date)

                    // Shows the next rule that will start in the future, if one exists.
                    nextRuleSection(now: timeline.date)

                    // Placeholder for the future DeviceActivityReport work.
                    habitsSection
                }
                .padding(20)
            }
            // systemGroupedBackground is the same family of color Apple uses for grouped screens.
            // It adapts automatically between light and dark mode.
            .background(Color(.systemGroupedBackground))
            // This is the compact navigation title shown in the nav bar.
            .navigationTitle("Focus Lock")
            .navigationBarTitleDisplayMode(.inline)
            // Presents the existing CreateRuleView when the primary button sets showCreateSheet = true.
            .sheet(isPresented: $showCreateSheet) {
                CreateRuleView()
            }
        }
    }

    // MARK: - Top Header

    // The header is intentionally simple:
    // - date, so the dashboard feels current
    // - screen title, so the user understands this is the operational home surface
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            // This renders like "Thursday, May 14".
            //
            // It uses Date() directly because it is just decorative/current-day context.
            // The rule calculations use TimelineView's timeline.date instead.
            Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Large page title. Kept outside a card so Home does not feel like a landing page.
            Text("Focus dashboard")
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Protection Status

    // Builds the large status card near the top of Home.
    //
    // The card has three possible meanings:
    // 1. Protected now: at least one rule is active at this moment.
    // 2. Next block is scheduled: no active rule, but one starts later.
    // 3. No active block: no active or upcoming monitorable rule.
    private func protectionStatusSection(now: Date) -> some View {
        // Find rules that should be blocking right now.
        let activeRules = activeRules(now: now)

        // Find the soonest future rule start.
        let nextRule = nextUpcomingRule(now: now)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                // Use a filled lock shield when protection is active.
                // Use a plain shield when nothing is currently blocking.
                Image(systemName: activeRules.isEmpty ? "shield" : "lock.shield.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(activeRules.isEmpty ? Color.secondary : Color.green)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 6) {
                    // Short headline: "Protected now", "Next block is scheduled", or "No active block".
                    Text(statusTitle(activeRules: activeRules, nextRule: nextRule))
                        .font(.title2.bold())

                    // Supporting sentence with the active/next rule name when possible.
                    Text(statusMessage(activeRules: activeRules, nextRule: nextRule))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        // Allows the text to wrap vertically instead of being squeezed or clipped.
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Primary Action

    // The main Home action.
    //
    // MVP 1 should make the user's next step obvious, and right now that step is creating a rule.
    private var primaryAction: some View {
        Button {
            // Tells SwiftUI to present CreateRuleView as a sheet.
            showCreateSheet = true
        } label: {
            // Label combines an SF Symbol with text.
            // This is more scannable than text alone.
            Label("Create Rule", systemImage: "plus.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    // MARK: - Today Summary

    // Builds the small dashboard tiles under "Today".
    //
    // These are not Screen Time usage stats yet.
    // They are rule stats that we can calculate honestly from local app state today.
    private func todaySummarySection(now: Date) -> some View {
        // How many rules are actively blocking right now.
        let activeCount = activeRules(now: now).count

        // How many saved rules are turned on.
        let enabledCount = appState.rules.filter(\.isEnabled).count

        // How many monitorable rules have a schedule that includes today.
        let scheduledTodayCount = appState.rules.filter { isScheduledToday($0, now: now) }.count

        return VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Today")

            // Two flexible columns makes the tiles fit a normal phone width.
            // The third tile wraps to the next row, as shown in the screenshot.
            LazyVGrid(columns: summaryColumns, spacing: 12) {
                summaryTile(
                    title: "Active now",
                    value: "\(activeCount)",
                    systemImage: "bolt.fill",
                    tint: .green
                )

                summaryTile(
                    title: "Enabled rules",
                    value: "\(enabledCount)",
                    systemImage: "checkmark.circle.fill",
                    tint: .blue
                )

                summaryTile(
                    title: "Scheduled today",
                    value: "\(scheduledTodayCount)",
                    systemImage: "calendar",
                    tint: .orange
                )
            }
        }
    }

    // MARK: - Next Rule

    // Shows the next future rule start.
    //
    // This helps the user trust that Focus Lock knows what is coming next.
    private func nextRuleSection(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Next")

            if let nextRule = nextUpcomingRule(now: now) {
                // A next rule exists, so show its name, start time, time window, and recurrence.
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        // User-entered rule title.
                        Text(nextRule.rule.title)
                            .font(.headline)

                        Spacer()

                        // The exact future start time we calculated.
                        Text(nextRule.start, style: .time)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    // The rule's saved daily time window.
                    //
                    // For one-time rules, this is still useful because it shows the chosen start/end times.
                    Text("\(nextRule.rule.startTime, style: .time) - \(nextRule.rule.endTime, style: .time)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Examples: Daily, Tue/Thu, One time: May 14.
                    Text(FocusLockSchedule.recurrenceSummary(for: nextRule.rule))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                // No future block exists.
                //
                // The message changes depending on whether the user has no rules at all
                // or has rules that simply are not monitorable/upcoming.
                emptyState(
                    title: "No upcoming blocks",
                    message: appState.rules.isEmpty ? "Create your first rule to schedule protection." : "Your enabled rules do not have another block coming up."
                )
            }
        }
    }

    // MARK: - Habits Placeholder

    // Placeholder for #41.
    //
    // We intentionally do not fake Screen Time data here.
    // When DeviceActivityReport is implemented, this section can become a real habits preview.
    private var habitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Habits")

            emptyState(
                title: "Insights coming soon",
                message: "Device activity reports will show screen habits here once the habits screen is built."
            )
        }
    }

    // MARK: - Reusable UI Helpers

    // Defines the dashboard tile grid.
    //
    // Each GridItem(.flexible()) takes half the available width.
    private var summaryColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }

    // Small helper for section headings like "Today", "Next", and "Habits".
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
    }

    // Builds one stat tile in the Today section.
    //
    // Parameters:
    // - title: small label under the number
    // - value: big number text
    // - systemImage: SF Symbol name
    // - tint: color for the icon
    private func summaryTile(title: String, value: String, systemImage: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Icon at top-left of the tile.
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)

            // Big count. monospacedDigit keeps numbers from jittering if they change.
            Text(value)
                .font(.title.bold())
                .monospacedDigit()

            // Human-readable label.
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                // Keep labels contained inside the tile on smaller screens.
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // Builds a quiet empty/informational card.
    //
    // Used for:
    // - no upcoming rule
    // - habits not implemented yet
    private func emptyState(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                // Allows longer messages to wrap naturally.
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Rule State Helpers

    // Returns rules that should be blocking right now.
    //
    // We require both:
    // - isMonitorable: enabled, has selected apps/categories/websites, valid duration, valid recurrence
    // - isActive: current time is inside that rule's blocking window
    private func activeRules(now: Date) -> [Rule] {
        appState.rules.filter { rule in
            FocusLockSchedule.isMonitorable(rule, now: now) && FocusLockSchedule.isActive(rule, now: now)
        }
    }

    // Chooses the short headline for the big status card.
    private func statusTitle(activeRules: [Rule], nextRule: UpcomingRule?) -> String {
        // Active blocks are the most important state, so they win first.
        if !activeRules.isEmpty {
            return "Protected now"
        }

        // If nothing is active but something will start later, show that.
        if nextRule != nil {
            return "Next block is scheduled"
        }

        // Otherwise, there is no active or upcoming protection.
        return "No active block"
    }

    // Chooses the supporting sentence under the status title.
    private func statusMessage(activeRules: [Rule], nextRule: UpcomingRule?) -> String {
        // One active rule: name it directly.
        if activeRules.count == 1, let activeRule = activeRules.first {
            return "\(activeRule.title) is blocking distractions right now."
        }

        // Multiple active rules: avoid listing every title in a crowded card.
        if activeRules.count > 1 {
            return "\(activeRules.count) rules are blocking distractions right now."
        }

        // No active rule, but an upcoming rule exists.
        if let nextRule {
            return "\(nextRule.rule.title) starts at \(nextRule.start.formatted(date: .omitted, time: .shortened))."
        }

        // No active/upcoming rule.
        return "Create a rule to protect your next focus window."
    }

    // Finds the soonest future rule start.
    //
    // This scans all monitorable rules, calculates each one's next future start,
    // then returns the earliest one.
    private func nextUpcomingRule(now: Date) -> UpcomingRule? {
        appState.rules
            // Ignore rules that cannot actually be scheduled or shield anything.
            .filter { FocusLockSchedule.isMonitorable($0, now: now) }
            .compactMap { rule -> UpcomingRule? in
                // Some rules may not have a future start.
                // Example: a one-time rule whose start already passed.
                guard let start = nextStartDate(for: rule, after: now) else {
                    return nil
                }

                // Pair the rule with the future start date so the UI can show both.
                return UpcomingRule(rule: rule, start: start)
            }
            // Pick the earliest start date.
            .min { $0.start < $1.start }
    }

    // Calculates the next future start date for one rule.
    //
    // Rules store startTime as a Date, but only the hour/minute matters for recurring rules.
    // One-time rules also store oneTimeDate, which gives us the exact calendar day.
    private func nextStartDate(for rule: Rule, after now: Date) -> Date? {
        // One-time rules happen once on one exact date.
        if rule.isOneTime {
            guard let oneTimeDate = rule.oneTimeDate else {
                return nil
            }

            // Combine the selected one-time date with the selected start time.
            let start = date(on: oneTimeDate, matchingTimeFrom: rule.startTime)

            // Only return it if it is still in the future.
            // If the one-time start already passed, Home should not call it "upcoming".
            return start > now ? start : nil
        }

        // Recurring rules repeat on selected weekdays.
        //
        // Look up to 7 days ahead because a weekly recurrence must repeat within a week
        // if it has at least one selected weekday.
        for dayOffset in 0...7 {
            // Candidate day = today, tomorrow, etc.
            guard let candidateDay = Calendar.current.date(byAdding: .day, value: dayOffset, to: now) else {
                continue
            }

            // Swift weekday numbers use Calendar's convention:
            // 1 = Sunday, 2 = Monday, ..., 7 = Saturday.
            let weekday = Calendar.current.component(.weekday, from: candidateDay)

            // Skip days this rule does not repeat on.
            guard rule.repeatWeekdays.contains(weekday) else {
                continue
            }

            // Combine this candidate day with the rule's saved start time.
            let start = date(on: candidateDay, matchingTimeFrom: rule.startTime)

            // Return the first candidate that starts in the future.
            if start > now {
                return start
            }
        }

        // No future start was found.
        return nil
    }

    // Returns whether this rule has a schedule that includes today.
    //
    // This powers the "Scheduled today" tile.
    private func isScheduledToday(_ rule: Rule, now: Date) -> Bool {
        // If iOS would not monitor this rule, we should not count it as scheduled.
        guard FocusLockSchedule.isMonitorable(rule, now: now) else {
            return false
        }

        // One-time rules count when their exact block interval overlaps today.
        //
        // This matters for overnight blocks. Example:
        // A one-time rule from Thursday 11:00 PM to Friday 1:00 AM
        // should still count as scheduled on Friday while that early-morning block exists.
        if rule.isOneTime {
            return oneTimeRuleOverlapsToday(rule, now: now)
        }

        // Recurring rules count when any part of their block window touches today.
        return recurringRuleOverlapsToday(rule, now: now)
    }

    // Checks whether a recurring rule has any blocking time on today's calendar date.
    private func recurringRuleOverlapsToday(_ rule: Rule, now: Date) -> Bool {
        // Converts the rule's daily times into simple minute counts.
        let startMinutes = minutesSinceMidnight(rule.startTime)
        let endMinutes = minutesSinceMidnight(rule.endTime)

        // Reads today's weekday number.
        let todayWeekday = Calendar.current.component(.weekday, from: now)

        // Same-day blocks only touch today when today is selected.
        if startMinutes < endMinutes {
            return rule.repeatWeekdays.contains(todayWeekday)
        }

        // Overnight blocks touch two calendar dates:
        // - the selected start day, late at night
        // - the following day, early in the morning
        if startMinutes > endMinutes {
            let previousWeekday = weekdayBefore(todayWeekday)
            let startsToday = rule.repeatWeekdays.contains(todayWeekday)
            let startedYesterdayAndContinuesToday = rule.repeatWeekdays.contains(previousWeekday)
            return startsToday || startedYesterdayAndContinuesToday
        }

        // Equal start/end times are invalid for monitoring, but keep this explicit.
        return false
    }

    // Checks whether a one-time rule's exact interval intersects today's calendar date.
    private func oneTimeRuleOverlapsToday(_ rule: Rule, now: Date) -> Bool {
        // Build the exact one-time start and end dates.
        guard let interval = oneTimeInterval(for: rule) else {
            return false
        }

        // Build today's midnight-to-midnight interval.
        let dayStart = Calendar.current.startOfDay(for: now)
        guard let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) else {
            return false
        }

        // Two intervals overlap when each one starts before the other one ends.
        return interval.start < dayEnd && interval.end > dayStart
    }

    // Builds the exact start/end dates for one one-time rule.
    private func oneTimeInterval(for rule: Rule) -> DateInterval? {
        // One-time rules need a selected calendar date.
        guard let oneTimeDate = rule.oneTimeDate else {
            return nil
        }

        // Put the saved start and end times onto that selected date.
        let start = date(on: oneTimeDate, matchingTimeFrom: rule.startTime)
        var end = date(on: oneTimeDate, matchingTimeFrom: rule.endTime)

        // If the end is not after the start, the block crosses midnight.
        if end <= start {
            guard let nextDayEnd = Calendar.current.date(byAdding: .day, value: 1, to: end) else {
                return nil
            }

            end = nextDayEnd
        }

        return DateInterval(start: start, end: end)
    }

    // Converts a Date's time into minutes after midnight.
    private func minutesSinceMidnight(_ date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        return hours * 60 + minutes
    }

    // Returns the weekday number immediately before the given weekday.
    private func weekdayBefore(_ weekday: Int) -> Int {
        weekday == 1 ? 7 : weekday - 1
    }

    // Combines a calendar day with the hour/minute from another Date.
    //
    // Example:
    // - day = May 14, 2026
    // - time = 11:00 PM
    // - result = May 14, 2026 at 11:00 PM
    private func date(on day: Date, matchingTimeFrom time: Date) -> Date {
        // Pull just the hour and minute from the rule's saved startTime.
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: time)

        // Set that hour/minute on the calendar day we are evaluating.
        return Calendar.current.date(
            bySettingHour: timeComponents.hour ?? 0,
            minute: timeComponents.minute ?? 0,
            second: 0,
            of: day
        ) ?? day
    }
}

// A tiny helper type used only by HomeView.
//
// It keeps a rule paired with the exact future start date we calculated for it.
private struct UpcomingRule {
    let rule: Rule
    let start: Date
}

// Preview support for Xcode.
#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(AppState())
    }
}
