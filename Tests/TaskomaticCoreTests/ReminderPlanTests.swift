import Foundation
import TaskomaticCore
import Testing

struct ReminderPlanTests {
  private var utc: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
  }

  @Test func unfinishedSimpleTasksHaveAnIndefinitelyRepeatingCommonReminder() {
    let now = ISO8601DateFormatter().date(from: "2026-09-08T10:00:00Z")!
    let tasks = [TaskItem(title: "Call the garage"), TaskItem(title: "Buy coffee")]
    let plan = ReminderPlan.make(
      tasks: tasks, schedule: ReminderSchedule(), now: now, calendar: utc)
    #expect(plan.reminders.count == 1)
    #expect(plan.reminders.first?.trigger == .daily)
    #expect(plan.reminders.first?.summary.titles == ["Call the garage", "Buy coffee"])
    #expect(plan.repeatsIndefinitely)
  }

  @Test func sleepingRecurringTaskIsRemindedOnReturnWithoutOpeningTheApp() {
    let parser = ISO8601DateFormatter()
    let now = parser.date(from: "2026-09-08T10:00:00Z")!
    let task = TaskItem(
      title: "Change sheets", completedAt: now, recurrence: Recurrence(interval: 1, unit: .week))
    let plan = ReminderPlan.make(
      tasks: [task], schedule: ReminderSchedule(), now: now, calendar: utc, limit: 3)
    #expect(
      plan.reminders.map(\.trigger) == [
        .once(parser.date(from: "2026-09-15T09:00:00Z")!),
        .once(parser.date(from: "2026-09-16T09:00:00Z")!),
        .once(parser.date(from: "2026-09-17T09:00:00Z")!),
      ])
    #expect(plan.reminders.first?.summary.titles == ["Change sheets"])
  }

  @Test func summaryChangesOnFutureReturnAndHonorsSelectedWeekdays() {
    let parser = ISO8601DateFormatter()
    let now = parser.date(from: "2026-09-11T10:00:00Z")!  // Friday
    let tasks = [
      TaskItem(title: "Buy coffee"),
      TaskItem(
        title: "Water plants", completedAt: now, recurrence: Recurrence(interval: 3, unit: .day)),
      TaskItem(title: "Book a table", completedAt: now),
    ]
    let plan = ReminderPlan.make(
      tasks: tasks, schedule: ReminderSchedule(weekdays: [2, 6]), now: now, calendar: utc, limit: 2)
    #expect(
      plan.reminders.map(\.trigger) == [
        .once(parser.date(from: "2026-09-14T09:00:00Z")!),
        .once(parser.date(from: "2026-09-18T09:00:00Z")!),
      ])
    #expect(plan.reminders.first?.summary.titles == ["Buy coffee", "Water plants"])
  }

  @Test func noOpenTasksOrDisabledRemindersProduceNoNotifications() {
    let now = Date(timeIntervalSince1970: 1_000)
    let completed = TaskItem(title: "Done", completedAt: now)
    #expect(
      ReminderPlan.make(tasks: [completed], schedule: ReminderSchedule(), now: now, calendar: utc)
        .reminders.isEmpty)
    #expect(
      ReminderPlan.make(
        tasks: [TaskItem(title: "Open")], schedule: ReminderSchedule(enabled: false), now: now,
        calendar: utc
      ).reminders.isEmpty)
  }

  @Test func largeSummaryUsesACountAndCannotCompleteMultipleTasks() {
    let summary = ReminderSummary(tasks: [
      TaskItem(title: "A"), TaskItem(title: "B"), TaskItem(title: "C"),
    ])
    #expect(summary.count == 3)
    #expect(summary.titles.isEmpty)
    #expect(summary.singleTaskCycle == nil)
  }

  @Test func notificationReservationStaysBoundedEvenForDistantRecurrences() {
    let parser = ISO8601DateFormatter()
    let now = parser.date(from: "2026-09-08T10:00:00Z")!
    let task = TaskItem(
      title: "Renew", completedAt: now, recurrence: Recurrence(interval: 12, unit: .month))
    let plan = ReminderPlan.make(
      tasks: [task], schedule: ReminderSchedule(), now: now, calendar: utc, limit: 500)
    #expect(plan.reminders.count == 60)
    #expect(plan.reminders.first?.trigger == .once(parser.date(from: "2027-09-08T09:00:00Z")!))
  }

  @Test func reminderAtMissingSpringTimeMovesToTheNextValidTime() {
    var paris = utc
    paris.timeZone = TimeZone(identifier: "Europe/Paris")!
    let parser = ISO8601DateFormatter()
    let now = parser.date(from: "2026-03-28T12:00:00+01:00")!
    let task = TaskItem(
      title: "Water plants", completedAt: now, recurrence: Recurrence(interval: 1, unit: .day))
    let plan = ReminderPlan.make(
      tasks: [task], schedule: ReminderSchedule(hour: 2, minute: 30), now: now, calendar: paris,
      limit: 2)
    #expect(
      plan.reminders.map(\.trigger) == [
        .once(parser.date(from: "2026-03-29T03:00:00+02:00")!),
        .once(parser.date(from: "2026-03-30T02:30:00+02:00")!),
      ])
  }
}
