//
//  FocusLockRuleStore.swift
//  focus-lock
//

// Foundation gives us FileManager, URL, JSONEncoder, JSONDecoder, Data, etc.
import Foundation

// This enum is our small persistence layer for rules.
//
// "Persistence" means saving data somewhere so it survives app restarts.
//
// We put this in Shared/ because both processes need it:
// 1. The main app saves rules.
// 2. The DeviceActivity extension loads rules when iOS wakes it up.
enum FocusLockRuleStore {

    // The filename we use inside the shared App Group container.
    private static let fileName = "rules.json"

    // Loads saved rules from disk.
    //
    // The return type [Rule] means "an array of Rule."
    static func loadRules() -> [Rule] {

        // rulesFileURL() returns URL?, meaning it might fail and return nil.
        //
        // guard let means:
        // "If there is no URL, exit this function early."
        guard let url = rulesFileURL() else {
            FocusLockDiagnostics.record("RuleStore load failed: App Group container unavailable.")
            return []
        }

        // If the file has never been created, there are no saved rules yet.
        guard FileManager.default.fileExists(atPath: url.path) else {
            FocusLockDiagnostics.record("RuleStore load found no rules file at \(url.path).")
            return []
        }

        // do/try/catch is Swift's error-handling syntax.
        //
        // Reading a file can fail, and decoding JSON can fail, so both use try.
        do {
            // Read the raw bytes from rules.json.
            let data = try Data(contentsOf: url)

            // Convert JSON bytes back into [Rule].
            let rules = try JSONDecoder().decode([Rule].self, from: data)
            FocusLockDiagnostics.record("RuleStore loaded \(rules.count) rule(s) from \(url.path).")
            return rules
        } catch {
            // If anything in the do block fails, Swift jumps here.
            FocusLockDiagnostics.record("RuleStore failed to load rules: \(error)")
            return []
        }
    }

    // Saves the current rules array to disk.
    //
    // The parameter name is rules, and its type is [Rule].
    static func saveRules(_ rules: [Rule]) {

        // Find where rules.json should live.
        // If we cannot find a valid location, exit early.
        guard let url = rulesFileURL() else {
            FocusLockDiagnostics.record("RuleStore save failed: App Group container unavailable.")
            return
        }

        do {
            // Convert [Rule] into JSON bytes.
            let data = try JSONEncoder().encode(rules)

            // Write those JSON bytes to rules.json.
            try data.write(to: url)
            FocusLockDiagnostics.record("RuleStore saved \(rules.count) rule(s) to \(url.path).")
        } catch {
            FocusLockDiagnostics.record("RuleStore failed to save rules: \(error)")
        }
    }

    // Figures out the exact file URL for rules.json.
    //
    // Return type URL? means:
    // "This returns a URL if it can, but it might return nil."
    private static func rulesFileURL() -> URL? {

        // Use App Group storage.
        //
        // We intentionally do not fall back to app Documents here. The DeviceActivity
        // extension cannot rely on the app's private Documents directory, so falling
        // back would hide the exact problem we are trying to diagnose.
        return FocusLockDiagnostics.appGroupContainerURL()?.appendingPathComponent(fileName)
    }
}
