import Foundation

public struct ReminderSchedule: Equatable, Sendable {
  public var enabled: Bool
  public var hour: Int
  public var minute: Int
  public var weekdays: Set<Int>

  public init(enabled: Bool = true, hour: Int = 9, minute: Int = 0, weekdays: Set<Int> = Set(1...7))
  {
    self.enabled = enabled
    self.hour = min(23, max(0, hour))
    self.minute = min(59, max(0, minute))
    self.weekdays = weekdays.intersection(1...7)
  }
}

public struct ReminderSummary: Equatable, Sendable {
  public let taskIDs: [UUID]
  public let titles: [String]
  public let singleTaskCycle: String?
  public var count: Int { taskIDs.count }

  public init(tasks: [TaskItem]) {
    taskIDs = tasks.map(\.id)
    titles = tasks.count <= 2 ? tasks.map(\.title) : []
    singleTaskCycle = tasks.count == 1 ? tasks.first?.cycleToken : nil
  }
}

public struct PlannedReminder: Equatable, Sendable {
  public enum Trigger: Equatable, Sendable {
    case daily
    case weekly(Int)
    case once(Date)
  }
  public let id: String
  public let trigger: Trigger
  public let summary: ReminderSummary
}

public struct ReminderPlan: Equatable, Sendable {
  public let reminders: [PlannedReminder]
  public let coverageUntil: Date?
  public var repeatsIndefinitely: Bool {
    reminders.contains { if case .once = $0.trigger { false } else { true } }
  }

  public static func make(
    tasks: [TaskItem], schedule: ReminderSchedule, now: Date, calendar: Calendar,
    limit: Int = 60
  ) -> ReminderPlan {
    let active = tasks.filter { $0.isActive(at: now, calendar: calendar) }
    guard schedule.enabled, !schedule.weekdays.isEmpty, limit > 0 else {
      return ReminderPlan(reminders: [], coverageUntil: nil)
    }
    let dormant = tasks.compactMap { task -> Date? in
      guard let next = task.nextActivation(calendar: calendar), next > now else { return nil }
      return next
    }
    if let firstReturn = dormant.min() {
      // Task activity can only grow while the app is untouched. Prepare each future
      // summary now; notification delivery does not need to execute app code.
      var reminders: [PlannedReminder] = []
      let count = min(limit, 60)
      var cursor = active.isEmpty ? max(now, firstReturn.addingTimeInterval(-1)) : now
      let time = DateComponents(hour: schedule.hour, minute: schedule.minute, second: 0)
      for _ in 0..<(count * 7 + 14) {
        guard reminders.count < count,
          let date = calendar.nextDate(
            after: cursor, matching: time, matchingPolicy: .nextTime,
            repeatedTimePolicy: .first)
        else { break }
        cursor = date
        guard schedule.weekdays.contains(calendar.component(.weekday, from: date)) else { continue }
        let futureTasks = tasks.filter { $0.isActive(at: date, calendar: calendar) }
        guard !futureTasks.isEmpty else { continue }
        reminders.append(
          PlannedReminder(
            id: "date-\(Int(date.timeIntervalSince1970))", trigger: .once(date),
            summary: ReminderSummary(tasks: futureTasks)))
      }
      let end: Date? = reminders.last.flatMap {
        if case .once(let date) = $0.trigger { date } else { nil }
      }
      return ReminderPlan(reminders: reminders, coverageUntil: end)
    }
    guard !active.isEmpty else { return ReminderPlan(reminders: [], coverageUntil: nil) }
    let summary = ReminderSummary(tasks: active)
    let reminders: [PlannedReminder]
    if schedule.weekdays.count == 7 {
      reminders = [PlannedReminder(id: "daily", trigger: .daily, summary: summary)]
    } else {
      reminders = schedule.weekdays.sorted().map {
        PlannedReminder(id: "weekday-\($0)", trigger: .weekly($0), summary: summary)
      }
    }
    return ReminderPlan(reminders: reminders, coverageUntil: nil)
  }
}
