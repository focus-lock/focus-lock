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
    // Builds the custom Focus Lock blocked screen that every shield type should reuse.
    private func focusLockShieldConfiguration() -> ShieldConfiguration {
        // Returns the title, subtitle, button text, and button color for the shield screen.
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
    
    // iOS calls this when the user opens an app that was selected directly.
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        // Shows the custom Focus Lock blocked screen for directly selected apps.
        return focusLockShieldConfiguration()
    }
    
    // iOS calls this when the user opens an app blocked because its category was selected.
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        // Shows the custom Focus Lock blocked screen for apps blocked through a category.
        return focusLockShieldConfiguration()
    }
    
    // iOS calls this when the user opens a web domain that was selected directly.
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        // Shows the custom Focus Lock blocked screen for directly selected websites.
        return focusLockShieldConfiguration()
    }
    
    // iOS calls this when the user opens a web domain blocked because its category was selected.
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        // Shows the custom Focus Lock blocked screen for websites blocked through a category.
        return focusLockShieldConfiguration()
    }
}
