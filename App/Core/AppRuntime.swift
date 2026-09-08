import CloudKit
import SwiftData
import SwiftUI
import TaskomaticCore
import UserNotifications

@MainActor @Observable
final class AppRuntime {
  static let shared = AppRuntime()
  let settings: AppSettings
  let notifications = NotificationService()
  private(set) var store: TaskStore?
  private(set) var storageError: Error?
  private(set) var cloudAvailable: Bool?
  let isolated: Bool
  let cloudEnabled: Bool

  private init() {
    #if LOCAL_ONLY || targetEnvironment(simulator)
      cloudEnabled = false
    #else
      cloudEnabled = true
    #endif
    #if DEBUG && targetEnvironment(simulator)
      isolated = true
      let arguments = ProcessInfo.processInfo.arguments
      if arguments.contains("--ui-testing") {
        let name = "com.pierreteodoresco.taskomatic.uitests"
        if arguments.contains("--reset-test-store") {
          UserDefaults.standard.removePersistentDomain(forName: name)
          // Reset notification fixtures only for the explicitly isolated simulator test store.
          UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
          UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        }
        settings = AppSettings(defaults: UserDefaults(suiteName: name)!)
        settings.reminderPromptDismissed = true
      } else {
        settings = AppSettings()
      }
    #else
      isolated = false
      settings = AppSettings()
    #endif
    loadStore()
    notifications.onComplete = { [weak self] id, cycle in
      guard let self, let store = self.store else { return }
      do {
        try store.complete(id: id, expectedCycle: cycle)
        await self.reschedule()
      } catch { store.error = error }
    }
  }

  func loadStore() {
    do {
      let schema = Schema([TaskRecord.self])
      let configuration: ModelConfiguration
      #if DEBUG && targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        let filename =
          arguments.contains("--ui-testing")
          ? "TaskomaticUITests.store" : "TaskomaticSimulator.store"
        let directory = URL.applicationSupportDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: filename)
        if arguments.contains("--ui-testing") && arguments.contains("--reset-test-store") {
          for suffix in ["", "-shm", "-wal"] {
            let path = url.path + suffix
            if FileManager.default.fileExists(atPath: path) {
              try FileManager.default.removeItem(atPath: path)
            }
          }
        }
        configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
      #else
        configuration = ModelConfiguration(
          schema: schema,
          cloudKitDatabase: cloudEnabled
            ? .private("iCloud.com.pierreteodoresco.taskomatic") : .none)
      #endif
      let container = try ModelContainer(for: schema, configurations: [configuration])
      store = try TaskStore(container: container)
      storageError = nil
    } catch { storageError = error }
  }

  func refresh() async {
    if let store {
      do { try store.reload() } catch { store.error = error }
    }
    await notifications.refreshAuthorization()
    guard !Task.isCancelled else { return }
    await reschedule()
    guard !Task.isCancelled else { return }
    if cloudEnabled {
      cloudAvailable =
        (try? await CKContainer(identifier: "iCloud.com.pierreteodoresco.taskomatic")
          .accountStatus()) == .available
    }
  }

  func reschedule() async {
    guard let store else { return }
    let schedule = ReminderSchedule(
      enabled: settings.remindersEnabled, hour: settings.reminderHour,
      minute: settings.reminderMinute, weekdays: settings.weekdays)
    await notifications.reschedule(
      tasks: store.items, schedule: schedule, strings: settings.strings)
  }
}
