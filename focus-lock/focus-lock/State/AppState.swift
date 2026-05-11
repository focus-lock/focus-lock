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
    func addRule(title: String, start: Date, end: Date, activitySelection: FamilyActivitySelection){
        let newRule = Rule(
            title: title,
            isEnabled: true,
            startTime: start,
            endTime: end,
            activitySelection: activitySelection
        )
        rules.append(newRule)
        // Note: saving, schedule registration, and shield refresh happen automatically
        // because of 'didSet' on the 'rules' variable.
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
        
        FocusLockRuleStore.loadRules()
    }
    
    func deleteRule(id:UUID){
        rules.removeAll(){
            $0.id == id
        }

        // didSet re-applies schedules and shields using only the rules that still exist.
    }
    
    func editRule(id: UUID,
                  title: String,
                  start: Date,
                  end: Date,
                  activitySelection: FamilyActivitySelection
              ){
        // Finds the position of the rule in the rules array whose id matches the id passed into this function.
        guard let index = rules.firstIndex(where: {$0.id == id}) else{
            return
        }
        
        // Replace the old title with the new title from the edit form.
            rules[index].title = title

            // Replace the old start time with the new start time from the edit form.
            rules[index].startTime = start

            // Replace the old end time with the new end time from the edit form.
            rules[index].endTime = end

            // Replace the old Screen Time app/category selection with the new selection from the edit form.
            rules[index].activitySelection = activitySelection

            // Because rules is @Published and has didSet, changing this rule automatically saves and syncs it.
        
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
    
    
    
    // MARK: - Stats (data for the Home screen)
    
    // Today
    @Published var moneyLostToday: Double = 15 // Example: dollars lost today
    @Published var minutesWastedToday: Int = 15 // Example: minutes wasted today

    // This week
    @Published var moneyLostThisWeek: Double = 100 // Example: dollars lost this week
    @Published var minutesWastedThisWeek: Int = 35 // Example: minutes wasted this week

    // Lifetime
    @Published var moneyLostLifetime: Double = 500 // Example: total dollars lost
    @Published var minutesWastedLifetime: Int = 300 // Example: total minutes wasted (5 hours)
    
    
    // MARK: - Formatting helpers

    // A simple currency formatter to display money values like $15.00
    private lazy var moneyFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = "USD"
        return nf
    }()
    
    func formattedMoney (_ value: Double) -> String {
        moneyFormatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
    
    var lifetimeHours: Int {
        minutesWastedLifetime / 60
    }
    
}
