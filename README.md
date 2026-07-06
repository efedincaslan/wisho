# Wisho — Birthday Reminders

An iOS app that makes sure you never miss a birthday — and makes sending the wish effortless. Syncs birthdays from contacts, fires smart local notifications, opens a pre-filled iMessage with one tap. If you miss one anyway, the **Belated Rescue** follows up two days later with a graceful pre-drafted belated message.

**100% on-device.** No accounts, no server, no analytics. Your contacts never leave your phone.

## Requirements

- Xcode 15+ (iOS 17 SDK) — locally on a Mac, **or via CI (no Mac needed, see below)**
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the project: `brew install xcodegen`

## Building without a Mac

This repo ships with [.github/workflows/build.yml](.github/workflows/build.yml), which runs on GitHub's free macOS runners:

- **Every push** → full simulator build; compiler errors show up in the Actions log.
- **Manual "Run workflow"** → an unsigned device IPA artifact you can sign and install on an iPhone from Windows using [AltStore](https://altstore.io) or [SideStore](https://sidestore.io) with a free Apple ID (re-signs every 7 days; the widget/App Group may not work under free-account entitlement limits).

To ship to TestFlight/App Store without a Mac: get an Apple Developer account ($99/yr), create an App Store Connect API key, and add a signed-archive job using [fastlane](https://fastlane.tools) or [Codemagic](https://codemagic.io) — signing and upload run entirely in CI. For hands-on simulator time, rent a cloud Mac session (MacinCloud, ~$1/hr).

## Getting started

```sh
xcodegen generate
open Wisho.xcodeproj
```

Then in Xcode:

1. Select your development team on both the **Wisho** and **WishoWidget** targets.
2. If your team can't claim `com.wisho.app`, change `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` (both targets) **and** the App Group id in `Wisho/Support/AppConstants.swift` (`AppGroup.identifier`) + the `com.apple.security.application-groups` entries in `project.yml`, then re-run `xcodegen generate`.
3. Run the **Wisho** scheme. It's pre-wired to the local `Wisho.storekit` configuration, so the paywall and PRO gating are fully testable in the simulator without App Store Connect.

Test notifications quickly: add a manual person with today's date and set the send time (Settings) a couple of minutes ahead, then background the app.

## Project layout

```
Wisho/
  App/            WishoApp (entry, ModelContainer, deep-link routing), AppRouter + notification delegates
  Models/         Person, WishEvent, AppSettings (SwiftData)
  Services/
    BirthdayMath          next/last occurrence, Feb 29 handling, fire-date math
    NotificationEngine    schedules day-of / heads-up / Belated Rescue (≤60 pending, 64 is the iOS cap)
    ContactSyncService    CNContacts import + idempotent re-sync
    Maintenance           launch/foreground housekeeping (missed events, reschedule, widget reload)
    StoreManager          StoreKit 2 entitlements + free-tier gating
    MessageTemplate       {first_name} substitution, default + belated templates
  Views/          Onboarding, Home, Send Sheet (+ MessageUI wrapper, confetti), Person Detail,
                  Add Person, Settings, Paywall, shared components
WishoWidget/      WidgetKit extension (small + medium), reads the shared App Group store
project.yml       XcodeGen spec (targets, entitlements, Info.plist keys, StoreKit config scheme)
Wisho.storekit    Local StoreKit config: wisho.pro.yearly ($9.99), wisho.pro.monthly ($1.99)
```

## How the core loop works

1. **Import** — onboarding requests Contacts + Notifications, imports every contact with a birthday. Re-sync matches by `CNContact.identifier`: updates in place, never duplicates, never touches manual entries.
2. **Schedule** — `Maintenance.run` executes on every launch/foreground/data change: it records missed birthdays, then `NotificationEngine.rescheduleAll` wipes and rebuilds pending notifications from current data (soonest ~60, within the iOS cap of 64). Day-of fires at the default send time in the person's timezone; already-passed times roll to next year rather than firing immediately.
3. **Send** — tapping a notification (or Home card) deep-links to the Send Sheet with the message pre-filled. `MessageComposeResult.sent` → `WishEvent` logged, `lastWishedYear` set, confetti + haptic.
4. **Belated Rescue (PRO)** — a rescue notification is *pre-scheduled* for 2 days after each birthday at 10:00 AM, because the app may not run in between. Handling the birthday triggers a full reschedule, which cancels the pending rescue. Tapping a rescue opens the Send Sheet with the belated template.

## Feature gating

Free: 10 people, day-of notifications, full send flow.
PRO (`wisho.pro.yearly` / `wisho.pro.monthly`): unlimited people, Belated Rescue, advance reminders, per-person custom messages & timezones, widget.
Paywall triggers: 11th person, any PRO feature tap, soft prompt after first successful send.

## Before shipping

- [ ] Real app icon (`Wisho/Assets.xcassets/AppIcon.appiconset`)
- [ ] Create both subscriptions in App Store Connect with the exact product IDs above
- [ ] Real privacy policy / support URLs in `AppConstants.swift`
- [ ] App Store name "Wisho: Birthday Reminders", subtitle "Never miss a birthday again"
- [ ] Screenshots: Send Sheet first, Belated Rescue notification second
- [ ] Privacy nutrition label: **Data Not Collected**
- [ ] QA: 0 contacts, 1,000+ contacts, denied permissions, airplane mode, Feb 29 birthday
