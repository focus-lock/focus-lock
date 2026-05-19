//
//  FocusLockHabitsReport.swift
//  FocusLockDeviceActivityReport
//

import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftUI
import _DeviceActivity_SwiftUI

extension DeviceActivityReport.Context {
    static let focusLockHabits = Self("FocusLockHabits")
}

struct FocusLockHabitsReport: DeviceActivityReportScene {
    // This must match the context used by HabitsView in the main app.
    let context: DeviceActivityReport.Context = .focusLockHabits

    // DeviceActivityReportScene asks for a closure that turns the calculated
    // configuration into the SwiftUI view shown inside the main app.
    let content: (FocusLockHabitsConfiguration) -> FocusLockHabitsReportView = { configuration in
        FocusLockHabitsReportView(configuration: configuration)
    }

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> FocusLockHabitsConfiguration {
        var totalActivityDuration: TimeInterval = 0
        var totalPickups = 0
        var totalNotifications = 0
        var longestActivity: DateInterval?
        var lastUpdatedDate: Date?
        var appRowsByID: [String: FocusLockAppActivityRow] = [:]

        for await activityData in data {
            lastUpdatedDate = latest(lastUpdatedDate, activityData.lastUpdatedDate)

            for await segment in activityData.activitySegments {
                totalActivityDuration += segment.totalActivityDuration
                longestActivity = longest(longestActivity, segment.longestActivity)

                for await category in segment.categories {
                    for await applicationActivity in category.applications {
                        totalPickups += applicationActivity.numberOfPickups
                        totalNotifications += applicationActivity.numberOfNotifications

                        let fallbackName = "App"
                        let displayName = applicationActivity.application.localizedDisplayName ?? fallbackName
                        let bundleIdentifier = applicationActivity.application.bundleIdentifier ?? displayName
                        let existingRow = appRowsByID[bundleIdentifier]

                        appRowsByID[bundleIdentifier] = FocusLockAppActivityRow(
                            id: bundleIdentifier,
                            displayName: displayName,
                            token: applicationActivity.application.token,
                            duration: (existingRow?.duration ?? 0) + applicationActivity.totalActivityDuration,
                            pickups: (existingRow?.pickups ?? 0) + applicationActivity.numberOfPickups,
                            notifications: (existingRow?.notifications ?? 0) + applicationActivity.numberOfNotifications
                        )
                    }
                }
            }
        }

        let apps = appRowsByID.values
            .sorted { $0.duration > $1.duration }

        return FocusLockHabitsConfiguration(
            totalActivityDuration: totalActivityDuration,
            totalPickups: totalPickups,
            totalNotifications: totalNotifications,
            longestActivity: longestActivity,
            lastUpdatedDate: lastUpdatedDate,
            apps: apps
        )
    }

    private func latest(_ current: Date?, _ candidate: Date) -> Date {
        guard let current else {
            return candidate
        }

        return max(current, candidate)
    }

    private func longest(_ current: DateInterval?, _ candidate: DateInterval?) -> DateInterval? {
        guard let candidate else {
            return current
        }

        guard let current else {
            return candidate
        }

        return candidate.duration > current.duration ? candidate : current
    }
}

struct FocusLockHabitsConfiguration {
    let totalActivityDuration: TimeInterval
    let totalPickups: Int
    let totalNotifications: Int
    let longestActivity: DateInterval?
    let lastUpdatedDate: Date?
    let apps: [FocusLockAppActivityRow]
}

struct FocusLockAppActivityRow: Identifiable {
    let id: String
    let displayName: String
    let token: ApplicationToken?
    let duration: TimeInterval
    let pickups: Int
    let notifications: Int
}

struct FocusLockHabitsReportView: View {
    let configuration: FocusLockHabitsConfiguration

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let lastUpdatedDate = configuration.lastUpdatedDate {
                    Text("Updated \(lastUpdatedDate.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                summaryGrid

                appsSection
            }
            .padding(.bottom, 120)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            metricTile(
                title: "Screen time",
                value: formattedDuration(configuration.totalActivityDuration),
                systemImage: "iphone",
                tint: .blue
            )

            metricTile(
                title: "Pickups",
                value: "\(configuration.totalPickups)",
                systemImage: "hand.tap",
                tint: .orange
            )

            metricTile(
                title: "Notifications",
                value: "\(configuration.totalNotifications)",
                systemImage: "bell.badge",
                tint: .purple
            )

            metricTile(
                title: "Longest session",
                value: formattedDuration(configuration.longestActivity?.duration ?? 0),
                systemImage: "clock",
                tint: .green
            )
        }
    }

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Apps")
                    .font(.headline)
            }

            if configuration.apps.isEmpty {
                Text("No app activity reported for this range yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                appRows
            }
        }
    }

    private var appRows: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(visibleApps) { app in
                appRow(app)
            }
        }
    }

    private var visibleApps: [FocusLockAppActivityRow] {
        configuration.apps
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }

    private func metricTile(title: String, value: String, systemImage: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)

            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func appRow(_ app: FocusLockAppActivityRow) -> some View {
        HStack(spacing: 12) {
            appIcon(app)

            VStack(alignment: .leading, spacing: 6) {
                Text(app.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                HStack(spacing: 12) {
                    Label("\(app.pickups)", systemImage: "hand.tap")
                    Label("\(app.notifications)", systemImage: "bell")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Text(formattedDuration(app.duration))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func appIcon(_ app: FocusLockAppActivityRow) -> some View {
        if let token = app.token {
            Label(token)
                .labelStyle(.iconOnly)
                .frame(width: 34, height: 34)
        } else {
            Image(systemName: "app.dashed")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = max(0, Int(duration / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(minutes)m"
    }
}
