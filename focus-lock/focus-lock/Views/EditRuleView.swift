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

    // Stores the editable start time while the user changes it.
    @State private var startTime: Date

    // Stores the editable end time while the user changes it.
    @State private var endTime: Date

    // Stores the editable app/category selection.
    @State private var activitySelection: FamilyActivitySelection

    // Tracks whether Apple's Screen Time picker should be visible.
    @State private var showAppPicker = false
    
    // Controls the popup shown when the edited schedule is too short for DeviceActivity.
    @State private var showDurationAlert = false


    // Runs when this edit screen is created with a specific rule.
    init(rule: Rule) {
        // Saves the original rule so we can use its id later when saving.
        self.rule = rule

        // Fills the text field with the rule's current title.
        _ruleName = State(initialValue: rule.title)

        // Fills the start picker with the rule's current start time.
        _startTime = State(initialValue: rule.startTime)

        // Fills the end picker with the rule's current end time.
        _endTime = State(initialValue: rule.endTime)

        // Fills the app picker with the rule's current selected apps.
        _activitySelection = State(initialValue: rule.activitySelection)
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
                }

                // Groups the time pickers under a Schedule heading.
                Section("Schedule") {
                    // Lets the user change the start time.
                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)

                    // Lets the user change the end time.
                    DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
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
                            Text("\(activitySelection.applicationTokens.count) selected")
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
                        // Create a temporary version of the edited rule so we can check the
                        // new start/end time before changing the saved rule.
                        let draftRule = Rule(
                            id: rule.id,
                            title: ruleName,
                            isEnabled: rule.isEnabled,
                            createdAt: rule.createdAt,
                            startTime: startTime,
                            endTime: endTime,
                            activitySelection: activitySelection
                        )

                        // DeviceActivity will not monitor intervals shorter than our shared
                        // minimum, so keep the original rule unchanged and explain the problem.
                        if FocusLockSchedule.durationMinutes(for: draftRule) < FocusLockSchedule.minimumMonitorDurationMinutes {
                            showDurationAlert = true
                            return
                        }

                        appState.editRule(
                            id: rule.id,
                            title: ruleName,
                            start: startTime,
                            end: endTime,
                            activitySelection: activitySelection
                        )

                        dismiss()
                    }


                    // Prevents saving when required fields are missing.
                    .disabled(ruleName.isEmpty || activitySelection.applicationTokens.isEmpty)
                }
            }
            // Explains why Save did not work when the schedule is under the minimum duration.
            .alert("Schedule Too Short", isPresented: $showDurationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Focus Lock rules must be at least \(FocusLockSchedule.minimumMonitorDurationMinutes) minutes long.")
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
}
