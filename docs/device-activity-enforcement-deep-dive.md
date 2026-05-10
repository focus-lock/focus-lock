# DeviceActivity Enforcement Deep Dive

This document explains PR #35 in beginner-friendly detail. The goal is to make the code feel less magical: what each Apple framework does, why the app needs an extension, how rules move through the system, and what still needs follow-up work.

## 1. The Problem We Solved

Before this PR, Focus Lock could block apps only when the main app was awake and ran this kind of logic:

```swift
ScreenTimeShieldManager.shared.syncShields(for: rules)
```

That works for immediate feedback, but it does not solve this case:

1. User creates a rule from 9:00 AM to 5:00 PM.
2. User closes Focus Lock.
3. At 9:00 AM, Focus Lock is not running.
4. Something still needs to apply the block.

iOS does not let normal apps run arbitrary code in the background whenever they want. For Screen Time style apps, Apple provides a specific background mechanism:

```text
DeviceActivityMonitor extension
```

That extension can receive callbacks when a registered schedule starts or ends.

## 2. The Big Architecture

There are now three important pieces:

```text
Main app
  - User creates, toggles, and deletes rules.
  - Saves rules to shared storage.
  - Registers schedules with iOS.
  - Applies shields immediately while app is open.

DeviceActivity monitor extension
  - Woken by iOS at schedule boundaries.
  - Loads saved rules from shared storage.
  - Applies or clears shields while the app is closed.

Shared code folder
  - Code used by both the main app and the extension.
  - Rule model, schedule math, App Group storage, diagnostics.
```

The key flow is:

```text
Create rule
  -> save rules.json to App Group storage
  -> register DeviceActivity schedule
  -> sync shields immediately

Scheduled start/end happens later
  -> iOS wakes DeviceActivityMonitor extension
  -> extension reads rules.json from App Group storage
  -> extension applies or clears ManagedSettings shields
```

## 3. Frameworks Involved

### FamilyControls

Used for asking Screen Time permission and letting the user pick apps.

Important type:

```swift
FamilyActivitySelection
```

This stores what the user selected in Apple's app picker.

### ManagedSettings

Used to actually block selected apps.

Important types:

```swift
ManagedSettingsStore
ApplicationToken
```

An `ApplicationToken` is Apple's privacy-preserving representation of an app the user selected. We do not store bundle IDs like `com.google.Gmail`. We store opaque app tokens and pass those tokens back to Apple.

The actual blocking line is:

```swift
store.shield.applications = activeApplicationTokens
```

Clearing shields is:

```swift
store.shield.applications = nil
```

### DeviceActivity

Used for scheduling and background callbacks.

Important types:

```swift
DeviceActivityCenter
DeviceActivitySchedule
DeviceActivityMonitor
DeviceActivityName
```

The main app uses `DeviceActivityCenter` to register schedules. The extension subclasses `DeviceActivityMonitor` to receive callbacks.

## 4. Why App Groups Are Needed

The main app and the monitor extension are not the same process.

```text
focus-lock app
FocusLockDeviceActivityMonitor extension
```

The main app's private Documents folder is not a reliable place for the extension to read saved rules. They need a shared container. Apple calls that an App Group.

For Shabarish:

```text
App bundle ID: com.focuslock.focuslockapp
App Group:     group.com.focuslock.focuslockapp
```

For Suraj:

```text
App bundle ID: com.focuslock.focuslock-app
App Group:     group.com.focuslock.focuslock-app
```

Both the main app and `FocusLockDeviceActivityMonitor` need the same App Group enabled in Signing & Capabilities.

`FocusLockShieldConfiguration` does not currently need App Groups because it only customizes the blocked screen UI. It does not read saved rules.

## 5. Local Config and Signing

Each developer has their own ignored local file:

```text
focus-lock/Config/Local.xcconfig
```

Shabarish's local config:

```xcconfig
DEVELOPMENT_TEAM = 6326888VVQ
APP_BUNDLE_ID = com.focuslock.focuslockapp
APP_GROUP_IDENTIFIER = group.com.focuslock.focuslockapp
```

Suraj's local config:

```xcconfig
DEVELOPMENT_TEAM = TGK2CZ6QA4
APP_BUNDLE_ID = com.focuslock.focuslock-app
APP_GROUP_IDENTIFIER = group.com.focuslock.focuslock-app
```

The committed entitlements use:

```xml
$(APP_GROUP_IDENTIFIER)
```

That keeps the committed project flexible for both individual Apple Developer accounts.

## 6. The Shared Rule Model

`Rule` moved from the main app folder into:

```text
focus-lock/Shared/Rule.swift
```

Why? Because both targets need to understand rules:

```text
Main app creates and saves rules.
Extension loads and applies rules.
```

Important fields:

```swift
var id: UUID
var title: String
var isEnabled: Bool
var startTime: Date
var endTime: Date
var activitySelection: FamilyActivitySelection
```

`activitySelection.applicationTokens` is the selected app set that eventually gets shielded.

## 7. Saving Rules

Rules are saved by:

```swift
FocusLockRuleStore.saveRules(rules)
```

Rules are loaded by:

```swift
FocusLockRuleStore.loadRules()
```

The store writes to:

```text
App Group container / rules.json
```

This matters because both the app and extension can access the App Group container.

We intentionally avoid silently falling back to normal app Documents storage. If App Group access fails, closed-app enforcement cannot work, so hiding that would make debugging painful.

## 8. Schedule Logic

Schedule logic lives in:

```text
focus-lock/Shared/FocusLockSchedule.swift
```

This file answers questions like:

```text
Is this rule enabled?
Did the user select apps?
Is the rule active right now?
How long is the rule?
What DeviceActivitySchedule should iOS monitor?
```

The key function for immediate shielding is:

```swift
static func activeApplicationTokens(from rules: [Rule], now: Date = Date()) -> Set<ApplicationToken>
```

It:

1. Filters rules down to rules that are monitorable and active right now.
2. Combines all selected app tokens from those rules.
3. Returns one unique set of app tokens to block.

## 9. The 15-Minute Minimum

While testing, a 2-minute schedule failed with:

```text
MonitoringError.intervalTooShort
```

That came from:

```swift
DeviceActivityCenter.startMonitoring(...)
```

So we added:

```swift
static let minimumMonitorDurationMinutes = 15
```

For now, rules shorter than 15 minutes are skipped by DeviceActivity registration. The UI still allows saving them. That is tracked in:

```text
#33 Add UI validation for DeviceActivity minimum rule duration
```

Important: the exact Apple minimum still needs to be confirmed or turned into a deliberate product rule.

## 10. Registering Schedules

The main app registers schedules in:

```text
focus-lock/focus-lock/DeviceActivityScheduleManager.swift
```

Core call:

```swift
try center.startMonitoring(
    activityName,
    during: FocusLockSchedule.schedule(for: rule)
)
```

This tells iOS:

```text
Please monitor this daily interval and call my DeviceActivity extension when it starts/ends.
```

The activity name is based on the rule ID:

```swift
focus-lock-rule-<UUID>
```

That makes it possible to register one schedule per rule and stop obsolete schedules when rules are deleted or disabled.

## 11. Why We Still Sync Shields in the Main App

This is still needed:

```swift
ScreenTimeShieldManager.shared.syncShields(for: rules)
```

`DeviceActivityScheduleManager` only registers future callbacks. It does not immediately block apps.

Example:

```text
Current time: 2:00 PM
User creates rule: 9:00 AM - 5:00 PM
```

The schedule's start time already happened today. If we only register the schedule, the app may not block immediately. So the app still computes the current active shield state and applies it right away.

The split is:

```text
Main app syncShields:
  "What should be blocked right now?"

DeviceActivity extension:
  "What should change when the app is closed and schedule boundaries happen?"
```

## 12. The DeviceActivity Extension

The extension lives in:

```text
focus-lock/FocusLockDeviceActivityMonitor/
```

Important class:

```swift
final class DeviceActivityMonitorExtension: DeviceActivityMonitor
```

iOS calls:

```swift
intervalDidStart(for:)
intervalDidEnd(for:)
```

When either callback runs, the extension:

1. Loads rules from App Group storage.
2. Computes active app tokens.
3. Applies or clears shields.

The extension does not depend on the main app being open.

## 13. The Info.plist/Fallback Issue

### What Info.plist is

Every iOS app and extension bundle has an `Info.plist`.

You can think of it as metadata that tells iOS:

```text
What is this bundle's identifier?
What is its display name?
What executable should launch?
If this is an extension, what extension point does it implement?
What custom metadata does the app want to read at runtime?
```

For example, our DeviceActivity monitor extension has:

```xml
<key>NSExtensionPointIdentifier</key>
<string>com.apple.deviceactivity.monitor-extension</string>
```

That tells iOS:

```text
This extension is a DeviceActivity monitor extension.
```

It also has:

```xml
<key>NSExtensionPrincipalClass</key>
<string>$(PRODUCT_MODULE_NAME).DeviceActivityMonitorExtension</string>
```

That tells iOS which Swift class to instantiate when the extension runs.

### What we wanted from Info.plist

We tried to read this from Info.plist:

```text
FocusLockAppGroupIdentifier
```

The idea was:

```text
Xcode build settings know APP_GROUP_IDENTIFIER.
Xcode writes APP_GROUP_IDENTIFIER into Info.plist.
Swift reads FocusLockAppGroupIdentifier from Info.plist.
Swift uses that value to find the App Group container.
```

In code, that looked like:

```swift
Bundle.main.object(forInfoDictionaryKey: "FocusLockAppGroupIdentifier")
```

This is useful because it keeps runtime code from hardcoding either developer's App Group. Instead, the value should come from build settings:

```xcconfig
APP_GROUP_IDENTIFIER = group.com.focuslock.focuslockapp
```

or:

```xcconfig
APP_GROUP_IDENTIFIER = group.com.focuslock.focuslock-app
```

In theory, that is a nice design:

```text
Local.xcconfig controls local identity.
Entitlements use the same value for signing.
Info.plist exposes the same value to Swift at runtime.
```

### What actually happened

But runtime logs showed:

```text
(bundle identifier fallback)
```

That means the custom Info.plist key was not available at runtime.

So Swift asked:

```text
Do you have FocusLockAppGroupIdentifier?
```

and the running app effectively answered:

```text
No.
```

The app still needed an App Group string, so it used fallback logic.

At first, the fallback was hardcoded to Suraj's group:

```text
group.com.focuslock.focuslock-app
```

That broke on Shabarish's device, which needed:

```text
group.com.focuslock.focuslockapp
```

### What we did instead

The current fallback derives from the running bundle ID:

```text
com.focuslock.focuslockapp
-> group.com.focuslock.focuslockapp
```

For the extension:

```text
com.focuslock.focuslockapp.FocusLockDeviceActivityMonitor
-> group.com.focuslock.focuslockapp
```

This works because our convention is:

```text
App Group = group.<main app bundle id>
```

For the main app, the bundle ID is already the base app ID:

```text
com.focuslock.focuslockapp
```

For the extension, the bundle ID has a suffix:

```text
com.focuslock.focuslockapp.FocusLockDeviceActivityMonitor
```

So the fallback removes known extension suffixes before adding `group.`.

### Why this is okay for now

The fallback is safer than hardcoding one developer's value because it adapts to both local setups:

```text
Shabarish:
com.focuslock.focuslockapp
-> group.com.focuslock.focuslockapp

Suraj:
com.focuslock.focuslock-app
-> group.com.focuslock.focuslock-app
```

It also helped us prove the feature works. After the fallback produced the correct local group, App Group storage started working and closed-app blocking succeeded.

### Why this still needs cleanup

The confusing part is that the code still has two possible sources:

```text
1. Info.plist key
2. bundle identifier fallback
```

That is why we created ticket #34. Long-term, we should choose one source of truth.

This is tracked for cleanup in:

```text
#34 Fix App Group runtime configuration source
```

Long-term, we should choose one clean source of truth:

```text
Option A: make Info.plist key work reliably
Option B: always derive from bundle ID and remove unused Info.plist plumbing
```

## 14. Diagnostics

We added:

```text
focus-lock/Shared/FocusLockDiagnostics.swift
```

Diagnostics are off by default:

```swift
private static let isEnabled = false
```

When enabled, diagnostics:

```text
print to Xcode console
write breadcrumbs to App Group diagnostics.log
dump the log when the app opens
```

This is useful because extension print logs can be hard to see.

Normal development should keep diagnostics off.

## 15. What We Proved

On a real iPhone, we proved:

1. App Group access works after fixing the group mismatch.
2. 2-minute schedules fail with `intervalTooShort`.
3. 15+ minute schedules register successfully.
4. With Focus Lock closed, the selected app blocks at the scheduled start time.

That means the core architecture works.

## 16. What Still Needs To Be Done

### Ticket #33: UI validation for minimum duration

Users should not be able to save schedules that DeviceActivity will reject.

Needed:

```text
Show validation message in CreateRuleView.
Disable Save for too-short intervals.
Confirm real minimum or choose product minimum.
Keep overnight durations working.
```

### Ticket #34: App Group runtime configuration cleanup

We should remove confusion around App Group source of truth.

Needed:

```text
Decide Info.plist vs bundle-derived runtime lookup.
If Info.plist, make the key actually appear at runtime.
If bundle-derived, remove unused Info.plist plumbing.
Keep both developers' bundle IDs working.
```

### Future cleanup

Once the feature is stable:

```text
Trim some beginner-heavy comments if they become noisy.
Keep the comments that explain Apple-specific APIs.
Decide whether diagnostics stay as a debug helper or move behind a build flag.
```

## 17. Testing Checklist

Use a real iPhone, not simulator.

1. Delete the app if signing/capabilities changed.
2. Build/run from Xcode.
3. Create a rule that starts a couple minutes in the future.
4. Make the duration at least 15 minutes.
5. Save.
6. Confirm registration succeeds if diagnostics are enabled.
7. Leave Focus Lock normally. Do not force quit.
8. Open a selected app after the start time.
9. Confirm the app is blocked.
10. Confirm it unblocks after the end time.

## 18. Mental Model To Remember

The simplest version:

```text
FamilyControls = choose apps
ManagedSettings = block apps
DeviceActivity = wake extension on schedule
App Groups = share saved rules between app and extension
```

The feature works only when all four parts are connected.
