import Foundation
import SwiftData
import TaskomaticCore

@Model
final class TaskRecord {
  var id: UUID = UUID()
  var title: String = ""
  var note: String = ""
  var createdAt: Date = Date.now
  var completedAt: Date?
  var recurrenceInterval: Int = 1
  var recurrenceUnit: String?
  var cycleID: UUID = UUID()

  init(item: TaskItem) {
    id = item.id
    title = item.title
    note = item.note
    createdAt = item.createdAt
    apply(item)
  }

  var item: TaskItem {
    TaskItem(
      id: id, title: title, note: note, createdAt: createdAt, completedAt: completedAt,
      recurrence: recurrenceUnit.flatMap(Recurrence.Unit.init(rawValue:)).map {
        Recurrence(interval: recurrenceInterval, unit: $0)
      }, cycleID: cycleID)
  }

  private func apply(_ item: TaskItem) {
    title = item.title
    note = item.note
    completedAt = item.completedAt
    cycleID = item.cycleID
    recurrenceInterval = item.recurrence?.interval ?? 1
    recurrenceUnit = item.recurrence?.unit.rawValue
  }
}
