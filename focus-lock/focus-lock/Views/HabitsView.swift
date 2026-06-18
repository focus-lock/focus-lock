//
//  HabitsView.swift
//  focus-lock
//

import DeviceActivity
import SwiftUI
import _DeviceActivity_SwiftUI

struct HabitsView: View {
    // Controls which date range the report asks Screen Time for.
    @State private var selectedRange: HabitRange = .today

    var body: some View {
        // Keep Habits as one fixed dashboard. DeviceActivityReport is hosted by
        // a separate extension process, and scroll gestures across that boundary
        // were unreliable on a real iPhone.
        VStack(alignment: .leading, spacing: 12) {
            rangePicker

            ZStack {
                // DeviceActivityReport does not expose a loading callback to the
                // main app. This remains visible behind the report until Apple's
                // extension host finishes rendering its opaque content.
                VStack(spacing: 10) {
                    ProgressView()

                    Text("Loading activity...")
                        .font(.subheadline.weight(.medium))

                    Text("Weekly and monthly reports may take a moment.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                DeviceActivityReport(.focusLockHabits, filter: selectedRange.filter)
                    // Recreate Apple's report host when the range changes so old
                    // Today/Week/Month results do not remain on screen.
                    .id(selectedRange.rawValue)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .background(Color(.systemGroupedBackground))
        .safeAreaPadding(.bottom, 88)
        .navigationTitle("Habits")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var rangePicker: some View {
        Picker("Range", selection: $selectedRange) {
            ForEach(HabitRange.allCases) { range in
                Text(range.title).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }
}

private enum HabitRange: String, CaseIterable, Identifiable {
    case today
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today:
            return "Today"
        case .week:
            return "Week"
        case .month:
            return "Month"
        }
    }

    var filter: DeviceActivityFilter {
        let interval = dateInterval
        let segment: DeviceActivityFilter.SegmentInterval

        switch self {
        case .today:
            segment = .hourly(during: interval)
        case .week:
            segment = .daily(during: interval)
        case .month:
            segment = .daily(during: interval)
        }

        return DeviceActivityFilter(segment: segment)
    }

    private var dateInterval: DateInterval {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .today:
            return calendar.dateInterval(of: .day, for: now) ?? DateInterval(start: now, duration: 24 * 60 * 60)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: now, duration: 7 * 24 * 60 * 60)
        case .month:
            return calendar.dateInterval(of: .month, for: now) ?? DateInterval(start: now, duration: 30 * 24 * 60 * 60)
        }
    }
}

#Preview {
    NavigationStack {
        HabitsView()
    }
}
