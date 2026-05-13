//
//  Rule.swift
//  focus-lock
//
//  Created by Shabarish on 1/17/26.
//

// Foundation gives us basic Swift/iOS types like UUID, Date, Calendar, Codable, etc.
import Foundation

// FamilyControls gives us FamilyActivitySelection, which stores the apps/categories/websites
// selected from Apple's Screen Time picker.
import FamilyControls

// A Rule is one saved blocking rule in our app.
//
// Example:
// "Block Gmail from 9:00 AM to 5:00 PM."
//
// This file now lives in Shared/ because BOTH the main app and the DeviceActivity extension
// need to understand what a Rule is.
struct Rule: Identifiable, Hashable, Codable {

    // Identifiable means SwiftUI can uniquely identify each rule in a ForEach.
    // UUID() creates a unique ID automatically when we create a new Rule.
    var id: UUID = UUID()

    // The user-facing name typed into the "Rule Name" field.
    var title: String

    // Whether the rule is turned on or off in the UI.
    var isEnabled: Bool

    // The date/time when this rule was first created.
    // Date() means "right now" when the Rule is created.
    var createdAt: Date = Date()

    // The daily start time for the rule.
    //
    // Calendar.current.date(from:) converts date components into a real Date.
    // .init(hour: 9, minute: 0) is shorthand for DateComponents(hour: 9, minute: 0).
    // The ! means "force unwrap"; we are telling Swift this date should always exist.
    var startTime: Date = Calendar.current.date(from: .init(hour: 9, minute: 0))!

    // The daily end time for the rule.
    // Same idea as startTime, but the default is 5:00 PM.
    var endTime: Date = Calendar.current.date(from: .init(hour: 17, minute: 0))!

    // Apple's Screen Time picker stores selected apps/categories/websites in this value.
    //
    // We mostly use activitySelection.applicationTokens right now.
    // An ApplicationToken is Apple's privacy-preserving way to represent a selected app.
    var activitySelection: FamilyActivitySelection = FamilyActivitySelection()
    
    // Stores which weekdays this rule repeats on.
        // Swift Calendar weekday numbers are usually:
        // 1 = Sunday, 2 = Monday, 3 = Tuesday, 4 = Wednesday,
        // 5 = Thursday, 6 = Friday, 7 = Saturday.
        // If this set is empty, we treat the rule as a one-time rule.
        var repeatWeekdays: Set<Int> = Rule.allWeekdays

        // Stores the calendar date for a one-time rule.
        // This is only used when repeatWeekdays is empty.
        // Example: May 13, 2026.
        var oneTimeDate: Date?

        // Gives us one shared definition of "every day."
        // Existing rules should behave like this after the migration.
        static let allWeekdays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]

        // Returns true when the rule should repeat on one or more weekdays.
        var isRecurring: Bool {
            !repeatWeekdays.isEmpty
        }

        // Returns true when the rule should run once and then be removed.
        var isOneTime: Bool {
            repeatWeekdays.isEmpty
        }
    
    

    // Hashable usually implies Equatable, and Swift can often generate this for us.
    // We define it manually so two Rule values count as "the same rule" if their IDs match.
    static func == (lhs: Rule, rhs: Rule) -> Bool {
        lhs.id == rhs.id
    }

    // Hashable lets a Rule be used in Set/dictionary-style operations.
    // We only hash the ID because the ID is the rule's identity.
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
