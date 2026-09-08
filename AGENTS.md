# Working on Taskomatic

Native SwiftUI iPhone app. Keep the repository local; commit reviewed work without adding a remote.

## Boundaries

- `Sources/TaskomaticCore` owns task lifecycle, recurrence, and reminder planning. Inject the calendar and current date. It stays independent of SwiftUI, SwiftData, and notification delivery.
- `App/Core` adapts persistence, preferences, iCloud, and UserNotifications. Persist mutations before rescheduling reminders; report failures instead of discarding data.
- `App/Design` owns semantic colors, spacing, typography, and shared controls. Feature views compose these controls; support Dynamic Type, VoiceOver, reduced motion, and both appearances.
- User-facing text belongs in the English and French localization resources, including notifications. Keep task content in the language the user entered.

## Verification and delivery

The user delegated test decisions. Test the public task lifecycle and reminder plan with fixed, independently specified dates; use the simulator to verify creation, editing, completion, restoration, settings, and persistence. Follow one failing behavioral test with its implementation before adding the next case.

Read `docs/architecture.md` when changing persistence, backup import/export, recurrence, scheduling, or notification actions. Read `docs/development.md` for build, simulator, signing, and device commands once those workflows are established.

Before committing, request an independent code review, address actionable findings, rerun affected checks, and obtain a follow-up review. Never commit signing credentials, provisioning profiles, simulator artifacts, or personal task data.
