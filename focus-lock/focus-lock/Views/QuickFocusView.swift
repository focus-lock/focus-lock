//
//  QuickFocusView.swift
//  focus-lock
//

import FamilyControls
import SwiftUI

struct QuickFocusView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var selectedDurationMinutes = 30
    @State private var activitySelection = FamilyActivitySelection()
    @State private var showAppPicker = false

    private let durationOptions = [
        QuickFocusDuration(minutes: 15, title: "15 min"),
        QuickFocusDuration(minutes: 30, title: "30 min"),
        QuickFocusDuration(minutes: 60, title: "1 hour"),
        QuickFocusDuration(minutes: 120, title: "2 hours")
    ]

    private var selectedActivitySummary: String {
        let appCount = activitySelection.applicationTokens.count
        let categoryCount = activitySelection.categoryTokens.count
        let webDomainCount = activitySelection.webDomainTokens.count

        var parts: [String] = []

        if appCount > 0 {
            parts.append("\(appCount) \(appCount == 1 ? "app" : "apps")")
        }

        if categoryCount > 0 {
            parts.append("\(categoryCount) \(categoryCount == 1 ? "category" : "categories")")
        }

        if webDomainCount > 0 {
            parts.append("\(webDomainCount) \(webDomainCount == 1 ? "website" : "websites")")
        }

        return parts.isEmpty ? "None selected" : parts.joined(separator: ", ") + " selected"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Duration", selection: $selectedDurationMinutes) {
                        ForEach(durationOptions) { option in
                            Text(option.title).tag(option.minutes)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Starts now and removes itself when the session ends.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Duration")
                }

                Section("Apps") {
                    Button {
                        showAppPicker = true
                    } label: {
                        HStack {
                            Text("Select Apps")
                            Spacer()
                            Text(selectedActivitySummary)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
            .navigationTitle("Start Focus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        appState.startQuickFocusSession(
                            durationMinutes: selectedDurationMinutes,
                            activitySelection: activitySelection
                        )
                        dismiss()
                    }
                    .disabled(!FocusLockSchedule.hasSelectedActivity(activitySelection))
                }
            }
            .familyActivityPicker(
                isPresented: $showAppPicker,
                selection: $activitySelection
            )
        }
    }
}

private struct QuickFocusDuration: Identifiable {
    let minutes: Int
    let title: String

    var id: Int {
        minutes
    }
}

#Preview {
    QuickFocusView()
        .environmentObject(AppState())
}
