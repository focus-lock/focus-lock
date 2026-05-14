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
    private func focusLockShieldConfiguration(blockedName: String) -> ShieldConfiguration {
        // Returns the title, subtitle, button text, and button color for the shield screen.
        return ShieldConfiguration(
            // Uses a deep focus color behind the shield screen instead of the default background.
            backgroundColor: UIColor(red: 0.05, green: 0.09, blue: 0.12, alpha: 1.0),
            
            // Shows a lock-and-shield symbol so the screen feels protected, not like a timer.
            icon: UIImage(systemName: "lock.shield.fill"),
            
            // Shows a calm title that makes the block feel intentional.
            title: .init(
                text: "\(blockedName) can wait",
                color: .white
            ),

            // Reminds the user that this block protects the focus session they chose.
            subtitle: .init(
                text: "You chose this focus window. Stay with it.",
                color: .lightText
            ),

            // Gives the user a calm action label without implying payment or bypass behavior.
            primaryButtonLabel: .init(
                text: "Stay focused",
                color: .white
            ),

            // Uses a focused green button color that stands out against the dark background.
            primaryButtonBackgroundColor: UIColor(red: 0.10, green: 0.55, blue: 0.35, alpha: 1.0)
        )
    }
    
    // iOS calls this when the user opens an app that was selected directly.
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        // Shows the custom Focus Lock blocked screen for directly selected apps.
        return focusLockShieldConfiguration(blockedName: displayName(for: application))
    }
    
    // iOS calls this when the user opens an app blocked because its category was selected.
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        // Shows the custom Focus Lock blocked screen for apps blocked through a category.
        return focusLockShieldConfiguration(blockedName: displayName(for: application))
    }
    
    // iOS calls this when the user opens a web domain that was selected directly.
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        // Shows the custom Focus Lock blocked screen for directly selected websites.
        return focusLockShieldConfiguration(blockedName: displayName(for: webDomain))
    }
    
    // iOS calls this when the user opens a web domain blocked because its category was selected.
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        // Shows the custom Focus Lock blocked screen for websites blocked through a category.
        return focusLockShieldConfiguration(blockedName: displayName(for: webDomain))
    }

    // Uses Apple's display name when available, with a privacy-safe fallback.
    private func displayName(for application: Application) -> String {
        guard let name = application.localizedDisplayName, !name.isEmpty else {
            return "This app"
        }

        return name
    }

    // Uses the website domain when Apple provides it, with a generic fallback.
    private func displayName(for webDomain: WebDomain) -> String {
        guard let domain = webDomain.domain, !domain.isEmpty else {
            return "This website"
        }

        return domain
    }
}
