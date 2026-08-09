//
//  RulesView.swift
//  
//
//  Created by Suraj Modur on 1/11/26.
//

import SwiftUI
import FamilyControls

struct RulesView: View {
    
    // New State to track if the sheet(rule add modal) is open
    @State private var showCreateSheet = false
    
    @State private var ruleBeingEdited: Rule?

    // Holds a destructive action while we ask the user whether they really want
    // to break an active simulated commitment.
    @State private var pendingCommitmentAction: PendingCommitmentAction?
    
    // Blocked screen shortcut temporarily hidden from the Rules page.
    // @State private var goToBlocked = false

    // The three rule actions that can weaken or end an active commitment.
    private struct PendingCommitmentAction: Identifiable {
        enum Kind: String {
            case disable
            case edit
            case delete
        }

        let rule: Rule
        let kind: Kind

        var id: String {
            "\(rule.id.uuidString)-\(kind.rawValue)"
        }
    }

    // Describes the user-facing state shown on each rule row.
    //
    // This is intentionally local to RulesView for now because the current task only changes
    // how the Rules screen looks. If Home and Rules later need the exact same status model,
    // this enum would be a good candidate to move into Shared/.
    private enum RuleDisplayStatus {
        case active
        case limitAvailable
        case scheduled
        case disabled
        case invalid(String)
        case completed

        // The short text shown inside the colored status pill on each rule card.
        var title: String {
            switch self {
            case .active:
                return "Active now"
            case .limitAvailable:
                return "Available today"
            case .scheduled:
                return "Scheduled"
            case .disabled:
                return "Disabled"
            case .invalid:
                return "Needs attention"
            case .completed:
                return "Completed"
            }
        }

        // The supporting sentence shown under the status pill.
        //
        // Invalid rules carry their own reason so the user knows what to fix.
        var detail: String {
            switch self {
            case .active:
                return "Blocking distractions right now"
            case .limitAvailable:
                return "Counting from when this rule was saved today"
            case .scheduled:
                return "Will turn on at the next scheduled time"
            case .disabled:
                return "Turn this rule on when you want it to run"
            case .invalid(let reason):
                return reason
            case .completed:
                return "This one-time rule has ended"
            }
        }

        // Chooses an SF Symbol that visually matches the status.
        var iconName: String {
            switch self {
            case .active:
                return "lock.shield.fill"
            case .limitAvailable:
                return "hourglass"
            case .scheduled:
                return "clock.fill"
            case .disabled:
                return "pause.circle.fill"
            case .invalid:
                return "exclamationmark.triangle.fill"
            case .completed:
                return "checkmark.seal.fill"
            }
        }

        // Main status color used by the badge and helper text.
        var tint: Color {
            switch self {
            case .active:
                return .green
            case .limitAvailable:
                return .blue
            case .scheduled:
                return .orange
            case .disabled:
                return .secondary
            case .invalid:
                return .red
            case .completed:
                return .secondary
            }
        }

        // Border color for the whole rule card.
        //
        // Active and scheduled rules get stronger borders because those are the states
        // the user is most likely checking at a glance.
        var borderColor: Color {
            switch self {
            case .active:
                return .green
            case .limitAvailable:
                return .blue
            case .scheduled:
                return .orange
            case .invalid:
                return .red
            default:
                return Color(.separator)
            }
        }

        // Optional glow around the whole rule card.
        //
        // Green means the rule is protecting the user now.
        // Orange means the rule is scheduled for a future window.
        var glowColor: Color? {
            switch self {
            case .active:
                return .green
            case .limitAvailable:
                return .blue
            case .scheduled:
                return .orange
            default:
                return nil
            }
        }

        // Controls where the row appears in the Rules list.
        //
        // Active rules are most urgent, so they go first.
        // Scheduled rules are useful but less urgent, so they go last.
        // The middle group keeps disabled, invalid, and completed rules visible without
        // pushing active protection out of the user's first view.
        var sortPriority: Int {
            switch self {
            case .active:
                return 0
            case .invalid, .disabled, .completed:
                return 1
            case .limitAvailable, .scheduled:
                return 2
            }
        }
    }
    
    // Builds the saved selection text for one rule in the rules list.
    private func selectedActivitySummary(for rule: Rule) -> String {
        // Counts directly selected individual apps.
        let appCount = rule.activitySelection.applicationTokens.count

        // Counts selected app categories, including category "Select All".
        let categoryCount = rule.activitySelection.categoryTokens.count

        // Counts selected websites if the user selects web domains later.
        let webDomainCount = rule.activitySelection.webDomainTokens.count

        // Stores each non-empty piece of the summary text.
        var parts: [String] = []

        // Adds an app summary when individual apps are selected.
        if appCount > 0 {
            parts.append("\(appCount) \(appCount == 1 ? "app" : "apps")")
        }

        // Adds a category summary when categories are selected.
        if categoryCount > 0 {
            parts.append("\(categoryCount) \(categoryCount == 1 ? "category" : "categories")")
        }

        // Adds a website summary when web domains are selected.
        if webDomainCount > 0 {
            parts.append("\(webDomainCount) \(webDomainCount == 1 ? "website" : "websites")")
        }

        // Shows zero selected when nothing has been picked yet.
        if parts.isEmpty {
            return "None Selected"
        }

        // Joins the non-empty pieces and adds the selected label at the end.
        return parts.joined(separator: ", ") + " selected"
    }
    
    @EnvironmentObject var appState: AppState
    @EnvironmentObject private var familyControlsManager: FamilyControlsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 50) {
            Text("Rules")
                .font(.title)
                .frame(maxWidth: .infinity, alignment: .center)
            
            if !familyControlsManager.hasScreenTimePermission {
                ScreenTimePermissionNotice()
            }
            
            FocusCompactButton(title: "Create Rule"){
                // flipping this to true.
                // the .sheet modifier below watches this switch
                showCreateSheet = true
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            // when showCreateSheet becomes true, it presents the view
            .sheet(isPresented: $showCreateSheet){
                CreateRuleView()
            }
            .sheet(item: $ruleBeingEdited){ rule in
                EditRuleView(rule:rule)
            }
            
            
            // Rebuilds this part of the screen every second.
            //
            // Rule status can change just because time passes, so this lets a scheduled
            // rule turn green soon after its start time without reopening the screen.
            TimelineView(.periodic(from: Date(), by: 1)) { timeline in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment:.leading, spacing: 16) {
                        if appState.rules.isEmpty {
                            emptyRulesState
                        } else {
                            // Shows rules in status order instead of raw saved order.
                            //
                            // Active rules move to the top. Scheduled rules move to the bottom.
                            // When a recurring active rule ends, the next timeline tick recalculates
                            // its status as scheduled and moves it down.
                            ForEach(sortedRules(now: timeline.date)){ rule in
                            // Calculate the status once per row so the badge, text, border,
                            // glow, and sorting all describe the same state.
                            let status = ruleDisplayStatus(for: rule, now: timeline.date)

                            VStack(alignment: .leading, spacing: 12){
                                HStack(alignment: .top, spacing: 12){
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(rule.title)
                                            .font(.title2)
                                            .bold()

                                        // Shows the compact "Active now" / "Scheduled" / etc. pill.
                                        statusBadge(status)
                                    }

                                    Spacer()
                                    
                                    Button {
                                        requestToggle(for: rule, now: timeline.date)
                                    } label: {
                                        Image(systemName: rule.isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundStyle(rule.isEnabled ? .green : .red)
                                            .font(.title2)
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel(rule.isEnabled ? "Disable rule" : "Enable rule")
                                    
                                    //Editing Rule Button
                                    Button(action: {
                                        requestEdit(for: rule, now: timeline.date)
                                    }) {
                                        Image(systemName: "pencil")
                                            .foregroundStyle(.blue)
                                            .font(.title2)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                    
                                    
                                    Button(action:{
                                        requestDelete(for: rule, now: timeline.date)
                                    }){
                                        Image(systemName: "trash")
                                            .foregroundStyle(.red)
                                            .font(.title2)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }

                                Text(status.detail)
                                    .font(.caption)
                                    .foregroundStyle(status.tint)
                                
                                Text(primaryScheduleText(for: rule, now: timeline.date))
                                    .font(.subheadline)
                                    .foregroundStyle(.gray)
                                
                                // Shows whether this rule is daily, one-time, or repeats on selected weekdays.
                                Text(FocusLockSchedule.recurrenceSummary(for: rule))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                
                                // Shows how many picker items this rule contains.
                                Text(selectedActivitySummary(for: rule))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if let commitmentCents = rule.simulatedCommitmentCents,
                                   commitmentCents > 0 {
                                    Label(
                                        "\(SimulatedCommitment.formatted(cents: commitmentCents)) simulated commitment",
                                        systemImage: "banknote"
                                    )
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.orange)
                                }

                                if shouldShowBlockForTodayButton(for: rule, now: timeline.date) {
                                    Button {
                                        appState.blockUsageLimitRuleForToday(id: rule.id)
                                    } label: {
                                        Label("Block for Today", systemImage: "lock.fill")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            // Draws the status-colored outline around the rule card.
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(status.borderColor.opacity(0.85), lineWidth: 1.5)
                            )
                            // Adds the green/orange glow for active and scheduled rules.
                            .shadow(color: status.glowColor?.opacity(0.32) ?? .clear, radius: 12, x: 0, y: 0)
                            .shadow(color: status.glowColor?.opacity(0.18) ?? .clear, radius: 22, x: 0, y: 0)
                            }
                        }
                    }
                    // Animates row movement when a status change changes the sorted order.
                    .animation(.easeInOut(duration: 0.25), value: sortedRuleIDs(now: timeline.date))
                }
                // While the user is already on this screen, remove completed one-time rules
                // instead of waiting for an app relaunch or the DeviceActivity extension callback.
                .onChange(of: timeline.date) { now in
                    removeCompletedOneTimeRulesIfNeeded(now: now)
                }
            }
            
            /*
            FocusButton(title: "Blocked Screen") {
                goToBlocked = true
            }
            */
        }
        .padding(20)
        .alert(item: $pendingCommitmentAction) { action in
            Alert(
                title: Text(commitmentAlertTitle(for: action)),
                message: Text(commitmentAlertMessage(for: action)),
                primaryButton: .destructive(Text(commitmentConfirmationTitle(for: action))) {
                    performCommitmentAction(action)
                },
                secondaryButton: .cancel()
            )
        }
        /*
        .navigationDestination(isPresented: $goToBlocked) {
            BlockedView()
        }
        */
    }

    private var emptyRulesState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "shield")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("No rules yet")
                .font(.title3.bold())

            Text("Create a schedule, daily limit, or quick focus session to start blocking distracting apps.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                showCreateSheet = true
            } label: {
                Label("Create Rule", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // Active commitments get an explicit confirmation before a control can
    // stop or weaken their current blocking window. Inactive and unstaked rules
    // keep the existing one-tap behavior.
    private func requestToggle(for rule: Rule, now: Date) {
        guard rule.isEnabled, activeCommitmentCents(for: rule, now: now) != nil else {
            appState.toggleRule(id: rule.id)
            return
        }

        pendingCommitmentAction = PendingCommitmentAction(rule: rule, kind: .disable)
    }

    private func requestEdit(for rule: Rule, now: Date) {
        guard activeCommitmentCents(for: rule, now: now) != nil else {
            ruleBeingEdited = rule
            return
        }

        pendingCommitmentAction = PendingCommitmentAction(rule: rule, kind: .edit)
    }

    private func requestDelete(for rule: Rule, now: Date) {
        guard activeCommitmentCents(for: rule, now: now) != nil else {
            appState.deleteRule(id: rule.id)
            return
        }

        pendingCommitmentAction = PendingCommitmentAction(rule: rule, kind: .delete)
    }

    // A commitment is guarded only while its rule is genuinely monitorable and
    // blocking. This avoids warning on disabled, invalid, upcoming, or completed rules.
    private func activeCommitmentCents(for rule: Rule, now: Date) -> Int? {
        guard let cents = rule.simulatedCommitmentCents,
              cents > 0,
              FocusLockSchedule.isMonitorable(rule, now: now),
              FocusLockSchedule.isActive(rule, now: now) else {
            return nil
        }

        return cents
    }

    private func commitmentAlertTitle(for action: PendingCommitmentAction) -> String {
        let cents = action.rule.simulatedCommitmentCents ?? 0
        return "Break \(SimulatedCommitment.formatted(cents: cents)) simulated commitment?"
    }

    private func commitmentAlertMessage(for action: PendingCommitmentAction) -> String {
        switch action.kind {
        case .disable:
            return "This rule will stop blocking now. Focus Lock will not charge you."
        case .edit:
            return "Editing requires stopping this active rule first. The rule will be disabled before the editor opens. Focus Lock will not charge you."
        case .delete:
            return "This active rule will be deleted and stop blocking now. Focus Lock will not charge you."
        }
    }

    private func commitmentConfirmationTitle(for action: PendingCommitmentAction) -> String {
        switch action.kind {
        case .disable:
            return "Disable Rule"
        case .edit:
            return "Break & Edit"
        case .delete:
            return "Delete Rule"
        }
    }

    private func performCommitmentAction(_ action: PendingCommitmentAction) {
        switch action.kind {
        case .disable:
            guard appState.rules.first(where: { $0.id == action.rule.id })?.isEnabled == true else {
                return
            }
            appState.toggleRule(id: action.rule.id)

        case .edit:
            // Disable first so opening the editor cannot silently change an active
            // commitment. The edited rule remains disabled until the user reenables it.
            if appState.rules.first(where: { $0.id == action.rule.id })?.isEnabled == true {
                appState.toggleRule(id: action.rule.id)
            }
            ruleBeingEdited = appState.rules.first(where: { $0.id == action.rule.id })

        case .delete:
            appState.deleteRule(id: action.rule.id)
        }
    }

    // Builds the compact colored status pill shown under the rule title.
    private func statusBadge(_ status: RuleDisplayStatus) -> some View {
        HStack(spacing: 6) {
            Image(systemName: status.iconName)
                .font(.caption.weight(.semibold))

            Text(status.title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(status.tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(status.tint.opacity(0.12))
        .clipShape(Capsule())
    }

    // Converts one saved Rule into the status the user should see right now.
    //
    // Order matters:
    // - disabled wins first because disabled rules should never appear active
    // - invalid comes before active/scheduled because an invalid rule cannot run
    // - active comes before scheduled because the rule is protecting right now
    // - scheduled means it has a future start date
    // - completed is the fallback, mostly for ended one-time rules before cleanup runs
    private func ruleDisplayStatus(for rule: Rule, now: Date) -> RuleDisplayStatus {
        if !rule.isEnabled {
            return .disabled
        }

        if let invalidReason = invalidReason(for: rule) {
            return .invalid(invalidReason)
        }

        if FocusLockSchedule.isActive(rule, now: now) {
            return .active
        }

        if rule.ruleKind == .usageLimit {
            return .limitAvailable
        }

        if nextStartDate(for: rule, after: now) != nil {
            return .scheduled
        }

        return .completed
    }

    // Returns a user-readable reason when a rule cannot actually run.
    private func invalidReason(for rule: Rule) -> String? {
        if !FocusLockSchedule.hasSelectedActivity(rule.activitySelection) {
            return "Choose at least one app, category, or website"
        }

        if FocusLockSchedule.durationMinutes(for: rule) < FocusLockSchedule.minimumMonitorDurationMinutes {
            if rule.ruleKind == .usageLimit {
                return "Daily limit must be at least \(FocusLockSchedule.minimumMonitorDurationMinutes) minutes"
            }

            return "Rule must be at least \(FocusLockSchedule.minimumMonitorDurationMinutes) minutes long"
        }

        if rule.isOneTime && rule.oneTimeDate == nil {
            return "Choose a date for this one-time rule"
        }

        return nil
    }

    // Builds the main time/limit text for a rule card.
    private func primaryScheduleText(for rule: Rule, now: Date) -> String {
        if rule.ruleKind == .usageLimit {
            let limitMinutes = rule.usageLimitMinutes ?? 0

            if FocusLockSchedule.hasReachedUsageLimitToday(rule, now: now) {
                return "\(limitMinutes) min limit reached. Blocked until tomorrow."
            }

            return "\(limitMinutes) min limit. Counts from now today, then resets daily."
        }

        return "\(rule.startTime.formatted(date: .omitted, time: .shortened)) - \(rule.endTime.formatted(date: .omitted, time: .shortened))"
    }

    // Shows the manual block action only when a usage-limit rule is ready but not blocked yet.
    private func shouldShowBlockForTodayButton(for rule: Rule, now: Date) -> Bool {
        rule.ruleKind == .usageLimit &&
        rule.isEnabled &&
        invalidReason(for: rule) == nil &&
        !FocusLockSchedule.hasReachedUsageLimitToday(rule, now: now)
    }

    // Finds the next future start time for a rule.
    //
    // One-time rules only have one possible start.
    // Recurring rules scan the next week because any weekly recurrence should appear
    // again within seven days if it has selected weekdays.
    private func nextStartDate(for rule: Rule, after now: Date) -> Date? {
        if rule.isOneTime {
            guard let oneTimeDate = rule.oneTimeDate else {
                return nil
            }

            let start = date(on: oneTimeDate, matchingTimeFrom: rule.startTime)
            return start > now ? start : nil
        }

        for dayOffset in 0...7 {
            guard let candidateDay = Calendar.current.date(byAdding: .day, value: dayOffset, to: now) else {
                continue
            }

            let weekday = Calendar.current.component(.weekday, from: candidateDay)
            guard rule.repeatWeekdays.contains(weekday) else {
                continue
            }

            let start = date(on: candidateDay, matchingTimeFrom: rule.startTime)
            if start > now {
                return start
            }
        }

        return nil
    }

    // Sorts the rule cards by their current status while preserving saved order inside
    // each status group.
    private func sortedRules(now: Date) -> [Rule] {
        appState.rules
            .enumerated()
            .sorted { left, right in
                let leftPriority = ruleDisplayStatus(for: left.element, now: now).sortPriority
                let rightPriority = ruleDisplayStatus(for: right.element, now: now).sortPriority

                if leftPriority != rightPriority {
                    return leftPriority < rightPriority
                }

                return left.offset < right.offset
            }
            .map(\.element)
    }

    // Gives SwiftUI a stable animation value that changes only when the visible order changes.
    private func sortedRuleIDs(now: Date) -> [UUID] {
        sortedRules(now: now).map(\.id)
    }

    // Deletes completed one-time rules while the Rules screen is open.
    //
    // AppState also cleans these up on launch, and the DeviceActivity extension cleans them
    // up after interval end. This helper keeps the on-screen list from showing a finished
    // one-time rule until the user leaves and reopens the app.
    private func removeCompletedOneTimeRulesIfNeeded(now: Date) {
        let completedRuleIDs = appState.rules
            .filter { FocusLockSchedule.isCompletedOneTimeRule($0, now: now) }
            .map(\.id)

        guard !completedRuleIDs.isEmpty else {
            return
        }

        for ruleID in completedRuleIDs {
            appState.deleteRule(id: ruleID)
        }
    }

    // Combines a calendar day with the hour/minute from a stored rule time.
    //
    // Rules store startTime/endTime as Date values, but recurring rules only care about
    // the clock time. This helper lets the view ask, "what would this rule's start time
    // be on this candidate day?"
    private func date(on day: Date, matchingTimeFrom time: Date) -> Date {
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: time)

        return Calendar.current.date(
            bySettingHour: timeComponents.hour ?? 0,
            minute: timeComponents.minute ?? 0,
            second: 0,
            of: day
        ) ?? day
    }
    
}

#Preview {
    NavigationStack {
            RulesView()
                .environmentObject(AppState())
        }
}
