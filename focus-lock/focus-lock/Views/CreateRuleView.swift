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
    // Stores the weekdays selected for repeating this rule.
    @State private var repeatWeekdays = Rule.allWeekdays
    // Stores the calendar date used when no repeat weekdays are selected.
    @State private var oneTimeDate = Date()

    @State private var activitySelection = FamilyActivitySelection()
    @State private var showAppPicker = false
    // Controls the sheet where the user chooses repeat settings.
    @State private var showRepeatSettings = false
    // Controls the popup shown when the selected schedule is too short for DeviceActivity.
    @State private var showDurationAlert = false
    // Controls the popup shown when a one-time rule already ended.
    @State private var showCompletedOneTimeAlert = false
    
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
    
    // Returns true when no repeat weekdays are selected.
    private var isOneTimeRule: Bool {
        // Empty repeat days means this rule should happen once.
        repeatWeekdays.isEmpty
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
                    
                    // Shows a date picker only when the rule is one-time.
                    if isOneTimeRule {
                        // Lets the user choose the exact date for the one-time rule.
                        DatePicker("Date", selection: $oneTimeDate, displayedComponents: .date)
                    }
                }
                
                // Lets the user open repeat settings from one clean row.
                Section("Repeat") {
                    // Opens the repeat settings sheet when tapped.
                    Button {
                        // Shows the repeat settings sheet.
                        showRepeatSettings = true
                    } label: {
                        // Places the row title and current repeat summary side by side.
                        HStack {
                            // Shows the row title.
                            Text("Repeat")
                            // Pushes the summary to the right side.
                            Spacer()
                            // Shows the current recurrence choice.
                            Text(repeatSummary)
                                // Styles the summary as secondary text.
                                .foregroundStyle(.secondary)
                        }
                    }
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
                                activitySelection: activitySelection,
                                // Stores the selected repeat weekdays on the draft rule.
                                repeatWeekdays: repeatWeekdays,
                                // Stores a date only when this is a one-time rule.
                                oneTimeDate: isOneTimeRule ? oneTimeDate : nil
                            )
                        
                        // DeviceActivity will not monitor intervals shorter than our shared
                        // minimum, so show an alert instead of saving a rule iOS will skip.
                        if FocusLockSchedule.durationMinutes(for: draftRule) < FocusLockSchedule.minimumMonitorDurationMinutes{
                            showDurationAlert = true
                            return
                        }
                        
                        // One-time rules should not be saved if their end time has already passed.
                        if FocusLockSchedule.isCompletedOneTimeRule(draftRule) {
                            // Shows an alert explaining that the selected one-time session is already over.
                            showCompletedOneTimeAlert = true
                            // Stops before saving the expired one-time rule.
                            return
                        }
                        
                        appState.addRule(
                            title: ruleName,
                            start: startTime,
                            end: endTime,
                            activitySelection: activitySelection,
                            // Sends the selected repeat weekdays to AppState.
                            repeatWeekdays: repeatWeekdays,
                            // Sends a one-time date only when no weekdays are selected.
                            oneTimeDate: isOneTimeRule ? oneTimeDate : nil
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
            // Explains why Save did not work when a one-time rule is already over.
            .alert("Invalid Time Range", isPresented: $showCompletedOneTimeAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Choose a future date or a time window that has not already ended.")
            }
            // Opens the repeat settings picker as a sheet.
            .sheet(isPresented: $showRepeatSettings) {
                // Shows the shared repeat settings UI.
                RepeatSettingsView(repeatWeekdays: $repeatWeekdays)
            }
            .familyActivityPicker(
                isPresented: $showAppPicker,
                selection: $activitySelection
            )
        }
    }
    
    // Builds the repeat summary shown on the main form.
    private var repeatSummary: String {
        // Creates a temporary rule so we can reuse the shared summary helper.
        let draftRule = Rule(
            title: ruleName,
            isEnabled: true,
            startTime: startTime,
            endTime: endTime,
            activitySelection: activitySelection,
            repeatWeekdays: repeatWeekdays,
            oneTimeDate: isOneTimeRule ? oneTimeDate : nil
        )
        
        // Returns text like Daily, Tue/Thu, or One time.
        return FocusLockSchedule.recurrenceSummary(for: draftRule)
    }
}

// Reusable sheet for choosing repeat behavior.
struct RepeatSettingsView: View {
    // Closes this sheet when the user taps Done.
    @Environment(\.dismiss) private var dismiss
    
    // Reads and writes the selected repeat weekdays from the parent screen.
    @Binding var repeatWeekdays: Set<Int>
    
    // Builds the repeat settings screen.
    var body: some View {
        // Gives the sheet a title and toolbar.
        NavigationStack {
            // Creates an iOS-style settings form.
            Form {
                // Groups the simple repeat choices.
                Section("Repeat") {
                    // Selects a one-time rule.
                    Button {
                        // Empty repeat days means this rule does not repeat.
                        repeatWeekdays = []
                    } label: {
                        // Shows the one-time option row.
                        repeatOptionRow(title: "Does Not Repeat", isSelected: repeatWeekdays.isEmpty)
                    }
                    
                    // Selects a daily recurring rule.
                    Button {
                        // All weekdays means this rule repeats every day.
                        repeatWeekdays = Rule.allWeekdays
                    } label: {
                        // Shows the daily option row.
                        repeatOptionRow(title: "Daily", isSelected: repeatWeekdays == Rule.allWeekdays)
                    }
                }
                
                // Groups custom weekday choices.
                Section("Custom Days") {
                    // Creates one tappable row for each weekday.
                    ForEach(FocusLockSchedule.weekdayDisplayOrder, id: \.self) { weekday in
                        // Toggles this weekday when the row is tapped.
                        Button {
                            // Adds or removes the selected weekday.
                            toggleRepeatWeekday(weekday)
                        } label: {
                            // Shows the weekday row with a checkmark when selected.
                            repeatOptionRow(
                                title: FocusLockSchedule.weekdayShortLabels[weekday] ?? "",
                                isSelected: repeatWeekdays.contains(weekday)
                            )
                        }
                    }
                }
            }
            // Shows the sheet title.
            .navigationTitle("Repeat")
            // Uses an inline title so the sheet feels compact.
            .navigationBarTitleDisplayMode(.inline)
            // Adds buttons to the top of the sheet.
            .toolbar {
                // Places Done on the confirmation side of the toolbar.
                ToolbarItem(placement: .confirmationAction) {
                    // Creates the Done button.
                    Button("Done") {
                        // Closes the sheet.
                        dismiss()
                    }
                }
            }
        }
    }
    
    // Builds one selectable option row.
    private func repeatOptionRow(title: String, isSelected: Bool) -> some View {
        // Places the label and checkmark in one row.
        HStack {
            // Shows the option title.
            Text(title)
            // Pushes the checkmark to the right side.
            Spacer()
            // Shows a checkmark only for the selected option.
            if isSelected {
                // Displays Apple's checkmark icon.
                Image(systemName: "checkmark")
                    // Uses the app accent color for selected rows.
                    .foregroundColor(.accentColor)
            }
        }
    }
    
    // Adds or removes one weekday from the selected repeat days.
    private func toggleRepeatWeekday(_ weekday: Int) {
        // Checks whether the weekday is already selected.
        if repeatWeekdays.contains(weekday) {
            // Removes the weekday when it is already selected.
            repeatWeekdays.remove(weekday)
        } else {
            // Adds the weekday when it is not selected yet.
            repeatWeekdays.insert(weekday)
        }
    }
}
