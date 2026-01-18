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
        Rule(title: "No tiktok during work", isEnabled: true),
        Rule(title: "Limit Instagram to 10min/day", isEnabled: false)
    ]
    
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

