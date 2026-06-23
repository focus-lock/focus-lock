//
//  EditRuleView.swift
//  focus-lock
//

// Imports SwiftUI so this file can build screens, forms, buttons, and navigation.
import SwiftUI

// Imports FamilyControls so this file can use FamilyActivitySelection and familyActivityPicker.
import FamilyControls

// Defines a SwiftUI screen used to edit one existing rule.
struct EditRuleView: View {
    // Gets SwiftUI's built-in dismiss action so this sheet can close itself.
    @Environment(\.dismiss) var dismiss

    // Gets the shared AppState so this screen can save edited rule data.
    @EnvironmentObject var appState: AppState

    // Stores the original rule passed in from RulesView.
    let rule: Rule

    // Stores the editable rule name while the user types.
    @State private var ruleName: String

    // Stores whether this rule is scheduled or a daily usage limit.
    @State private var ruleKind: RuleKind

    // Stores the editable start time while the user changes it.
    @State private var startTime: Date

    // Stores the editable end time while the user changes it.
    @State private var endTime: Date

    // Stores the editable app/category selection.
    @State private var activitySelection: FamilyActivitySelection
    
    // Stores the editable repeat weekdays.
    @State private var repeatWeekdays: Set<Int>
    
    // Stores the editable date for a one-time rule.
    @State private var oneTimeDate: Date

    // Stores the selected preset daily usage limit.
    @State private var selectedUsageLimitMinutes: Int

    // Stores the custom daily usage limit.
    @State private var customUsageLimitMinutes: Int

    // Tracks whether the custom duration control is active.
    @State private var isUsingCustomUsageLimit: Bool

    // Tracks whether Apple's Screen Time picker should be visible.
    @State private var showAppPicker = false
    
    // Controls the sheet where the user chooses repeat settings.
    @State private var showRepeatSettings = false
    
    // Controls the popup shown when the edited schedule is too short for DeviceActivity.
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

    // Returns the selected daily usage limit.
    private var usageLimitMinutes: Int {
        isUsingCustomUsageLimit ? customUsageLimitMinutes : selectedUsageLimitMinutes
    }

    // Returns true when the user is editing a usage-limit rule.
    private var isUsageLimitRule: Bool {
        ruleKind == .usageLimit
    }



    // Runs when this edit screen is created with a specific rule.
    init(rule: Rule) {
        // Saves the original rule so we can use its id later when saving.
        self.rule = rule

        // Fills the text field with the rule's current title.
        _ruleName = State(initialValue: rule.title)

        // Fills the rule type picker with the rule's current kind.
        _ruleKind = State(initialValue: rule.ruleKind)

        // Fills the start picker with the rule's current start time.
        _startTime = State(initialValue: rule.startTime)

        // Fills the end picker with the rule's current end time.
        _endTime = State(initialValue: rule.endTime)

        // Fills the app picker with the rule's current selected apps.
        _activitySelection = State(initialValue: rule.activitySelection)
        
        // Fills the repeat weekday controls with the rule's current repeat days.
        _repeatWeekdays = State(initialValue: rule.repeatWeekdays)
        
        // Fills the one-time date picker with the saved date, or today if there is no saved date yet.
        _oneTimeDate = State(initialValue: rule.oneTimeDate ?? Date())

        let savedUsageLimitMinutes = rule.usageLimitMinutes ?? 30
        let presetUsageLimitMinutes = [15, 30, 60].contains(savedUsageLimitMinutes) ? savedUsageLimitMinutes : 30

        _selectedUsageLimitMinutes = State(initialValue: presetUsageLimitMinutes)
        _customUsageLimitMinutes = State(initialValue: max(savedUsageLimitMinutes, FocusLockSchedule.minimumMonitorDurationMinutes))
        _isUsingCustomUsageLimit = State(initialValue: ![15, 30, 60].contains(savedUsageLimitMinutes))
    }

    // Describes the UI that appears inside the edit sheet.
    var body: some View {
        // Adds navigation styling so the sheet can have a title and toolbar buttons.
        NavigationStack {
            // Creates an iOS-style form layout for the editable fields.
            Form {
                // Groups the rule name field under a Rule Details heading.
                Section("Rule Details") {
                    // Lets the user change the rule name.
                    TextField("Rule Name", text: $ruleName)

                    Picker("Rule Type", selection: $ruleKind) {
                        Text("Schedule").tag(RuleKind.scheduled)
                        Text("Usage Limit").tag(RuleKind.usageLimit)
                    }
                    .pickerStyle(.segmented)
                }

                if isUsageLimitRule {
                    Section("Daily Limit") {
                        Picker("Duration", selection: $selectedUsageLimitMinutes) {
                            Text("15 min").tag(15)
                            Text("30 min").tag(30)
                            Text("1 hour").tag(60)
                        }
                        .disabled(isUsingCustomUsageLimit)

                        Toggle("Custom Duration", isOn: $isUsingCustomUsageLimit)

                        if isUsingCustomUsageLimit {
                            TextField("Minutes", value: $customUsageLimitMinutes, format: .number)
                                .keyboardType(.numberPad)
                        }

                        Text("Today starts counting when this rule is saved. Future days reset daily.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    // Groups the time pickers under a Schedule heading.
                    Section("Schedule") {
                        // Lets the user change the start time.
                        DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)

                        // Lets the user change the end time.
                        DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                        
                        // Shows a date picker only when the edited rule is one-time.
                        if isOneTimeRule {
                            // Lets the user choose the exact date for the one-time rule.
                            DatePicker("Date", selection: $oneTimeDate, displayedComponents: .date)
                        }
                    }
                    
                    // Groups recurrence controls under a Repeat heading.
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
                }

                // Groups the selected app controls under an Apps heading.
                Section("Apps") {
                    // Creates a tappable row for opening the app picker.
                    Button {
                        // Changes state so Apple's Screen Time picker opens.
                        showAppPicker = true
                    } label: {
                        // Places the row title and selected count horizontally.
                        HStack {
                            // Shows the label for the app picker row.
                            Text("Select Apps")

                            // Pushes the selected count to the right side of the row.
                            Spacer()

                            // Shows how many apps are currently selected.
                            Text(selectedActivitySummary)
                                // Makes the selected count use secondary text styling.
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Shows Edit Rule as the sheet title.
            .navigationTitle(Text("Edit Rule"))

            // Adds navigation bar buttons to the sheet.
            .toolbar {
                // Places this item where Cancel actions normally appear.
                ToolbarItem(placement: .cancellationAction) {
                    // Creates a Cancel button.
                    Button("Cancel") {
                        // Closes the edit sheet without saving changes.
                        dismiss()
                    }
                }

                // Places this item where Save actions normally appear.
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if isUsageLimitRule {
                            if usageLimitMinutes < FocusLockSchedule.minimumMonitorDurationMinutes {
                                showDurationAlert = true
                                return
                            }

                            appState.editUsageLimitRule(
                                id: rule.id,
                                title: ruleName,
                                usageLimitMinutes: usageLimitMinutes,
                                activitySelection: activitySelection
                            )

                            dismiss()
                            return
                        }

                        // Create a temporary version of the edited rule so we can check the
                        // new start/end time before changing the saved rule.
                        let draftRule = Rule(
                            id: rule.id,
                            title: ruleName,
                            isEnabled: rule.isEnabled,
                            createdAt: rule.createdAt,
                            startTime: startTime,
                            endTime: endTime,
                            activitySelection: activitySelection,
                            // Stores the edited repeat weekdays on the draft rule.
                            repeatWeekdays: repeatWeekdays,
                            // Stores a date only when this is a one-time rule.
                            oneTimeDate: isOneTimeRule ? oneTimeDate : nil
                        )

                        // DeviceActivity will not monitor intervals shorter than our shared
                        // minimum, so keep the original rule unchanged and explain the problem.
                        if FocusLockSchedule.durationMinutes(for: draftRule) < FocusLockSchedule.minimumMonitorDurationMinutes {
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

                        appState.editRule(
                            id: rule.id,
                            title: ruleName,
                            start: startTime,
                            end: endTime,
                            activitySelection: activitySelection,
                            // Sends the edited repeat weekdays to AppState.
                            repeatWeekdays: repeatWeekdays,
                            // Sends a one-time date only when no weekdays are selected.
                            oneTimeDate: isOneTimeRule ? oneTimeDate : nil
                        )

                        dismiss()
                    }


                    // Prevents saving when required fields are missing.
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
            // Attaches Apple's Screen Time picker to this edit screen.
            .familyActivityPicker(
                // Opens the picker when showAppPicker becomes true.
                isPresented: $showAppPicker,

                // Stores the user's picker choices in activitySelection.
                selection: $activitySelection
            )
        }
    }
    
    // Builds the repeat summary shown on the main form.
    private var repeatSummary: String {
        // Creates a temporary rule so we can reuse the shared summary helper.
        let draftRule = Rule(
            id: rule.id,
            title: ruleName,
            isEnabled: rule.isEnabled,
            createdAt: rule.createdAt,
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
