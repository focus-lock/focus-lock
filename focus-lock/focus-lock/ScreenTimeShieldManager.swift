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
        // Gets the active individual app tokens.
        let activeApplicationTokens = FocusLockSchedule.activeApplicationTokens(from: rules)

        // Gets the active app category tokens.
        let activeCategoryTokens = FocusLockSchedule.activeCategoryTokens(from: rules)

        // Gets the active web domain tokens.
        let activeWebDomainTokens = FocusLockSchedule.activeWebDomainTokens(from: rules)

        // Shields directly selected apps, or clears app shields if none are active.
        store.shield.applications = activeApplicationTokens.isEmpty ? nil : activeApplicationTokens

        // Shields selected app categories, or clears category shields if none are active.
        store.shield.applicationCategories = activeCategoryTokens.isEmpty ? nil : .specific(activeCategoryTokens)

        // Shields selected web domains, or clears web domain shields if none are active.
        store.shield.webDomains = activeWebDomainTokens.isEmpty ? nil : activeWebDomainTokens

    }

    // Removes all app shields managed by this store.
    func clearShields() {
        // Removes directly selected app shields.
        store.shield.applications = nil

        // Removes selected category shields.
        store.shield.applicationCategories = nil

        // Removes selected web domain shields.
        store.shield.webDomains = nil
    }
}
