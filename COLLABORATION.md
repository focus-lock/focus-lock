# Deep Dive: Collaborating on iOS Screen Time Apps (Paid + Free)

This document outlines the technical strategy for multiple developers working on **Focus Lock** when only one has a paid Apple Developer Program membership.

## The Challenge
The `FamilyControls` framework (Screen Time API) requires a special entitlement (`com.apple.developer.family-controls`) signed by Apple.
- **Paid Account (You):** Can obtain this signature and run on real devices.
- **Free Account (Teammate):** Apple blocks this signature. The app will crash or fail to compile if it tries to access these APIs.

## The Strategy: Simulation Mode (Mocking)
We will architect the app to have two modes: **Real Mode** and **Simulation Mode**. This allows the free-account developer to build 90% of the app (UI, Logic, Rules) without ever touching the restricted Apple APIs.

### 1. Technical Implementation: Conditional Compilation
We use Swift's `#if targetEnvironment(simulator)` directive to automatically switch behavior.

**Why Simulator?**
Your teammate (Free Account) will develop *exclusively* on the iOS Simulator. This is the standard workflow for free accounts. You (Paid Account) will test on a Real Device.

### 2. Mocking the Permission Layer
**File:** `FamilyControlsManager.swift`
We wrap the sensitive Apple API calls.

```swift
class FamilyControlsManager: ObservableObject {
    // Automatically true if running on Simulator
    #if targetEnvironment(simulator)
    static let isSimulation = true
    #else
    static let isSimulation = false // Real device = Real API
    #endif

    func requestAuthorization() async {
        if Self.isSimulation {
            // FAKE IT: Pretend permission was granted immediately
            print("Simulating: Authorization Granted ✅")
            await MainActor.run { hasScreenTimePermission = true }
            return
        }

        // REAL IT: Call Apple API (Only on Real Device)
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }
}
```

### 3. Mocking the UI Layer (App Picker)
**File:** `CreateRuleView.swift` (Ticket A2)
The `FamilyActivityPicker` is an Apple-provided UI component that *also* requires the entitlement. We must swap it out.

```swift
if FamilyControlsManager.isSimulation {
    // Show a simple list of fake apps (e.g. "Instagram", "TikTok")
    // Teammate can select these to test the "Save Rule" logic.
    MockAppPicker(selection: $selection)
} else {
    // Show the real Apple picker (Only on Real Device)
    FamilyActivityPicker(selection: $selection)
}
```

### 4. Workflow & Roles

| Feature | **Signing Owner (You)** | **Feature Owner (Teammate)** |
| :--- | :--- | :--- |
| **Account Type** | Paid ($99/yr) | Free |
| **Primary Device** | Real iPhone | iOS Simulator |
| **Role** | Entitlements, final testing, App Store. | UI, CoreData, Logic, New Features. |
| **Process** | Merges PRs, verifies on-device. | Develops with Mock Data, opens PRs. |

### 5. Data Persistence
The `FamilyActivitySelection` object (which stores the list of selected apps) is specific to the Screen Time framework.
- **Simulation:** We can store a dummy selection or just ignore the specific token data, saving only the rule metadata (Name, Time).
- **Real:** We store actual opaque tokens provided by Apple.

## Summary
By using `isSimulation`, your teammate is **unblocked**. They can build the entire "Create Rule" flow, the "Home" dashboard, and the "Schedule" logic using simulated app selections. You then verify the "Real" blocking mechanics on your physical device.
