//
//  SimulatedCommitmentSection.swift
//  focus-lock
//

import Foundation
import SwiftUI

// Keeps simulated commitment presentation in one place so Create Rule,
// Edit Rule, Quick Focus, Home, and Rules all use the same amounts and copy.
enum SimulatedCommitment {
    static let presetAmountsCents = [0, 500, 1_000, 2_500]

    // Zero means the user chose no commitment. We store that as nil on Rule
    // so old and unstaked rules remain lightweight and easy to distinguish.
    static func storedCents(from selectedCents: Int) -> Int? {
        selectedCents > 0 ? selectedCents : nil
    }

    static func formatted(cents: Int) -> String {
        let dollars = cents / 100
        let remainingCents = cents % 100

        if remainingCents == 0 {
            return "$\(dollars)"
        }

        return String(format: "$%d.%02d", dollars, remainingCents)
    }
}

// A reusable Form section for choosing an optional simulated commitment.
// No payment details are collected in this MVP 2A experiment.
struct SimulatedCommitmentSection: View {
    @Binding var selectedCents: Int

    var body: some View {
        Section {
            Picker("Amount", selection: $selectedCents) {
                ForEach(SimulatedCommitment.presetAmountsCents, id: \.self) { cents in
                    Text(cents == 0 ? "None" : SimulatedCommitment.formatted(cents: cents))
                        .tag(cents)
                }
            }
        } header: {
            Text("Commitment")
        } footer: {
            Text("Simulated for motivation only. Focus Lock will not charge you.")
        }
    }
}

#Preview {
    Form {
        SimulatedCommitmentSection(selectedCents: .constant(1_000))
    }
}
