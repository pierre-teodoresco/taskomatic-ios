# Independent review

An independent agent reviewed the application before the first commit. The first pass requested four corrections:

| Finding | Correction | Evidence |
| --- | --- | --- |
| Midnight DST could carry 01:00 into the next day | Normalize the destination with `Calendar.startOfDay` | A Santiago regression test failed before the correction |
| Completing or undoing could overwrite later edits | Apply targeted mutations in a fresh SwiftData context; undo changes completion only | A two-context storage test reproduced the lost title before the correction |
| Restoring/undoing reused an old notification token | Persist and rotate a cycle UUID on completion, restoration, and undo | A domain test reproduced token reuse; storage tests exercise stale action rejection |
| Background expiration did not cancel the notification worker | Forward cancellation with `withTaskCancellationHandler` and check between asynchronous operations | Follow-up code review verifies the cancellation path |

The local notification horizon and unavailable paid CloudKit provisioning are documented delivery limitations, not claims of completed cloud validation. The second pass requested preservation of the pending notification reserve during cancellation and wording appropriate to the local-only build. A regression test reproduced the reserve dropping from 60 requests to 2 before the fix. Queue reconciliation now preserves existing requests until replacements exist, respects the system capacity, keeps the preview separate, and converges after a retry. The local deletion dialog now describes deletion from this iPhone. Final follow-up and test results are recorded below.

## Final verification — 8 September 2026

The final independent review reported no remaining actionable findings. The reviewer checked the cancellation/queue changes, local deletion wording, editor toolbar save, icon rendering, formatting, configuration files, and all 112 matching localized keys and placeholders.

- Swift package: 14 behavioral tests passed.
- Simulator storage and notification queue: 5 XCTest tests passed.
- iPhone 17 / iOS 26.5: 4 UI tests passed, including task persistence, recurring task editing/completion, language/appearance persistence, and real notification delivery with the app backgrounded.
- Swift formatting and plist/resource validation passed.
- Signed Local configuration built successfully; code signature validated and application installed on the connected iPhone. Initial launch was rejected by device security pending developer profile trust on the phone.

The recurring-task UI test also exposed a save button hidden by the keyboard. Moving Save into the navigation toolbar resolved the regression; the full UI suite then passed.

The final visual pass on iPhone SE (iOS 18.2) at accessibility-extra-extra-large text exposed a wrapped filter label. The filter control now uses a vertical layout at accessibility sizes, with explicit 44-point touch areas. The independent reviewer approved this delta; the small-screen build, screenshot verification, and creation/completion/restoration/relaunch UI test passed. The signed Local build was rebuilt and reinstalled after this change.

## Settings appearance regression

A user reported that repeated theme changes updated the home screen while the open settings sheet retained its previous appearance. A UI regression test reproduced this by measuring the rendered sheet gutter: Clair was selected but the sheet remained dark. The fix forwards the presenting window's resolved color scheme into the settings presentation. It also handles returning to System without recreating the sheet.

The independent reviewer approved the revised fix and requested that System restoration start from the opposite explicit mode, so the test requires a visible transition under either system appearance. That improvement is included. The repeated-toggle/System test and existing language/appearance persistence test passed on iPhone 17 / iOS 26.5; captured light and dark sheet renders were inspected.

The same regression test passed on iPhone SE / iOS 18.2 with the system set to dark, covering restoration in both directions. The signed Local configuration built successfully and the updated application was installed on the connected iPhone.

## Quick-add keyboard dismissal

A failing UI test reproduced the keyboard staying open when the page above quick add was tapped. The page scroll view now clears only quick-add focus through a simultaneous tap gesture, preserving the draft and allowing existing controls to act. The composer is outside the gesture area. The regression test verifies dismissal without insertion, draft retention, resumed typing, filter interaction, and one explicit task insertion. This test and the existing task lifecycle and recurring-task UI tests passed on iPhone 17 / iOS 26.5. The independent review reported no actionable findings.

## Notification visibility

The independent review identified two concrete visibility defects: routine rescheduling erased every delivered notification, including the test, and foreground presentation omitted the Notification Center list. Removing the blanket deletion and requesting `.list` preserves received notifications. `sendTest` now refreshes authorization before scheduling, and both translations describe scheduling rather than promise banner delivery.

A foreground banner test passed before the change, establishing that the delegate worked on the simulator. Extending it to check Notification Center after reopening the app failed before the fix. The completed foreground/retention and background delivery tests both passed on iPhone 17 / iOS 26.5. An intermediate run was interrupted by a simulator test-runner SIGTERM/XPC failure; the successful run used a restarted simulator. Explicit simulator fixture reset also clears pending/delivered notifications so an old preview cannot satisfy a new test. The independent follow-up found no actionable issues.

The connected iPhone was inspected through the app’s notification API: authorization, banners, sounds, lock screen, and Notification Center were enabled; scheduled delivery was disabled; the NotificationService delegate was present. The debugger was detached. These findings do not establish why the user missed the physical-device banner; Focus status remained an unanswered diagnostic question.

## Recurrence selection touch area

A UI regression test reproduced the recurrence picker ignoring taps in a row's empty trailing area. The shared `SelectionRow` now defines a rectangular touch target across its padded width. Selected options use the semantic accent background and foreground, a checkmark, and the selected accessibility trait. The picker keeps its existing immediate return after selection.

The regression verifies both trailing space and leading padding, then reopens the picker to confirm the selected state. It and the existing recurring-task creation/completion test passed on iPhone 17 / iOS 26.5. The selection test also passed in dark appearance, and both captured renders were inspected. The independent review and follow-up found no actionable issues and verified selected-text contrast in both appearances. The signed Local build succeeded and was installed and launched on the connected iPhone.

## Version 1.1 — backup and usability review

Three independent review passes covered task flows, storage, Files integration, error handling, accessibility and translations. Findings drove these changes:

- Quick-add drafts survive opening and cancelling the detailed editor; successful creation returns to the active filter.
- Editing an active task's recurrence no longer silently archives or postpones it. A completion made by another context since the editor opened is preserved.
- Failed Undo remains available after its original six-second timeout. A failed refresh after a successful save is distinguished from a failed write, preventing an invitation to insert a duplicate.
- Controls use a semantic foreground on accent: contrast is 5.52:1 in light appearance and 6.86:1 in dark appearance. Reminder days have adaptive, at least 44-point targets and fuller weekday labels; language selection has a visible label.
- Unsaved editor changes require an explicit discard, and sheet gestures preserve them. iOS 26 omitted the role-cancel button in its compact confirmation popover; a normal Keep Editing action fixes the verified omission.

The versioned backup format preserves all task states and rejects invalid or oversized files before writing. A real disk-store test verifies restoration, existing-edit preservation, repeat-import idempotence and fresh cycle tokens after relaunch. A read-only store produces a real save failure and leaves both tasks and disk unchanged. Independent follow-up approved the bounded, coordinated security-scoped reader and the import success message deferred until preview dismissal.

The system Files exporter produced a valid JSON document and showed its success message. A disposable import probe selected that exported file with added missing-task fixtures through Files, confirmed the preview, restored two tasks, observed the success alert and verified the new task on Home. The probe was removed rather than commit a test depending on an external simulator file. iCloud Drive requested account sign-in on the simulator, and CloudKit provisioning was rejected for the Personal Team; neither remote upload nor automatic CloudKit sync is claimed as validated.

Final checks: 17 Swift package tests and 9 storage/notification-queue tests passed. All 12 iPhone 17 / iOS 26.5 UI cases passed, covering the existing flows plus draft preservation, explicit discard/deletion choices and persisted custom recurrence. The full run initially passed 11 UI cases; the remaining test queried a StaticText where the native Stepper exposes its label. Correcting that test query and rerunning the case passed without a production change. Swift formatting, resource validation, all 139 matching English/French keys and placeholders, and `git diff --check` passed. The final independent code follow-up found no actionable issue.

The signed Local build, version 1.1.0 (2), passed code-signature verification and was installed and launched on the connected iPhone. Device app inventory confirmed the version. Simulator fixture resets and backup probes did not touch the physical device's task store.

The final iPhone SE / iOS 18.2 visual pass used dark appearance and accessibility-extra-extra-large text. It confirmed readable reminder-day targets, backup actions and custom recurrence controls, and exposed word fragmentation in the language row. That row now stacks its label above the picker at accessibility sizes. The follow-up reviewer approved this delta; fresh captures and the language/appearance persistence UI test passed. The disposable visual probe was removed, and the signed app was rebuilt, signature-verified, reinstalled and launched with this last correction.
