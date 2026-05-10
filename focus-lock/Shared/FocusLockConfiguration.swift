//
//  FocusLockConfiguration.swift
//  focus-lock
//

// Foundation gives us Bundle, String, and other base types.
import Foundation

// A tiny namespace for app-wide configuration values.
//
// enum with no cases is a common Swift pattern for "a bag of static helpers."
// It means we are not planning to create a FocusLockConfiguration() object.
enum FocusLockConfiguration {

    // This is the Info.plist key where we store the resolved App Group identifier.
    //
    // In project.pbxproj, we set:
    // INFOPLIST_KEY_FocusLockAppGroupIdentifier = "$(APP_GROUP_IDENTIFIER)";
    //
    // At build time, Xcode replaces $(APP_GROUP_IDENTIFIER) with something like:
    // group.com.focuslock.focuslockapp
    private static let appGroupInfoKey = "FocusLockAppGroupIdentifier"

    // A computed property.
    //
    // It looks like a variable, but it runs code each time we ask for it.
    static var appGroupIdentifier: String {
        if let appGroup = infoPlistAppGroupIdentifier {
            return appGroup
        }

        return derivedAppGroupIdentifier
    }

    static var appGroupSource: String {
        infoPlistAppGroupIdentifier == nil ? "bundle identifier fallback" : "Info.plist"
    }

    private static var infoPlistAppGroupIdentifier: String? {

        // Bundle.main is the currently running bundle.
        // In the main app, Bundle.main is the app.
        // In the extension, Bundle.main is the extension.
        //
        // object(forInfoDictionaryKey:) reads a value from Info.plist.
        //
        // "as? String" means: try to treat the value as a String.
        // If it is not a String, the result becomes nil instead of crashing.
        //
        // if let appGroup = ... means:
        // "If this optional has a real value, unwrap it into a constant named appGroup."
        if let appGroup = Bundle.main.object(forInfoDictionaryKey: appGroupInfoKey) as? String,

           // This second condition says the string must not be empty.
           !appGroup.isEmpty {

            // If the Info.plist value exists and is not empty, use it.
            return appGroup
        }

        return nil
    }

    private static var derivedAppGroupIdentifier: String {
        // Fallback value derived from the current bundle identifier.
        //
        // Ideally we do not use this, because the xcconfig/project setting should provide
        // the real value. But if the Info.plist key is missing, deriving from the bundle
        // ID is safer than hardcoding one developer's App Group.
        //
        // Examples:
        // com.focuslock.focuslockapp -> group.com.focuslock.focuslockapp
        // com.focuslock.focuslockapp.FocusLockDeviceActivityMonitor -> group.com.focuslock.focuslockapp
        let bundleID = Bundle.main.bundleIdentifier ?? "com.focuslock.focuslock-app"
        let baseBundleID = bundleID
            .replacingOccurrences(of: ".FocusLockDeviceActivityMonitor", with: "")
            .replacingOccurrences(of: ".FocusLockShieldConfiguration", with: "")

        return "group.\(baseBundleID)"
    }
}
