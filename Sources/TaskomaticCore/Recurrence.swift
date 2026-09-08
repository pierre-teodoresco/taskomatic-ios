import Foundation

public struct Recurrence: Codable, Equatable, Sendable {
  public enum Unit: String, Codable, CaseIterable, Sendable {
    case day, week, month
  }

  public let interval: Int
  public let unit: Unit

  public init(interval: Int, unit: Unit) {
    self.interval = max(1, interval)
    self.unit = unit
  }

  public func nextActivation(after completion: Date, calendar: Calendar) -> Date {
    let component: Calendar.Component =
      switch unit {
      case .day: .day
      case .week: .weekOfYear
      case .month: .month
      }
    let day = calendar.startOfDay(for: completion)
    let next = calendar.date(byAdding: component, value: interval, to: day) ?? day
    return calendar.startOfDay(for: next)
  }
}
