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
    // Controls the popup shown when the selected schedule is too short for DeviceActivity.
    @State private var showDurationAlert = false
    
    // Builds the text shown next to the app picker row.
    private var selectedActivitySummary: String {
        // Counts directly selected individual apps.
        let appCount = activitySelection.applicationTokens.count

        // Counts selected app categories, including category "Select All".
        let categoryCount = activitySelection.categoryTokens.count

        // Counts selected websites if the user selects web domains later.
        let webDomainCount = activitySelection.webDomainTokens.count

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
                            // Shows the total number of selected picker items.
                            Text(selectedActivitySummary)
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
                        // Create a temporary rule so we can reuse the same duration helper
                        // that the schedule manager uses before saving anything.
                        let draftRule = Rule(
                                title: ruleName,
                                isEnabled: true,
                                startTime: startTime,
                                endTime: endTime,
                                activitySelection: activitySelection
                            )
                        
                        // DeviceActivity will not monitor intervals shorter than our shared
                        // minimum, so show an alert instead of saving a rule iOS will skip.
                        if FocusLockSchedule.durationMinutes(for: draftRule) < FocusLockSchedule.minimumMonitorDurationMinutes{
                            showDurationAlert = true
                            return
                        }
                        
                        appState.addRule(
                            title: ruleName,
                            start: startTime,
                            end: endTime,
                            activitySelection: activitySelection
                        )

                        dismiss()
                    }
                    .disabled(ruleName.isEmpty || !FocusLockSchedule.hasSelectedActivity(activitySelection))
                }
            }
            // Explains why Save did not work when the schedule is under the minimum duration.
            .alert("Schedule Too Short", isPresented: $showDurationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Focus Lock rules must be at least \(FocusLockSchedule.minimumMonitorDurationMinutes) minutes long.")
            }
            .familyActivityPicker(
                isPresented: $showAppPicker,
                selection: $activitySelection
            )
        }
    }
}
