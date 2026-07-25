# MVP Real-Device QA Checklist

Use this checklist before calling MVP 1 releasable. Screen Time behavior must be verified on a physical iPhone; the simulator is not enough for FamilyControls, ManagedSettings, DeviceActivity, App Groups, or DeviceActivityReport.

## Setup

- [ ] Pull the latest `main`.
- [ ] Confirm `focus-lock/Config/Local.xcconfig` contains your local signing values.
- [ ] Confirm App Groups are enabled for `focus-lock` and `FocusLockDeviceActivityMonitor`.
- [ ] Clean build folder in Xcode.
- [ ] Delete the installed app if signing, entitlements, App Groups, or extension targets changed.
- [ ] Build and run on a real iPhone.

## First Launch And Authorization

- [ ] App opens directly to Home without login.
- [ ] Screen Time authorization prompt appears when access has not been granted.
- [ ] If authorization is denied, Home shows a visible Screen Time access warning.
- [ ] Create Rule, Edit Rule, and Quick Focus show the same warning when access is missing.
- [ ] After granting authorization, app/category/website selection can open.
- [ ] After revoking authorization in Settings and reopening the app, the warning appears again.

## Rule Creation

- [ ] Cannot save a rule with an empty name.
- [ ] Cannot save a rule with no apps, categories, or websites selected.
- [ ] Cannot save a scheduled rule shorter than `FocusLockSchedule.minimumMonitorDurationMinutes`.
- [ ] Cannot save a usage-limit rule shorter than `FocusLockSchedule.minimumMonitorDurationMinutes`.
- [ ] Cannot save a one-time rule whose end time has already passed.
- [ ] Recurring rules save with the expected selected weekdays.
- [ ] One-time rules save with the expected selected date.
- [ ] Category selection blocks apps from the selected category.
- [ ] Website selection blocks the selected websites if available on the test device.

## Home

- [ ] Empty state is clear before any rules exist.
- [ ] Home shows `No active block` when nothing is active.
- [ ] Home shows `Next block is scheduled` for the next upcoming scheduled rule.
- [ ] Home shows `Protected now` during an active scheduled rule.
- [ ] Today stats update for active, enabled, and scheduled rules.
- [ ] Long rule names wrap without overlapping buttons or cards.
- [ ] Start Focus opens the Quick Focus sheet.
- [ ] Create Rule opens the full rule creation sheet.

## Rules

- [ ] Empty state is clear before any rules exist.
- [ ] Active rules sort above inactive rules.
- [ ] Invalid rules show a `Needs attention` state and a readable reason.
- [ ] Disabled rules show as disabled and do not block.
- [ ] Rule toggle updates shields immediately.
- [ ] Editing a scheduled rule updates schedules and shields.
- [ ] Editing a usage-limit rule resets that day's reached state.
- [ ] Deleting a rule clears its shields unless another active rule still covers the same app/category/website.
- [ ] Completed one-time rules disappear after completion and app refresh.

## Quick Focus

- [ ] Start button is disabled until at least one app, category, or website is selected.
- [ ] 15-minute quick focus starts immediately.
- [ ] Selected apps block immediately.
- [ ] Quick Focus appears in Rules as an active one-time rule.
- [ ] Closing the app normally does not stop the block.
- [ ] Quick Focus ends automatically.
- [ ] Completed Quick Focus rule is cleaned up from Rules.
- [ ] Overlapping Quick Focus and scheduled rules do not unblock shared selected items too early.

## Closed-App Enforcement

- [ ] Create a scheduled rule that starts a few minutes in the future and lasts at least 15 minutes.
- [ ] Leave Focus Lock normally. Do not force quit.
- [ ] Open a selected app after the start time; it should be blocked.
- [ ] Open a selected app after the end time; it should be unblocked unless another rule still covers it.
- [ ] Repeat with overlapping rules that block the same app.
- [ ] Repeat with category selection.
- [ ] Repeat after phone lock/unlock.
- [ ] Repeat after device restart if time allows.

## Usage Limits

- [ ] Usage-limit rule saves with selected apps/categories/websites.
- [ ] Usage-limit rule shows as available before the limit is reached.
- [ ] `Block for Today` manually blocks the selection for the rest of the day.
- [ ] Usage-limit reached state clears on a later day.
- [ ] Editing the usage limit resets today's reached state.

## Habits

- [ ] Habits tab renders Today.
- [ ] Habits tab renders Week.
- [ ] Habits tab renders Month.
- [ ] Weekly and monthly loading delay is acceptable with the loading message visible.
- [ ] App rows show icon, name, pickups, notifications, and duration.
- [ ] Long app names stay aligned and readable.
- [ ] The final visible app rows are not hidden by the floating tab bar.
- [ ] Switching Today/Week/Month does not leave stale report data permanently on screen.

## Install, Persistence, And Reinstall

- [ ] Rules persist after closing and reopening the app.
- [ ] Rules persist after a normal app update/install over the existing app.
- [ ] Deleting the app removes local app data unless iOS/App Group behavior keeps shared container data for the current install path.
- [ ] If old rules unexpectedly remain after reinstall, disable/delete rules and verify shields clear.
- [ ] App does not appear stuck as newly installed after normal reinstall.

## Shield Screen

- [ ] Blocked app shows the custom Focus Lock shield screen.
- [ ] Shield copy does not mention money in MVP 1.
- [ ] Shield screen looks acceptable in light and dark mode.
- [ ] Shield screen remains readable for long app names if iOS provides them.

## Final Pass

- [ ] Test in light mode.
- [ ] Test in dark mode.
- [ ] Test with large text if time allows.
- [ ] Check for obvious clipping on the smallest available test phone.
- [ ] Confirm `FocusLockDiagnostics.isEnabled` is `false`.
- [ ] Confirm no personal `Local.xcconfig`, signing churn, or Xcode user state is staged.
- [ ] Record known limitations in the PR before merging.
