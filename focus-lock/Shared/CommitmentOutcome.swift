//
//  CommitmentOutcome.swift
//  focus-lock
//

import Foundation

// The two honest outcomes we can determine for a committed one-time rule.
// These are local motivational records, not financial transactions.
enum CommitmentOutcomeResult: String, Codable {
    case completed
    case endedEarly
}

// A compact snapshot survives after its original one-time Rule is removed.
struct CommitmentOutcome: Identifiable, Codable, Equatable {
    let ruleID: UUID
    let ruleTitle: String
    let simulatedCommitmentCents: Int
    let result: CommitmentOutcomeResult
    let occurredAt: Date

    // One one-time rule can produce only one final outcome.
    var id: UUID {
        ruleID
    }
}

// Both the app and DeviceActivity monitor extension use this App Group-backed store.
// Keeping the write logic here prevents duplicate completion records when both
// processes notice the same finished one-time rule.
enum FocusLockCommitmentStore {
    private static let fileName = "commitment-outcomes.json"
    private static let maximumStoredOutcomes = 100

    static func loadOutcomes() -> [CommitmentOutcome] {
        guard let url = outcomesFileURL(),
              FileManager.default.fileExists(atPath: url.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([CommitmentOutcome].self, from: data)
                .sorted { $0.occurredAt > $1.occurredAt }
        } catch {
            FocusLockDiagnostics.record("CommitmentStore failed to load outcomes: \(error)")
            return []
        }
    }

    // Returns true only when this call created or replaced an outcome.
    @discardableResult
    static func record(_ result: CommitmentOutcomeResult,
                       for rule: Rule,
                       occurredAt: Date = Date()) -> Bool {
        guard rule.ruleKind == .scheduled,
              rule.isOneTime,
              let cents = rule.simulatedCommitmentCents,
              cents > 0 else {
            return false
        }

        // A disabled rule did not remain active through completion.
        if result == .completed && !rule.isEnabled {
            return false
        }

        var outcomes = loadOutcomes()
        let newOutcome = CommitmentOutcome(
            ruleID: rule.id,
            ruleTitle: rule.title,
            simulatedCommitmentCents: cents,
            result: result,
            occurredAt: occurredAt
        )

        if let existingIndex = outcomes.firstIndex(where: { $0.ruleID == rule.id }) {
            let existing = outcomes[existingIndex]

            // Ended early wins if an end-time callback races with a confirmed early exit.
            guard existing.result != .endedEarly, result == .endedEarly else {
                return false
            }

            outcomes[existingIndex] = newOutcome
        } else {
            outcomes.append(newOutcome)
        }

        outcomes.sort { $0.occurredAt > $1.occurredAt }
        outcomes = Array(outcomes.prefix(maximumStoredOutcomes))
        return saveOutcomes(outcomes)
    }

    private static func saveOutcomes(_ outcomes: [CommitmentOutcome]) -> Bool {
        guard let url = outcomesFileURL() else {
            FocusLockDiagnostics.record("CommitmentStore save failed: App Group container unavailable.")
            return false
        }

        do {
            let data = try JSONEncoder().encode(outcomes)
            try data.write(to: url, options: .atomic)
            FocusLockDiagnostics.record("CommitmentStore saved \(outcomes.count) outcome(s).")
            return true
        } catch {
            FocusLockDiagnostics.record("CommitmentStore failed to save outcomes: \(error)")
            return false
        }
    }

    private static func outcomesFileURL() -> URL? {
        FocusLockDiagnostics.appGroupContainerURL()?.appendingPathComponent(fileName)
    }
}
