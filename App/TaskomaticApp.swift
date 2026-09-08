import SwiftData
import SwiftUI

@main
struct TaskomaticApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
  @Environment(\.scenePhase) private var scenePhase
  @State private var runtime = AppRuntime.shared

  var body: some Scene {
    WindowGroup {
      Group {
        if let store = runtime.store {
          HomeView()
            .environment(store)
            .task(id: store.revision) { await runtime.reschedule() }
        } else {
          VStack(spacing: 20) {
            BrandMark(size: 48)
            Text(runtime.settings.strings("error.storage.title")).font(.title2.weight(.semibold))
            Text(runtime.settings.strings("error.storage.body")).foregroundStyle(Theme.secondary)
            PrimaryButton(title: runtime.settings.strings("error.retry")) { runtime.loadStore() }
          }.multilineTextAlignment(.center).padding(32)
        }
      }
      .environment(runtime)
      .environment(runtime.settings)
      .environment(\.locale, runtime.settings.strings.locale)
      .preferredColorScheme(runtime.settings.appearance.colorScheme)
      .tint(Theme.accent)
      .task { await runtime.refresh() }
      .task(id: configurationKey) { await runtime.reschedule() }
      .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
        Task { await runtime.refresh() }
      }
      .onReceive(
        NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
      ) { _ in
        Task { await runtime.refresh() }
      }
      .onChange(of: scenePhase) { _, phase in
        if phase == .active { Task { await runtime.refresh() } }
        if phase == .background { AppDelegate.scheduleRefresh() }
      }
    }
  }

  private var configurationKey: String {
    let settings = runtime.settings
    return
      "\(settings.remindersEnabled)-\(settings.reminderHour)-\(settings.reminderMinute)-\(settings.weekdays.sorted())-\(settings.language)"
  }
}
