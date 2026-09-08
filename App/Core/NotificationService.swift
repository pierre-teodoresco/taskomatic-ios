import Foundation
import Observation
import TaskomaticCore
@preconcurrency import UserNotifications

@MainActor @Observable
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
  private let center = UNUserNotificationCenter.current()
  private var worker: Task<Void, Never>?
  private(set) var authorization: UNAuthorizationStatus = .notDetermined
  private(set) var plan: ReminderPlan?
  private(set) var error: Error?
  var onComplete: ((UUID, String) async -> Void)?

  override init() {
    super.init()
    center.delegate = self
  }

  func refreshAuthorization() async {
    authorization = await center.notificationSettings().authorizationStatus
  }

  func requestAuthorization() async -> Bool {
    do {
      let granted = try await center.requestAuthorization(options: [.alert, .sound])
      await refreshAuthorization()
      return granted
    } catch {
      self.error = error
      return false
    }
  }

  func reschedule(tasks: [TaskItem], schedule: ReminderSchedule, strings: AppStrings) async {
    guard !Task.isCancelled else { return }
    let previous = worker
    previous?.cancel()
    let next = Task { [weak self] in
      await previous?.value
      guard !Task.isCancelled, let self else { return }
      await self.replace(tasks: tasks, schedule: schedule, strings: strings)
    }
    worker = next
    await withTaskCancellationHandler {
      await next.value
    } onCancel: {
      next.cancel()
    }
  }

  private func replace(tasks: [TaskItem], schedule: ReminderSchedule, strings: AppStrings) async {
    await refreshAuthorization()
    guard !Task.isCancelled else { return }
    let action = UNNotificationAction(
      identifier: "complete", title: strings("notification.complete"),
      options: [.authenticationRequired])
    center.setNotificationCategories([
      UNNotificationCategory(identifier: "single-task", actions: [action], intentIdentifiers: [])
    ])
    let authorized = [.authorized, .provisional, .ephemeral].contains(authorization)
    let nextPlan =
      schedule.enabled && authorized
      ? ReminderPlan.make(tasks: tasks, schedule: schedule, now: .now, calendar: .current) : nil
    let requests = (nextPlan?.reminders ?? []).map { reminder in
      let components: DateComponents
      let repeats: Bool
      switch reminder.trigger {
      case .daily:
        components = DateComponents(hour: schedule.hour, minute: schedule.minute)
        repeats = true
      case .weekly(let weekday):
        components = DateComponents(hour: schedule.hour, minute: schedule.minute, weekday: weekday)
        repeats = true
      case .once(let date):
        components = Calendar.current.dateComponents(
          [.year, .month, .day, .hour, .minute], from: date)
        repeats = false
      }
      return UNNotificationRequest(
        identifier: "taskomatic.\(reminder.id)",
        content: content(for: reminder.summary, strings: strings),
        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats))
    }
    do {
      try await NotificationReconciler.replace(
        requests, in: SystemNotificationQueue(center: center))
      center.removeAllDeliveredNotifications()
      plan = nextPlan
      error = nil
    } catch {
      // A partial renewal must not advertise coverage that has not been verified.
      plan = nil
      self.error = error
    }
  }

  private func content(for summary: ReminderSummary, strings: AppStrings)
    -> UNMutableNotificationContent
  {
    let content = UNMutableNotificationContent()
    content.sound = .default
    content.threadIdentifier = "taskomatic.daily"
    switch summary.count {
    case 1:
      content.title = strings("notification.single.title")
      content.body = trimmedTitle(summary.titles.first ?? "")
      if let id = summary.taskIDs.first, let cycle = summary.singleTaskCycle {
        content.categoryIdentifier = "single-task"
        content.userInfo = ["taskID": id.uuidString, "cycle": cycle]
      }
    case 2:
      content.title = strings("notification.two.title")
      content.body = summary.titles.map { "• " + trimmedTitle($0) }.joined(separator: "\n")
    default:
      content.title = strings("notification.many.title")
      content.body = strings("notification.many.body", summary.count)
    }
    return content
  }

  private func trimmedTitle(_ title: String) -> String {
    let title = title.split(whereSeparator: \.isNewline).joined(separator: " ")
    return title.count > 140 ? String(title.prefix(139)) + "…" : title
  }

  func sendTest(strings: AppStrings) async -> Bool {
    let content = UNMutableNotificationContent()
    content.title = strings("notification.test.title")
    content.body = strings("notification.test.body")
    content.sound = .default
    do {
      try await center.add(
        UNNotificationRequest(
          identifier: "taskomatic.test", content: content,
          trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
      return true
    } catch {
      self.error = error
      return false
    }
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .sound]
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
  ) async {
    guard response.actionIdentifier == "complete",
      let rawID = response.notification.request.content.userInfo["taskID"] as? String,
      let id = UUID(uuidString: rawID),
      let cycle = response.notification.request.content.userInfo["cycle"] as? String
    else { return }
    await handleCompletion(id: id, cycle: cycle)
  }

  private func handleCompletion(id: UUID, cycle: String) async { await onComplete?(id, cycle) }
}
