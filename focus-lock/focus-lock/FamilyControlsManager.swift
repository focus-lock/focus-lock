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

@MainActor
final class FamilyControlsManager: ObservableObject {

    // 1. Singleton instance
    static let shared = FamilyControlsManager()

    // 2. Published authorization state for UI updates.
    @Published private(set) var authorizationStatus: AuthorizationStatus

    // Stores the latest authorization failure so the UI can explain what happened.
    @Published private(set) var authorizationErrorMessage: String?

    // 3. Authorization center
    private let center = AuthorizationCenter.shared

    private init() {
        authorizationStatus = center.authorizationStatus
    }

    var hasScreenTimePermission: Bool {
        if authorizationStatus == .approved {
            return true
        }

        if #available(iOS 26.4, *), authorizationStatus == .approvedWithDataAccess {
            return true
        }

        return false
    }

    // 4. Request Authorization Function
    func requestAuthorization() async {
        do {
            // 5. The actual request
            try await center.requestAuthorization(for: .individual)

            // 6. Update success state.
            refreshAuthorizationStatus()
            authorizationErrorMessage = nil
        } catch {
            // 7. Handle errors
            refreshAuthorizationStatus()
            authorizationErrorMessage = error.localizedDescription
        }
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = center.authorizationStatus
    }

}
