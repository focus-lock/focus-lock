//
//  CreateRuleView.swift
//  focus-lock
//
//  Created by Shabarish  on 1/21/26.
//

import SwiftUI

struct CreateRuleView: View {
    // 1. "Dismiss" is a function provided by the system to close this sheet.
    @Environment(\.dismiss) var dismiss
    
    // 2. We need access to the store to save the rule.
    @EnvironmentObject var appState: AppState
    
    // 3. Local state for the text field.
    @State private var ruleName = ""
    @State private var startTime = Calendar.current.date(from: .init(hour: 9, minute: 0))!
    @State private var endTime = Calendar.current.date(from: .init(hour: 17, minute: 0))!
    
    var body: some View {
        // IMPORTANT: Sheets start a "Fresh Context".
        // Use a NEW NavigationStack here so we can have a Toolbar (Save/Cancel buttons).
        // The NavigationStack from the background View doesn't reach into the Sheet.
        
        NavigationStack {
            Form {
                Section("Rule Details"){
                    TextField("Rule Name", text: $ruleName)
                }
                Section("Schedule"){
                    //DatePicker is a built-in SwiftUI component
                    //displayedComponents: .hourAndMinute hides the Day/Month part
                    
                    DatePicker("Start Time", selection: $startTime,
                               displayedComponents: .hourAndMinute)
                    DatePicker("End Time", selection: $endTime,
                               displayedComponents: .hourAndMinute)
                }
                
            }
            .navigationTitle(Text("New Rule"))
            .toolbar {
                // Cancel Button
                ToolbarItem(placement: .cancellationAction){
                    Button("Cancel"){
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction){
                    Button("Save"){
                        appState.addRule(title: ruleName, start: startTime, end: endTime)
                        dismiss()
                    }
                    .disabled(ruleName.isEmpty)
                }
                
            }
        }
    }
}
