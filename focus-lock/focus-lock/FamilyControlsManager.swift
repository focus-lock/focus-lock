//
//  FamilyControlsManager.swift
//  focus-lock
//
//  Created by Shabarish Nair on 2/9/26.
//

import Foundation
import FamilyControls
import SwiftUI
import Combine

class FamilyControlsManager: ObservableObject {
    
    // 1. Singleton instance
    static let shared = FamilyControlsManager()
    
    // 2. Published property for UI updates
    @Published var hasScreenTimePermission = false
    
    // 3. Authorization center
    private let center = AuthorizationCenter.shared
    
    // 4. Request Authorization Function
    func requestAuthorization() async {
        do {
            // 5. The actual request
            try await center.requestAuthorization(for: .individual)
            
            // 6. Update success state on main actor
            await MainActor.run {
                self.hasScreenTimePermission = true
            }
        } catch {
            // 7. Handle errors
            print("Failed to enroll: \(error)")
        }
    }
    
}
