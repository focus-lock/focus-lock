# Focus Lock MVP 1 Vision

This document captures the product thinking behind the MVP 1 tickets. It is meant to explain why the next set of work exists, not to replace the GitHub issues.

## MVP 1 Thesis

Focus Lock should not feel like a rule CRUD app that happens to block apps.

MVP 1 should feel like a trustworthy iOS focus tool that helps a user:

- choose what they want to protect
- block distracting apps, categories, and websites during the right windows
- understand what is currently being protected
- see enough screen habit context to make better rules
- trust that blocking still works when the main app is closed

The first version does not need money functionality, subscriptions, social accountability, advanced gamification, or cross-device sync. It does need a complete and understandable loop around blocking, habits, rules, and design.

## Product Pillars

### 1. Screen Blocking

Blocking is the core promise. If users do not trust it, nothing else matters.

MVP 1 should make blocking feel reliable and legible:

- selected apps, categories, and websites are blocked during active rules
- schedules work while the app is closed
- overlapping rules do not accidentally unblock shared targets
- users can tell whether Focus Lock is currently protecting them
- authorization and setup problems are shown clearly

Current foundation:

- FamilyControls app/category/website selection
- ManagedSettings shields
- custom shield UI
- DeviceActivityMonitor closed-app enforcement
- shared App Group rule storage

### 2. Screen Habits

MVP 1 should give users visibility into their behavior, not just controls.

The first useful version does not need complex analytics. It should answer:

- what happened today?
- what tends to distract me?
- am I improving or slipping?
- do my rules match my actual habits?

Apple's Screen Time APIs are privacy-preserving, so the app should use `DeviceActivityReport` where possible instead of trying to manually expose private activity identity data.

### 3. Rules

Rules should feel like a control center, not just a list.

Users should be able to understand:

- which rules are active now
- which rules are coming up
- which rules are disabled
- which rules are invalid or cannot be scheduled
- whether a rule repeats or is a one-time session

The app already treats saved rules as recurring daily rules. MVP 1 should make that explicit and add one-time behavior for temporary focus windows.

### 4. Decent Design

Design matters because trust is partly visual.

MVP 1 should be calm, clear, and iOS-native. Home should be an operational dashboard, not a marketing page. The user should be able to open the app and immediately know:

- am I protected right now?
- what happens next?
- what can I do quickly?
- is anything broken?

## Adversarial Risks

These are the failure modes to avoid:

- reliable blocking hidden behind confusing UI
- polished UI wrapped around unreliable schedules
- rule creation without status or feedback
- analytics that look fake, shallow, or disconnected from rules
- too many features before one complete daily loop feels good
- depending on Screen Time APIs we have not tested on real devices
- adding one-time sessions before shield clearing and overlapping rules are trustworthy

MVP 1 should optimize for trust before breadth.

## MVP 1 Ticket Map

### #39 Add One-Time Vs Recurring Rule Option

Existing rules are already recurring. This ticket makes recurrence explicit and adds a non-recurring option.

Recurring rule:

```text
Block social apps every day from 9 PM to 7 AM.
```

One-time rule:

```text
Block social apps today from 2 PM to 4 PM, then remove or disable the rule after it finishes.
```

This supports ad hoc focus without cluttering the rules list.

### #41 Add DeviceActivityReport Habits Screen

Adds the visibility side of MVP 1.

The goal is not perfect analytics. The goal is enough activity context for users to understand their screen habits and adjust rules.

### #42 Add Quick Focus Session

Adds immediate value from Home.

Instead of forcing users to create a permanent schedule, they can start a temporary session now. This likely builds on the one-time rule infrastructure.

### #43 Add MVP Real-Device QA Checklist

Protects us from fooling ourselves.

Screen Time behavior needs real-device testing. The checklist should cover authorization, app/category/website selection, schedule enforcement, closed-app behavior, overlapping rules, uninstall/reinstall expectations, and habits reporting.

### #44 Redesign Home As Focus Dashboard

Turns Home into the main product surface.

Home should show current protection state, next rule, today's summary, and the most important action. It should make the app feel trustworthy and useful even before the user digs into rules.

### #45 Add Rule Status And Schedule Health States

Creates the shared language that Home and Rules need.

Statuses such as Active, Upcoming, Disabled, Invalid, and Completed make the app understandable. This should avoid duplicating status logic across views.

## Recommended Build Order

1. Add rule status and schedule health states.
2. Redesign Home around those states.
3. Add one-time vs recurring rules.
4. Add quick focus sessions.
5. Add DeviceActivityReport habits.
6. Add the QA checklist in parallel or before the next major real-device testing pass.

The exact order can change, but the principle should stay the same: make the app explain what it is doing before adding more power.

## Out Of Scope For MVP 1

- money penalties or payments
- subscriptions
- friend groups or accountability partners
- leaderboards
- cross-device sync
- desktop/browser extensions
- advanced AI recommendations
- complex gamification

Those may become useful later, but they should not distract from the first complete loop.
