import Foundation
import TaskomaticCore
import Testing

struct TaskLifecycleTests {
  @Test func completedSimpleTaskStaysArchived() {
    let task = TaskItem(title: "Book a table", completedAt: Date(timeIntervalSince1970: 1_000))
    #expect(
      !task.isActive(
        at: Date(timeIntervalSince1970: 2_000_000), calendar: Calendar(identifier: .gregorian)))
  }

  @Test func recurringTaskBecomesActiveWithoutAnAppLaunchOrMutation() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let parser = ISO8601DateFormatter()
    let task = TaskItem(
      title: "Change sheets", completedAt: parser.date(from: "2026-09-10T18:00:00Z")!,
      recurrence: Recurrence(interval: 1, unit: .week))
    #expect(!task.isActive(at: parser.date(from: "2026-09-16T23:59:59Z")!, calendar: calendar))
    #expect(task.isActive(at: parser.date(from: "2026-09-17T00:00:00Z")!, calendar: calendar))
    #expect(task.isActive(at: parser.date(from: "2027-01-01T00:00:00Z")!, calendar: calendar))
  }

  @Test func restoringATaskInvalidatesAnOldNotificationAction() {
    var task = TaskItem(title: "Coffee")
    let oldNotificationToken = task.cycleToken
    task.complete(at: Date(timeIntervalSince1970: 1000))
    task.restore()
    #expect(task.cycleToken != oldNotificationToken)
  }
}
