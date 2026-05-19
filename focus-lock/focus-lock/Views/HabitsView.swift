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
        VStack(alignment: .leading, spacing: 20) {
            header

            rangePicker

            DeviceActivityReport(.focusLockHabits, filter: selectedRange.filter)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
        .background(Color(.systemGroupedBackground))
        .safeAreaPadding(.bottom, 96)
        .navigationTitle("Habits")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Screen habits")
                .font(.largeTitle.bold())

            Text("See where your attention is going, then tune your rules around the real patterns.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
