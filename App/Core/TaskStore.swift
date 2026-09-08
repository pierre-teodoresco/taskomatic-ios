import Foundation
import Observation
import SwiftData
import TaskomaticCore

@MainActor @Observable
final class TaskStore {
  private let container: ModelContainer
  private(set) var items: [TaskItem] = []
  private(set) var revision = 0
  var error: Error?

  init(container: ModelContainer) throws {
    self.container = container
    try reload()
  }

  func reload() throws {
    let context = ModelContext(container)
    items = try context.fetch(FetchDescriptor<TaskRecord>(sortBy: [SortDescriptor(\.createdAt)]))
      .map(\.item)
    revision += 1
  }

  func exportBackup() throws -> Data {
    let context = ModelContext(container)
    let current = try context.fetch(
      FetchDescriptor<TaskRecord>(sortBy: [SortDescriptor(\.createdAt)])
    )
    .map(\.item)
    return try TaskBackup(items: current).encoded()
  }

  /// Restores only missing IDs. Re-read at confirmation time; a preview may be stale.
  @discardableResult
  func restoreBackup(_ backup: TaskBackup) throws -> Int {
    let context = ModelContext(container)
    context.autosaveEnabled = false
    let existing = Set(try context.fetch(FetchDescriptor<TaskRecord>()).map(\.id))
    let missing = backup.items.filter { !existing.contains($0.id) }
    for item in missing {
      let restored = TaskItem(
        id: item.id, title: item.title, note: item.note, createdAt: item.createdAt,
        completedAt: item.completedAt, recurrence: item.recurrence)
      context.insert(TaskRecord(item: restored))
    }
    try commit(context)
    return missing.count
  }

  private func commit(_ context: ModelContext) throws {
    do { try context.save() } catch {
      context.rollback()
      throw error
    }
    // Persistence already succeeded. A refresh failure must not invite a duplicate insertion.
    do { try reload() } catch { self.error = StoreError.refreshAfterSave }
  }

  @discardableResult
  func add(title: String, note: String = "", recurrence: Recurrence? = nil) throws -> UUID {
    let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else { throw StoreError.emptyTitle }
    let item = TaskItem(
      title: title, note: note.trimmingCharacters(in: .whitespacesAndNewlines),
      recurrence: recurrence)
    let context = ModelContext(container)
    context.autosaveEnabled = false
    context.insert(TaskRecord(item: item))
    try commit(context)
    return item.id
  }

  func edit(
    original: TaskItem, title: String, note: String, recurrence: Recurrence?, at date: Date = .now
  ) throws {
    let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else { throw StoreError.emptyTitle }
    let context = ModelContext(container)
    context.autosaveEnabled = false
    let record = try find(original.id, in: context)
    // Only fields edited in this form are written. Synced completion and unrelated
    // content changes remain authoritative in the fresh context.
    if title != original.title { record.title = title }
    if note != original.note { record.note = note }
    if recurrence != original.recurrence {
      if record.completedAt != nil && record.item.isActive(at: date, calendar: .current) {
        // Editing the cadence must not complete or postpone an already-active cycle.
        record.completedAt = nil
        record.cycleID = UUID()
      }
      record.recurrenceInterval = recurrence?.interval ?? 1
      record.recurrenceUnit = recurrence?.unit.rawValue
    }
    try commit(context)
  }

  @discardableResult
  func complete(id: UUID, expectedCycle: String, at date: Date = .now) throws -> CompletionUndo? {
    let context = ModelContext(container)
    context.autosaveEnabled = false
    let record = try find(id, in: context)
    guard record.item.cycleToken == expectedCycle,
      record.item.isActive(at: date, calendar: .current)
    else {
      try reload()
      return nil
    }
    let previous = record.completedAt
    record.completedAt = date
    record.cycleID = UUID()
    let undo = CompletionUndo(
      taskID: id, appliedCycleID: record.cycleID, previousCompletedAt: previous)
    try commit(context)
    return undo
  }

  func restore(id: UUID, expectedCycle: String) throws {
    let context = ModelContext(container)
    context.autosaveEnabled = false
    let record = try find(id, in: context)
    if record.item.cycleToken == expectedCycle {
      record.completedAt = nil
      record.cycleID = UUID()
      try commit(context)
      return
    }
    try reload()
  }

  func undoCompletion(_ undo: CompletionUndo) throws {
    let context = ModelContext(container)
    context.autosaveEnabled = false
    let record = try find(undo.taskID, in: context)
    if record.cycleID == undo.appliedCycleID {
      record.completedAt = undo.previousCompletedAt
      record.cycleID = UUID()
      try commit(context)
      return
    }
    try reload()
  }

  private func find(_ id: UUID, in context: ModelContext) throws -> TaskRecord {
    let descriptor = FetchDescriptor<TaskRecord>(predicate: #Predicate { $0.id == id })
    guard let record = try context.fetch(descriptor).first else { throw StoreError.missingTask }
    return record
  }

  func delete(_ id: UUID) throws {
    let context = ModelContext(container)
    context.autosaveEnabled = false
    let descriptor = FetchDescriptor<TaskRecord>(predicate: #Predicate { $0.id == id })
    for record in try context.fetch(descriptor) { context.delete(record) }
    try commit(context)
  }

  func perform(_ operation: () throws -> Void) {
    do { try operation() } catch { self.error = error }
  }

  enum StoreError: Error {
    case emptyTitle, missingTask, refreshAfterSave
  }
}

struct CompletionUndo: Identifiable {
  let taskID: UUID
  let appliedCycleID: UUID
  let previousCompletedAt: Date?
  var id: UUID { appliedCycleID }
}
