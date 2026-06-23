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

// Describes how a rule decides when selected apps should be blocked.
enum RuleKind: String, Codable {
    // Scheduled rules use the existing start/end time window behavior.
    case scheduled

    // Usage limit rules block after the selected apps have been used for a daily limit.
    case usageLimit
}

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

    // Whether this rule is a scheduled time window or a daily usage limit.
    var ruleKind: RuleKind = .scheduled

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

    // The amount of selected-app usage allowed each day before a usage-limit rule blocks.
    //
    // Scheduled rules leave this as nil.
    var usageLimitMinutes: Int?

    // The date/time when this usage-limit rule most recently reached its daily limit.
    //
    // If this date is today, the selected apps should stay blocked until the next day
    // unless the user disables the rule.
    var usageLimitReachedAt: Date?
    
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

    // Keeps old saved rules working when new fields are added.
    //
    // Without this custom decoder, older rules.json files would fail to load because they
    // do not contain ruleKind, usageLimitMinutes, or usageLimitReachedAt.
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case isEnabled
        case ruleKind
        case createdAt
        case startTime
        case endTime
        case activitySelection
        case usageLimitMinutes
        case usageLimitReachedAt
        case repeatWeekdays
        case oneTimeDate
    }

    init(id: UUID = UUID(),
         title: String,
         isEnabled: Bool,
         ruleKind: RuleKind = .scheduled,
         createdAt: Date = Date(),
         startTime: Date = Calendar.current.date(from: .init(hour: 9, minute: 0))!,
         endTime: Date = Calendar.current.date(from: .init(hour: 17, minute: 0))!,
         activitySelection: FamilyActivitySelection = FamilyActivitySelection(),
         usageLimitMinutes: Int? = nil,
         usageLimitReachedAt: Date? = nil,
         repeatWeekdays: Set<Int> = Rule.allWeekdays,
         oneTimeDate: Date? = nil) {
        self.id = id
        self.title = title
        self.isEnabled = isEnabled
        self.ruleKind = ruleKind
        self.createdAt = createdAt
        self.startTime = startTime
        self.endTime = endTime
        self.activitySelection = activitySelection
        self.usageLimitMinutes = usageLimitMinutes
        self.usageLimitReachedAt = usageLimitReachedAt
        self.repeatWeekdays = repeatWeekdays
        self.oneTimeDate = oneTimeDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        ruleKind = try container.decodeIfPresent(RuleKind.self, forKey: .ruleKind) ?? .scheduled
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        startTime = try container.decodeIfPresent(Date.self, forKey: .startTime) ?? Calendar.current.date(from: .init(hour: 9, minute: 0))!
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime) ?? Calendar.current.date(from: .init(hour: 17, minute: 0))!
        activitySelection = try container.decodeIfPresent(FamilyActivitySelection.self, forKey: .activitySelection) ?? FamilyActivitySelection()
        usageLimitMinutes = try container.decodeIfPresent(Int.self, forKey: .usageLimitMinutes)
        usageLimitReachedAt = try container.decodeIfPresent(Date.self, forKey: .usageLimitReachedAt)
        repeatWeekdays = try container.decodeIfPresent(Set<Int>.self, forKey: .repeatWeekdays) ?? Rule.allWeekdays
        oneTimeDate = try container.decodeIfPresent(Date.self, forKey: .oneTimeDate)
    }
}
