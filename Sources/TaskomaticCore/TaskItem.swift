import Foundation

public struct TaskItem: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public var title: String
  public var note: String
  public let createdAt: Date
  public var completedAt: Date?
  public var recurrence: Recurrence?
  public private(set) var cycleID: UUID

  public init(
    id: UUID = UUID(), title: String, note: String = "", createdAt: Date = .now,
    completedAt: Date? = nil, recurrence: Recurrence? = nil, cycleID: UUID = UUID()
  ) {
    self.id = id
    self.title = title
    self.note = note
    self.createdAt = createdAt
    self.completedAt = completedAt
    self.recurrence = recurrence
    self.cycleID = cycleID
  }

  public func nextActivation(calendar: Calendar) -> Date? {
    guard let completedAt, let recurrence else { return nil }
    return recurrence.nextActivation(after: completedAt, calendar: calendar)
  }

  public func isActive(at date: Date, calendar: Calendar) -> Bool {
    guard completedAt != nil else { return true }
    guard let next = nextActivation(calendar: calendar) else { return false }
    return date >= next
  }

  /// Identifies the completion cycle so an old delivered notification cannot complete a newer cycle.
  public var cycleToken: String { cycleID.uuidString }

  public mutating func complete(at date: Date) {
    completedAt = date
    cycleID = UUID()
  }
  public mutating func restore() {
    completedAt = nil
    cycleID = UUID()
  }
}
