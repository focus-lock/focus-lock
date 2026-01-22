//
//  AppState.swift
//  focus-lock
//
//  Created by Shabarish  on 1/17/26.
//


import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    
    // MARK: - Rules (data for the Rules screen)
    @Published var rules: [Rule] = [
//        Rule(title: "No tiktok during work", isEnabled: true),
//        Rule(title: "Limit Instagram to 10min/day", isEnabled: false)
    ] {
        // Runs right after something changes in rules
        didSet {
            saveRules()
        }
    }
    
    // MARK: - Actions
    
    // Encapsulation: The View shouldn't know HOW to append a rule, just that it WANTS to add one.
    // We now include start and end times in the creation.
    func addRule(title: String, start: Date, end: Date){
        let newRule = Rule(
            title: title,
            isEnabled: true,
            startTime: start,
            endTime: end
        )
        rules.append(newRule)
        // Note: saveRules() is called automatically because of 'didSet' on the 'rules' variable.
    }
    
    // Sets initial state of rules
    init () {
        rules = loadRules()
    }
    
    
    // Retrieves document folder within phone and stores rules.json within that folder path
    private func rulesFileURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("rules.json")
    }
    
    
    // Writes rules into documents
    private func saveRules(){
        do {
            // Turns Rules object in JSON
            let data = try JSONEncoder().encode(rules)
            // Writes JSON data into ruleFileURL
            try data.write(to: rulesFileURL())
        } catch {
            print("Failed to save rules:", error)
        }
    }
    
    
    // Loads rules from the file path (Only runs at init)
    private func loadRules() -> [Rule] {
        
        let url = rulesFileURL()
        
        // Just makes sure rules.json exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        
        
        // Converts JSON to array of Rule and returns
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Rule].self, from: data)
        } catch {
            print("Failed to load rules:", error)
            return []
        }
    }
    
    func deleteRule(id:UUID){
        rules.removeAll(){
            $0.id == id
        }
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

