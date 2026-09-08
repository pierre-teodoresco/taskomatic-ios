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
