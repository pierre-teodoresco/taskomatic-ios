@preconcurrency import BackgroundTasks
import UIKit

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
  static let refreshIdentifier = "com.pierreteodoresco.taskomatic.refresh"

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    _ = AppRuntime.shared
    BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshIdentifier, using: .main) {
      task in
      MainActor.assumeIsolated {
        let work = Task { @MainActor in
          await AppRuntime.shared.refresh()
          task.setTaskCompleted(success: !Task.isCancelled)
          Self.scheduleRefresh()
        }
        task.expirationHandler = { work.cancel() }
      }
    }
    return true
  }

  static func scheduleRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: refreshIdentifier)
    request.earliestBeginDate = Date.now.addingTimeInterval(12 * 60 * 60)
    try? BGTaskScheduler.shared.submit(request)
  }

  func application(
    _ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]
  ) async -> UIBackgroundFetchResult {
    await AppRuntime.shared.refresh()
    return .newData
  }
}
