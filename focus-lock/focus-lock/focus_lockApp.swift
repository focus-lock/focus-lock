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
    var body: some Scene {
        WindowGroup {
            ContentView()
            
            // 2. Start the check when the app launches
                .task {
                    await familyControlsManager.requestAuthorization()
                }
            
        }
    }
}
