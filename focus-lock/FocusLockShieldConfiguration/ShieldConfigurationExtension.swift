//
//  ShieldConfigurationExtension.swift
//  FocusLockShieldConfiguration
//
//  Created by Suraj Modur on 5/8/26.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

// Override the functions below to customize the shields used in various situations.
// The system provides a default appearance for any methods that your subclass doesn't override.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    // iOS calls this when the user opens an app that Focus Lock has shielded.
    // This config controls the system blocked screen shown over that app.
    override func configuration(shielding application: Application) -> ShieldConfiguration {

        return ShieldConfiguration(
            // Matches the title currently shown in BlockedView.
            title: .init(
                text: "App is blocked",
                color: .label
            ),

            // Adds a short explanation because shield screens support a subtitle area.
            subtitle: .init(
                text: "Focus Lock is keeping you away from this app.",
                color: .secondaryLabel
            ),

            // Matches the button currently shown in BlockedView.
            primaryButtonLabel: .init(
                text: "Pay $5 to unlock",
                color: .white
            ),

            // Makes the primary action look like a real call-to-action button.
            primaryButtonBackgroundColor: .systemBlue
        )
    }
    
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        // Customize the shield as needed for applications shielded because of their category.
        ShieldConfiguration()
    }
    
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        // Customize the shield as needed for web domains.
        ShieldConfiguration()
    }
    
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        // Customize the shield as needed for web domains shielded because of their category.
        ShieldConfiguration()
    }
}
