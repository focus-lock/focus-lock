//
//  Rule.swift
//  focus-lock
//
//  Created by Shabarish  on 1/17/26.
//

import Foundation
import FamilyControls

struct Rule: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var title: String
    var isEnabled: Bool
    var createdAt: Date = Date()
    var startTime: Date = Calendar.current.date(from: .init(hour: 9, minute: 0))!
    var endTime: Date = Calendar.current.date(from: .init(hour: 17, minute: 0))!
    var activitySelection: FamilyActivitySelection = FamilyActivitySelection()
    
    static func == (lhs: Rule, rhs: Rule) -> Bool {
            lhs.id == rhs.id
        }

    func hash(into hasher: inout Hasher) {
            hasher.combine(id)
    }

}
