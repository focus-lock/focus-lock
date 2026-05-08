//
//  CreateRuleView.swift
//  focus-lock
//
//  Created by Shabarish on 1/21/26.
//

import SwiftUI
import FamilyControls

struct CreateRuleView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState

    @State private var ruleName = ""
    @State private var startTime = Calendar.current.date(from: .init(hour: 9, minute: 0))!
    @State private var endTime = Calendar.current.date(from: .init(hour: 17, minute: 0))!

    @State private var activitySelection = FamilyActivitySelection()
    @State private var showAppPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Rule Details") {
                    TextField("Rule Name", text: $ruleName)
                }

                Section("Schedule") {
                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)

                    DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                }

                Section("Apps") {
                    Button {
                        showAppPicker = true
                    } label: {
                        HStack {
                            Text("Select Apps")
                            Spacer()
                            Text("\(activitySelection.applicationTokens.count) selected")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(Text("New Rule"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        appState.addRule(
                            title: ruleName,
                            start: startTime,
                            end: endTime,
                            activitySelection: activitySelection
                        )

                        dismiss()
                    }
                    .disabled(ruleName.isEmpty || activitySelection.applicationTokens.isEmpty)
                }
            }
            .familyActivityPicker(
                isPresented: $showAppPicker,
                selection: $activitySelection
            )
        }
    }
}
