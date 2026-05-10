//
//  ScreenTimeShieldManager.swift
//  focus-lock
//
//  Created by Suraj Modur on 5/8/26.
//

import ManagedSettings

final class ScreenTimeShieldManager {
    static let shared = ScreenTimeShieldManager()

    private let store = ManagedSettingsStore()

    // Rebuilds the shield list from rules that are enabled and active right now.
    // Apps outside their scheduled time are not shielded.
    //
    // The main app calls this for immediate feedback while it is open.
    // The DeviceActivity monitor extension handles scheduled refreshes while the app is closed.
    func syncShields(for rules: [Rule]) {

        // Ask shared schedule logic which selected app tokens should be blocked right now.
        //
        // This returns a Set<ApplicationToken>.
        // Empty set means no selected apps currently need shielding.
        let activeApplicationTokens = FocusLockSchedule.activeApplicationTokens(from: rules)

        // If no rules are active right now, remove all shields.
        //
        // The ternary operator works like:
        // condition ? valueIfTrue : valueIfFalse
        //
        // So this means:
        // if activeApplicationTokens is empty, set shield.applications to nil;
        // otherwise, set it to the tokens we should block.
        store.shield.applications = activeApplicationTokens.isEmpty ? nil : activeApplicationTokens
    }

    // Removes all app shields managed by this store.
    func clearShields() {
        store.shield.applications = nil
    }
}
