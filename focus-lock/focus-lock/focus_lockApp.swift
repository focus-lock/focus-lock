//
//  focus_lockApp.swift
//  focus-lock
//
//  Created by Shabarish Nair on 1/11/26.
//

import SwiftUI

@main
struct focus_lockApp: App {
    
    // 1. Create the state object
    @StateObject var familyControlsManager = FamilyControlsManager.shared
    // Creates the shared app state at the app entry point.
    @StateObject private var appState = AppState()
    // Watches whether the app is active, inactive, or in the background.
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Gives every child screen access to the same shared app state.
                .environmentObject(appState)
                .environmentObject(familyControlsManager)
            
            // 2. Start the check when the app launches
                .task {
                    await familyControlsManager.requestAuthorization()
                }
                // Runs whenever the app changes between active, inactive, and background.
                .onChange(of: scenePhase) { newPhase in
                    // Only reload saved rules when the app becomes active on screen.
                    guard newPhase == .active else {
                        // Ignore background and inactive transitions.
                        return
                    }
                    
                    // Reload rules in case the DeviceActivity extension deleted a completed one-time rule.
                    appState.refreshRulesFromStorage()
                    familyControlsManager.refreshAuthorizationStatus()
                }
            
        }
    }
}
