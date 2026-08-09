# Focus Lock Project Context for Future Codex Sessions

This document is the durable handoff for future Codex sessions and contributors. Update it as the project changes.

## Project Goal

Focus Lock is an iOS app that uses Apple's Screen Time APIs to let a user create rules that block selected apps during scheduled windows.

The MVP direction is:

- request Screen Time / FamilyControls authorization
- let the user select apps with Apple's picker
- save rules with selected app tokens and daily time windows
- block selected apps during active rules
- keep enforcement working when the main app is closed

## Current Branch Context

As of PR #35, the app has:

- app selection through `FamilyActivitySelection`
- custom shield UI through `FocusLockShieldConfiguration`
- closed-app schedule enforcement through `FocusLockDeviceActivityMonitor`
- shared rule storage using an App Group
- a long-form learning doc at `docs/device-activity-enforcement-deep-dive.md`
- an MVP 1 product vision doc at `docs/mvp-1-vision.md`
- Screen Time habits reporting through `FocusLockDeviceActivityReport`
- optional local-only simulated commitments on rules and Quick Focus
- confirmation guardrails for changing active simulated commitments

The branch that introduced the DeviceActivity enforcement context was:

```text
codex/device-activity-enforcement
```

## Important Apple Frameworks

Use this mental model:

```text
FamilyControls = permission and app selection
ManagedSettings = app shielding / blocking
ManagedSettingsUI = custom blocked-screen UI
DeviceActivity = scheduled callbacks while the app is closed
App Groups = shared storage between app and extension
```

## Target Structure

The Xcode project has four targets:

```text
focus-lock
  Main SwiftUI app.
  Creates rules, saves rules, registers schedules, and syncs shields immediately.

FocusLockShieldConfiguration
  ManagedSettingsUI shield configuration extension.
  Customizes the blocked screen shown by iOS.

FocusLockDeviceActivityMonitor
  DeviceActivity monitor extension.
  Woken by iOS at schedule start/end.
  Reads saved rules from App Group storage and applies/clears shields.

FocusLockDeviceActivityReport
  DeviceActivity report extension.
  Renders Screen Time habit analytics for the Habits tab.
  Receives private activity data from iOS and should not export raw usage data to the main app.
```

The shared Swift files live in:

```text
focus-lock/Shared/
```

Those files are compiled into both the main app and `FocusLockDeviceActivityMonitor`.

## Key Runtime Flow

When a rule is created/toggled/deleted:

```text
AppState changes rules
  -> FocusLockRuleStore saves rules.json into App Group storage
  -> DeviceActivityScheduleManager registers schedules with DeviceActivityCenter
  -> ScreenTimeShieldManager syncs shields immediately while app is open
```

When the app is closed and a schedule boundary happens:

```text
iOS wakes FocusLockDeviceActivityMonitor
  -> intervalDidStart or intervalDidEnd runs
  -> extension loads rules.json from App Group storage
  -> FocusLockSchedule computes active app tokens
  -> ManagedSettingsStore applies or clears shields
```

## Important Files

```text
focus-lock/focus-lock/State/AppState.swift
  Owns the in-memory rules array.
  Saves rules and triggers schedule/shield syncs.

focus-lock/focus-lock/DeviceActivityScheduleManager.swift
  Registers rule schedules with DeviceActivityCenter.

focus-lock/focus-lock/ScreenTimeShieldManager.swift
  Applies immediate shields while the app is open.

focus-lock/FocusLockDeviceActivityMonitor/DeviceActivityMonitorExtension.swift
  Extension callback entrypoint for closed-app enforcement.

focus-lock/FocusLockDeviceActivityReport/DeviceActivityReportExtension.swift
  Extension entrypoint for Screen Time habits reporting.

focus-lock/FocusLockDeviceActivityReport/FocusLockHabitsReport.swift
  Aggregates DeviceActivity report data into the Habits tab UI.

focus-lock/focus-lock/Views/HabitsView.swift
  Main-app Habits tab that hosts DeviceActivityReport.

focus-lock/Shared/Rule.swift
  Shared Rule model.

focus-lock/Shared/FocusLockRuleStore.swift
  Saves and loads rules.json from App Group storage.

focus-lock/Shared/FocusLockSchedule.swift
  Shared schedule math and active-token calculation.

focus-lock/Shared/FocusLockConfiguration.swift
  Determines the App Group identifier.

focus-lock/Shared/FocusLockDiagnostics.swift
  Temporary diagnostics helper, off by default.

focus-lock/Shared/CommitmentOutcome.swift
  Stores local outcomes for committed one-time rules in the App Group.
```

## Signing and Local Config

Both developers use individual Apple Developer accounts. Do not commit personal signing values.

Each developer should have an ignored local file:

```text
focus-lock/Config/Local.xcconfig
```

Shabarish local config:

```xcconfig
DEVELOPMENT_TEAM = 6326888VVQ
APP_BUNDLE_ID = com.focuslock.focuslockapp
APP_GROUP_IDENTIFIER = group.com.focuslock.focuslockapp
```

Suraj local config:

```xcconfig
DEVELOPMENT_TEAM = TGK2CZ6QA4
APP_BUNDLE_ID = com.focuslock.focuslock-app
APP_GROUP_IDENTIFIER = group.com.focuslock.focuslock-app
```

Committed defaults live in:

```text
focus-lock/Config/Shared.xcconfig
focus-lock/Config/Local.example.xcconfig
```

The entitlements use:

```xml
$(APP_GROUP_IDENTIFIER)
```

## App Group Requirements

App Groups must be enabled for:

```text
focus-lock
FocusLockDeviceActivityMonitor
```

`FocusLockShieldConfiguration` does not currently need App Groups because it only customizes the blocked screen UI and does not read saved rules.

Common App Group failure:

```text
container_create_or_lookup_app_group_path_by_app_group_identifier: client is not entitled
```

This means the running app/extension is not signed for the App Group it is trying to use.

## DeviceActivity Schedule Gotcha

Very short schedules fail.

During testing, a 1-2 minute rule failed with:

```text
MonitoringError.intervalTooShort
```

The current code uses:

```swift
FocusLockSchedule.minimumMonitorDurationMinutes = 15
```

Rules shorter than that are not registered with DeviceActivity. UI validation is not implemented yet.

Follow-up issue:

```text
#33 Add UI validation for DeviceActivity minimum rule duration
```

## Info.plist/App Group Gotcha

Runtime App Group lookup comes from the custom Info.plist key:

```text
FocusLockAppGroupIdentifier
```

The same `APP_GROUP_IDENTIFIER` build setting should feed both:

```text
Entitlements -> signing/capability access
Info.plist   -> Swift runtime lookup
```

The main app plist is `focus-lock/Config/focus-lock-Info.plist`. The DeviceActivity monitor extension plist is `focus-lock/FocusLockDeviceActivityMonitor/Info.plist`.

If those values diverge, App Group storage can fail with `client is not entitled`.

If `FocusLockAppGroupIdentifier` is missing, treat it as a project configuration bug. The app should not quietly derive an App Group from the bundle ID because that can hide signing/runtime mismatches.

## Diagnostics

Diagnostics live in:

```text
focus-lock/Shared/FocusLockDiagnostics.swift
```

They are off by default:

```swift
private static let isEnabled = false
```

Temporarily flip to `true` when debugging:

- App Group storage
- DeviceActivity schedule registration
- monitor extension callbacks

Do not leave diagnostics enabled for normal PRs unless the PR is specifically about debugging.

## Testing Guidance

Use a real iPhone for Screen Time behavior. The simulator is not reliable for FamilyControls, ManagedSettings, App Groups, or DeviceActivity enforcement.

Recommended closed-app enforcement test:

1. Delete the app from the phone if signing/capabilities changed.
2. Build/run from Xcode on the phone.
3. Create a rule starting a few minutes in the future.
4. Make the rule duration at least 15 minutes.
5. Save the rule.
6. Leave Focus Lock normally. Do not force quit.
7. Open a selected blocked app after the start time.
8. Confirm it is blocked.
9. Confirm it unblocks after the end time.

If diagnostics are enabled, look for:

```text
ScheduleManager successfully registered ...
DeviceActivityMonitor intervalDidStart fired ...
DeviceActivityMonitor applied shields.
```

## Git Hygiene

Do not commit:

```text
.DS_Store
build/
xcuserdata/
*.xcuserstate
focus-lock/Config/Local.xcconfig
```

Be careful with:

```text
focus-lock/focus-lock.xcodeproj/project.pbxproj
```

This file can contain both real project structure changes and accidental local signing churn. Review it before committing.

## Current Open Follow-ups

```text
#65 Track local outcomes for one-time simulated commitments
```

Likely future tickets:

- reduce or clean up beginner-heavy comments after both developers understand the flow
- decide whether diagnostics stay as a helper or move behind a debug build flag
- improve schedule editing and deletion UX
- add tests or lightweight debug UI for saved rules/schedules

## Recommended PR Review Order

For PR #35 and related work:

1. Read `docs/device-activity-enforcement-deep-dive.md`.
2. Review shared files in `focus-lock/Shared/`.
3. Review `DeviceActivityScheduleManager.swift`.
4. Review `DeviceActivityMonitorExtension.swift`.
5. Review `project.pbxproj` last, focusing on target wiring and entitlements.

## Working Style for Future Codex Sessions

The user is learning iOS and Swift. Prefer:

- explaining concepts slowly
- keeping comments where they teach Apple-specific behavior
- committing in small, understandable chunks
- checking `project.pbxproj` carefully before committing
- using real-device testing for Screen Time features
- documenting partner setup steps in PR descriptions

Avoid:

- hiding signing changes in large commits
- assuming simulator behavior proves Screen Time features
- committing personal local config
- force pushing unless intentionally amending a branch and using `--force-with-lease`
