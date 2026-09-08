# Development workflow

## Tools and project

Use Xcode 26 or newer with Swift 6. The deployment target is iOS 17. The repository has no external runtime dependency; `TaskomaticCore` is a local Swift package. XcodeGen 2.44+ regenerates the checked-in project after `project.yml` changes:

```sh
xcodegen generate
swift test
```

Run `scripts/verify.sh SIMULATOR_UUID` to execute domain, storage, and UI checks. Logs and build products belong under ignored `DerivedData` directories. `swift format format --in-place --recursive App Sources Tests TaskomaticTests TaskomaticUITests` applies the Swift toolchain formatter.

## Simulator

```sh
xcrun simctl list devices available
xcrun simctl boot SIMULATOR_UUID
open -a Simulator
./scripts/verify.sh SIMULATOR_UUID
```

Debug simulator builds use a local SwiftData store. The `--ui-testing` launch argument selects a dedicated store and preferences suite. `--reset-test-store` resets the test store, test preferences, and this simulator app’s pending/delivered notification fixtures. These arguments are compiled out of physical-device and release behavior. Never seed the user's phone with test tasks.

## Connected iPhone

Find the device with `xcrun devicectl list devices`. Use a local shell variable `IOS_DEVICE_ID` for the returned identifier. To install using a free Personal Team:

```sh
xcodebuild -project Taskomatic.xcodeproj -scheme TaskomaticLocal -configuration Local \
  -destination 'generic/platform=iOS' -derivedDataPath DerivedData-local \
  -allowProvisioningUpdates build
xcrun devicectl device install app --device "$IOS_DEVICE_ID" \
  DerivedData-local/Build/Products/Local-iphoneos/Taskomatic.app
xcrun devicectl device process launch --device "$IOS_DEVICE_ID" com.pierreteodoresco.taskomatic
```

If installation succeeds but launch reports an untrusted profile, approve the developer profile on the iPhone under Settings → General → VPN & Device Management. This cannot be approved by the app. The initial local profile expires on 15 September 2026 (Paris time); rebuild/reinstall to renew it.

Keep device profiles, certificates, credentials, and `Config/Local.xcconfig` out of Git. The checked-in team identifier can be changed in `project.yml` when using another development team. `Config/Local.entitlements` must stay separate from the CloudKit entitlements; a generated target-wide entitlements declaration would override the Local configuration.

## Enable and validate iCloud

1. Select an active Apple Developer Program team. Set its ID in `project.yml`, regenerate, and use the Taskomatic scheme.
2. Enable the private container `iCloud.com.pierreteodoresco.taskomatic` and configure a provisioning profile with CloudKit and push capabilities.
3. On signed devices using the same Apple account, create/edit/complete/delete tasks and verify propagation in both directions, including offline edits and simultaneous changes. Check iCloud sign-out/account-switch behavior separately.
4. Initialize and inspect the development schema in CloudKit Console. Before TestFlight, deploy that schema to production; deployment copies schema, not development records. Production schema changes must remain additive.
5. Test a production/TestFlight build against production CloudKit. Availability of the Apple account alone is not evidence of successful synchronization.

Apple references: [SwiftData synchronization](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices), [CloudKit troubleshooting](https://developer.apple.com/documentation/technotes/tn3164-debugging-the-synchronization-of-nspersistentcloudkitcontainer), [TestFlight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview).

## Files and iCloud Drive backup verification

The manual exporter/importer works in Local builds. Test with disposable simulator tasks: export from Settings to On My iPhone, inspect the JSON with `TaskBackup.decode`, restore a file containing missing tasks, verify the preview and success message, then relaunch. The storage tests separately verify preservation of existing tasks, repeated imports, rotated notification tokens and rollback with a genuinely read-only store.

For a real iCloud Drive check, choose iCloud Drive in the system exporter on an authenticated device, wait for Files to finish uploading, then download and restore that file on another authenticated device. The simulator used on 8 September 2026 was signed out of iCloud; the provider correctly requested sign-in. Its successful local Files round trip does not prove cloud upload or multi-device synchronization. CloudKit provisioning was also retested and explicitly rejected for the current Personal Team. These are separate integration paths and validation limits.

## Localization and visual changes

Add matching keys to `App/Resources/en.lproj/Localizable.strings` and `fr.lproj/Localizable.strings`. For another language, add its `.lproj` resource, `AppLanguage` case, settings label, and `knownRegions` entry. The system preference falls back to the app's development language. Translate UI and notification templates; never translate user-entered task content.

Use semantic colors and shared controls in `App/Design`. Validate light and dark appearances, large accessibility text, keyboard presentation, and narrow screens. The icon is original vector artwork generated by `swift scripts/generate-icon.swift`; its PNG is checked in.
