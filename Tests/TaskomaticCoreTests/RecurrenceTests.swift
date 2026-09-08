import Foundation
import Testing

@testable import TaskomaticCore

struct RecurrenceTests {
  private var paris: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
    return calendar
  }

  @Test func weeklyTaskReturnsAtStartOfDayOneWeekAfterCompletion() {
    let completed = ISO8601DateFormatter().date(from: "2026-09-10T18:30:00+02:00")!
    let expected = ISO8601DateFormatter().date(from: "2026-09-17T00:00:00+02:00")!
    #expect(
      Recurrence(interval: 1, unit: .week).nextActivation(after: completed, calendar: paris)
        == expected)
  }

  @Test(arguments: [
    ("2026-01-31T18:30:00+01:00", "2026-02-28T00:00:00+01:00"),
    ("2028-01-31T18:30:00+01:00", "2028-02-29T00:00:00+01:00"),
  ])
  func calendarMonthsClampToLastDay(completed: String, expected: String) {
    let parser = ISO8601DateFormatter()
    #expect(
      Recurrence(interval: 1, unit: .month).nextActivation(
        after: parser.date(from: completed)!, calendar: paris)
        == parser.date(from: expected)!)
  }

  @Test func dailyTaskKeepsMidnightAcrossSpringClockChange() {
    let parser = ISO8601DateFormatter()
    let completed = parser.date(from: "2026-03-28T23:30:00+01:00")!
    let expected = parser.date(from: "2026-03-30T00:00:00+02:00")!
    #expect(
      Recurrence(interval: 2, unit: .day).nextActivation(after: completed, calendar: paris)
        == expected)
  }

  @Test func midnightClockChangeDoesNotShiftTheFollowingDaysActivation() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Santiago")!
    let parser = ISO8601DateFormatter()
    let completed = parser.date(from: "2026-09-06T18:00:00-03:00")!
    #expect(
      Recurrence(interval: 1, unit: .day).nextActivation(after: completed, calendar: calendar)
        == parser.date(from: "2026-09-07T00:00:00-03:00")!)
  }
}
