//
//  AppState.swift
//  focus-lock
//
//  Created by Shabarish  on 1/17/26.
//


import SwiftUI
import Combine
import FamilyControls

@MainActor
final class AppState: ObservableObject {
    
    // MARK: - Rules (data for the Rules screen)
    @Published var rules: [Rule] = [
//        Rule(title: "No tiktok during work", isEnabled: true),
//        Rule(title: "Limit Instagram to 10min/day", isEnabled: false)
    ] {
        // Runs right after something changes in rules
        didSet {
            persistAndSyncRules()
        }
    }
    
    // MARK: - Actions
    
    // Encapsulation: The View shouldn't know HOW to append a rule, just that it WANTS to add one.
    // We now include start and end times in the creation.
    func addRule(title: String,
                 start: Date,
                 end: Date,
                 activitySelection: FamilyActivitySelection,
                 simulatedCommitmentCents: Int? = nil,
                 // Stores the selected repeat days for this new rule.
                 repeatWeekdays: Set<Int> = Rule.allWeekdays,
                 // Stores the date for this rule when it is a one-time rule.
                 oneTimeDate: Date? = nil){
        // Clears the one-time date for recurring rules because recurring rules do not need one exact date.
        let savedOneTimeDate = repeatWeekdays.isEmpty ? oneTimeDate : nil
        
        let newRule = Rule(
            title: title,
            isEnabled: true,
            startTime: start,
            endTime: end,
            activitySelection: activitySelection,
            simulatedCommitmentCents: normalizedSimulatedCommitment(simulatedCommitmentCents),
            // Saves the repeat days chosen by the user.
            repeatWeekdays: repeatWeekdays,
            // Saves the one-time date only when this is a one-time rule.
            oneTimeDate: savedOneTimeDate
        )
        rules.append(newRule)
        // Note: saving, schedule registration, and shield refresh happen automatically
        // because of 'didSet' on the 'rules' variable.
    }

    // Creates a daily usage-limit rule.
    //
    // Example:
    // "Allow 30 minutes of Instagram today, then block it until tomorrow."
    func addUsageLimitRule(title: String,
                           usageLimitMinutes: Int,
                           activitySelection: FamilyActivitySelection,
                           simulatedCommitmentCents: Int? = nil) {
        let newRule = Rule(
            title: title,
            isEnabled: true,
            ruleKind: .usageLimit,
            activitySelection: activitySelection,
            usageLimitMinutes: usageLimitMinutes,
            usageLimitReachedAt: nil,
            simulatedCommitmentCents: normalizedSimulatedCommitment(simulatedCommitmentCents)
        )

        rules.append(newRule)
    }

    // Starts an immediate one-time focus session from the Home screen.
    //
    // This intentionally reuses the existing scheduled rule model instead of adding
    // a separate session type. That means the same persistence, DeviceActivity
    // registration, immediate shield sync, and completed one-time cleanup all apply.
    func startQuickFocusSession(durationMinutes: Int,
                                activitySelection: FamilyActivitySelection,
                                simulatedCommitmentCents: Int? = nil,
                                now: Date = Date()) {
        guard durationMinutes >= FocusLockSchedule.minimumMonitorDurationMinutes else {
            return
        }

        guard let endTime = Calendar.current.date(byAdding: .minute, value: durationMinutes, to: now) else {
            return
        }

        let quickFocusRule = Rule(
            title: "Quick Focus",
            isEnabled: true,
            ruleKind: .scheduled,
            startTime: now,
            endTime: endTime,
            activitySelection: activitySelection,
            simulatedCommitmentCents: normalizedSimulatedCommitment(simulatedCommitmentCents),
            repeatWeekdays: [],
            oneTimeDate: now
        )

        rules.append(quickFocusRule)
    }
    
    func toggleRule(id: UUID) {
        guard let index = rules.firstIndex(where: { $0.id == id }) else {
            return
        }

        // Flips the rule between enabled and disabled.
        // The rules array saves automatically because of didSet.
        rules[index].isEnabled.toggle()

        // didSet rebuilds schedules and shields after the rule changes.
    }
    
    // Sets initial state of rules.
    //
    // init runs when AppState is first created.
    //
    // This is important because saved rules should still matter after the app restarts.
    init () {
        // During DeviceActivity debugging, dump the shared diagnostic log whenever
        // the app starts. This lets us see extension breadcrumbs after reopening the app.
        FocusLockDiagnostics.dumpLogToConsole()

        // Load previously saved rules from the shared App Group store.
        rules = loadRules()

        // Tell iOS about all enabled schedules again.
        //
        // This is defensive: if the app restarts, we make sure DeviceActivityCenter
        // still has the latest schedule registrations.
        DeviceActivityScheduleManager.shared.syncSchedules(for: rules)

        // Apply the correct shield state right now while the app is open.
        //
        // Example:
        // If you open the app during an active rule window, this makes sure shields match.
        ScreenTimeShieldManager.shared.syncShields(for: rules)
    }
    
    // Writes rules into shared App Group storage so the DeviceActivity extension can read them.
    private func saveRules(){
        FocusLockRuleStore.saveRules(rules)
    }
    
    
    // Loads rules from the file path (Only runs at init)
    private func loadRules() -> [Rule] {
        // Reads all saved rules from App Group storage.
        let savedRules = FocusLockRuleStore.loadRules()
        
        // Removes one-time rules that have already completed.
        let activeRules = savedRules.filter { !FocusLockSchedule.isCompletedOneTimeRule($0) }

        // Clears usage-limit reached state from previous days.
        let cleanedRules = FocusLockSchedule.clearingExpiredUsageLimitState(from: activeRules)
        
        // Checks whether any completed one-time rules were removed.
        let didCleanUsageLimitState = zip(activeRules, cleanedRules).contains { oldRule, newRule in
            oldRule.usageLimitReachedAt != newRule.usageLimitReachedAt
        }

        if activeRules.count != savedRules.count || didCleanUsageLimitState {
            // Saves the cleaned rule list back to App Group storage.
            FocusLockRuleStore.saveRules(cleanedRules)
        }
        
        // Gives callers the cleaned list of rules.
        return cleanedRules
    }
    
    func deleteRule(id:UUID){
        rules.removeAll(){
            $0.id == id
        }

        // didSet re-applies schedules and shields using only the rules that still exist.
    }
    
    // Reloads rules from shared App Group storage.
    func refreshRulesFromStorage() {
        // Reads the latest saved rules, including changes made by the DeviceActivity extension.
        rules = loadRules()
    }
    
    func editRule(id: UUID,
                  title: String,
                  start: Date,
                  end: Date,
                  activitySelection: FamilyActivitySelection,
                  simulatedCommitmentCents: Int? = nil,
                  // Stores the updated repeat days for this rule.
                  repeatWeekdays: Set<Int> = Rule.allWeekdays,
                  // Stores the updated date when this rule is one-time.
                  oneTimeDate: Date? = nil
              ){
        // Finds the position of the rule in the rules array whose id matches the id passed into this function.
        guard let index = rules.firstIndex(where: {$0.id == id}) else{
            return
        }
        
        // Clears the one-time date for recurring rules because recurring rules do not need one exact date.
        let savedOneTimeDate = repeatWeekdays.isEmpty ? oneTimeDate : nil
        
        // Replace the old title with the new title from the edit form.
            rules[index].title = title

            // Make sure this rule uses scheduled time-window behavior.
            rules[index].ruleKind = .scheduled

            // Replace the old start time with the new start time from the edit form.
            rules[index].startTime = start

            // Replace the old end time with the new end time from the edit form.
            rules[index].endTime = end

            // Replace the old Screen Time app/category selection with the new selection from the edit form.
            rules[index].activitySelection = activitySelection

            // Save the optional simulated commitment selected in the edit form.
            rules[index].simulatedCommitmentCents = normalizedSimulatedCommitment(simulatedCommitmentCents)
        
            // Replace the old repeat days with the new repeat days from the edit form.
            rules[index].repeatWeekdays = repeatWeekdays
        
            // Replace the old one-time date with the new one-time date from the edit form.
            rules[index].oneTimeDate = savedOneTimeDate

            // Scheduled rules do not use daily usage-limit state.
            rules[index].usageLimitMinutes = nil
            rules[index].usageLimitReachedAt = nil

            // Because rules is @Published and has didSet, changing this rule automatically saves and syncs it.
        
    }

    // Updates an existing daily usage-limit rule.
    func editUsageLimitRule(id: UUID,
                            title: String,
                            usageLimitMinutes: Int,
                            activitySelection: FamilyActivitySelection,
                            simulatedCommitmentCents: Int? = nil) {
        guard let index = rules.firstIndex(where: { $0.id == id }) else {
            return
        }

        rules[index].title = title
        rules[index].ruleKind = .usageLimit
        rules[index].activitySelection = activitySelection
        rules[index].usageLimitMinutes = usageLimitMinutes
        rules[index].simulatedCommitmentCents = normalizedSimulatedCommitment(simulatedCommitmentCents)

        // If the user changes the allowed time or selected apps, let the rule start fresh.
        rules[index].usageLimitReachedAt = nil
    }

    // Manually blocks a usage-limit rule for the rest of today.
    //
    // This is useful when the user knows they already used too much time before
    // Focus Lock started monitoring this rule.
    func blockUsageLimitRuleForToday(id: UUID) {
        guard let index = rules.firstIndex(where: { $0.id == id }),
              rules[index].ruleKind == .usageLimit else {
            return
        }

        rules[index].usageLimitReachedAt = Date()
    }

    // Treat zero and negative values as no commitment before writing a Rule.
    // The UI currently offers only known positive presets, but this keeps the
    // model safe if custom amounts are added later.
    private func normalizedSimulatedCommitment(_ cents: Int?) -> Int? {
        guard let cents, cents > 0 else {
            return nil
        }

        return cents
    }

    private func persistAndSyncRules() {
        // 1. Save the latest rules to shared storage.
        //
        // The DeviceActivity extension reads from this same storage later.
        saveRules()

        // 2. Register/update the iOS schedules for enabled rules.
        //
        // This is the piece that lets iOS wake us up while the app is closed.
        DeviceActivityScheduleManager.shared.syncSchedules(for: rules)

        // 3. Refresh shields immediately in case the rule should apply right now.
        //
        // This makes the app feel instant instead of waiting for the next schedule boundary.
        ScreenTimeShieldManager.shared.syncShields(for: rules)
    }
    
}
