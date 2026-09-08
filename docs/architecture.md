# Product and architecture

## Product rules

Tasks have a title and optional note, with no deadline. Tapping the page above quick add dismisses the keyboard and preserves the current draft; only explicit submission creates a task. A simple completed task is archived and can be restored. A recurring task is active immediately on creation. Completing it records the completion instant; its next activation is the start of the local calendar day N days, weeks, or calendar months later. Month-end dates clamp to the last valid day. Missed cycles never accumulate.

Activity is derived from persisted completion and recurrence values when queried, rather than requiring a background mutation at midnight. A task remains active until explicitly completed. Recurring tasks retain the latest completion, not a completion journal.

The reminder schedule has one local hour and a selection of weekdays. Summaries list titles when one or two tasks are active and use a count for larger lists. A single-task notification may offer completion, guarded against a stale task cycle. Zero active tasks produce no task reminder.

## Verification boundaries

The implementation authority and choice of necessary tests were delegated by the user. Automated domain tests cover task activity and reminder plans through their public interfaces. Calendar expectations use worked examples, including leap years and daylight saving. UI tests exercise the real app with an isolated local store so test data never enters iCloud or the user's phone.

## Persistence

SwiftData stores CloudKit-compatible records with defaults and optional completion values. Domain snapshots keep SwiftData out of policy code. iCloud uses a private database per Apple account. Cloud synchronization is eventual; it is not a versioned backup. Each mutation reads a fresh SwiftData context and only changes its owned fields. The editor applies differences against its original snapshot, so a completion or unrelated note edit from another context survives. Undo restores only completion state and rejects a superseded cycle. Every completion, restoration, and undo rotates a persisted cycle UUID; old notification actions cannot complete a later cycle.

The Local configuration omits CloudKit capabilities for Personal Team signing. It uses the same bundle identifier and on-device store location. Real CloudKit synchronization remains unvalidated until a paid team provisions the container; account availability alone is not synchronization status.

### Portable backups

`TaskBackup` is the versioned JSON boundary: a format identifier, version, export date, and every task state, including notes and archived tasks. Dates use milliseconds since the Unix epoch. Validate the entire document before constructing a usable backup: unique UUIDs, nonempty titles, dates in the supported range, recurrence units and intervals 1...99. Cap documents at 10 MiB and 10,000 tasks.

The Settings export reads a fresh database snapshot and passes a `BackupDocument` to the system exporter. The user can choose iCloud Drive or another Files provider without an app CloudKit entitlement. An export callback confirms a file was written, not that a provider finished uploading it. Imports coordinate security-scoped file access off the main actor and offer a preview before writing.

Restoration adds only IDs absent from a fresh context at confirmation time. Existing task content and completion remain authoritative; reminder preferences remain local. Imported tasks receive new cycle UUIDs, invalidating old notification actions. One save commits all additions; a save failure rolls back. A post-commit refresh error is reported separately so a successful insertion is never offered as a failed operation to repeat. Reimporting the same file is idempotent within the local store. Independent offline imports on two CloudKit devices remain an unvalidated duplicate-record risk and must be resolved before claiming multi-device import guarantees.

Changing the recurrence of a currently active task preserves its active state, using the fresh record rather than the editor snapshot. An older completion that would otherwise archive or postpone it is cleared and its cycle token rotates. A task completed by another context since the editor opened keeps that completion.

## Reminder delivery

Local notification delivery is handled by iOS, even while the app is closed. A stable active task set uses indefinite repeating calendar triggers. If a dormant recurring task changes a future summary, the planner prepares up to 60 dated requests. The settings screen displays the coverage date. Background refresh is an opportunistic renewal mechanism, not an execution guarantee: continuity after exhausting that reserve without reopening the app would require a server and remains a product limitation awaiting confirmation.

`NotificationReconciler` is the system-queue boundary. It replaces stable identifiers in place, adds before removing obsolete requests, and frees a single obsolete slot only when necessary to stay within 64 pending requests (including one preview). Cancellation or an add failure preserves the remaining reserve; a later renewal converges to the desired set. The service serializes workers, forwards caller cancellation, rejects already-cancelled callers, and clears its displayed coverage after partial failure. Disabling reminders explicitly reconciles to an empty set. The preview request is independent. Rescheduling leaves delivered notifications intact; their history remains available until the user dismisses it. Foreground delivery requests banner, Notification Center list, and sound. Successful test scheduling is not proof that iOS displayed a banner: authorization, presentation settings, and Focus are separate concerns.

Foreground, significant time changes, successful mutations, and remote changes rebuild the plan. Recurrence and calendar triggers use local calendar days; the pure domain accepts an injected calendar to verify DST and month-end behavior.

## Visual direction

Restrained, contemporary interface: off-white and slate, indigo accent, graphite dark appearance, precise type hierarchy, quiet surfaces, concise motion, and subtle haptics. Mobbin references: Things 3 (724087de-2e95-47ec-926c-efbdab249a23) and Linear Mobile (30ebc468-06c8-46dd-9503-e197e89a1e5c). These references inform layout, not copied assets.

The main window resolves the user's light/dark/system preference. The settings sheet receives the window's resolved `colorScheme` explicitly, so changes reach an already-open presentation. Forwarding a nullable preference to the sheet left System restoration stale on iOS 26.5; keep the presentation's identity and state while updating the resolved scheme.
