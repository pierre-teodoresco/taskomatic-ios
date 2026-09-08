import SwiftData
import TaskomaticCore
import XCTest

@testable import Taskomatic

@MainActor
final class TaskStoreTests: XCTestCase {
  func testRecurrenceEditPreservesCompletionMadeAfterTheEditorOpened() throws {
    let container = try ModelContainer(
      for: TaskRecord.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    let local = try TaskStore(container: container)
    try local.add(title: "Plantes", recurrence: Recurrence(interval: 1, unit: .week))
    let form = try XCTUnwrap(local.items.first)
    let other = try TaskStore(container: container)
    let completed = Date(timeIntervalSince1970: 1_780_000_000)
    try other.complete(id: form.id, expectedCycle: form.cycleToken, at: completed)
    try local.edit(
      original: form, title: form.title, note: form.note, recurrence: nil, at: completed)
    XCTAssertEqual(local.items.first?.completedAt, completed)
    XCTAssertFalse(try XCTUnwrap(local.items.first).isActive(at: completed, calendar: .current))
  }

  func testChangingRecurrenceKeepsAnAlreadyActiveTaskActive() throws {
    let completed = Date(timeIntervalSince1970: 1_780_000_000)
    let now = completed.addingTimeInterval(10 * 86_400)
    for recurrence in [nil, Recurrence(interval: 1, unit: .month)] as [Recurrence?] {
      let container = try ModelContainer(
        for: TaskRecord.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
      let store = try TaskStore(container: container)
      try store.add(title: "Plantes", recurrence: Recurrence(interval: 1, unit: .week))
      let initial = try XCTUnwrap(store.items.first)
      try store.complete(id: initial.id, expectedCycle: initial.cycleToken, at: completed)
      let active = try XCTUnwrap(store.items.first)
      XCTAssertTrue(active.isActive(at: now, calendar: .current))
      try store.edit(
        original: active, title: active.title, note: active.note, recurrence: recurrence, at: now)
      let edited = try XCTUnwrap(store.items.first)
      XCTAssertTrue(edited.isActive(at: now, calendar: .current))
      XCTAssertNotEqual(edited.cycleToken, active.cycleToken)
    }
  }

  func testFailedBackupRestoreDoesNotWriteAnyTasks() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "readonly.store")
    let writable = try ModelContainer(
      for: TaskRecord.self, configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
    let original = try TaskStore(container: writable)
    try original.add(title: "Keep this task")
    let readonly = try ModelContainer(
      for: TaskRecord.self,
      configurations: ModelConfiguration(url: url, allowsSave: false, cloudKitDatabase: .none))
    let store = try TaskStore(container: readonly)
    let backup = try TaskBackup(items: [
      TaskItem(title: "First import"), TaskItem(title: "Second import"),
    ])
    XCTAssertThrowsError(try store.restoreBackup(backup))
    try original.reload()
    XCTAssertEqual(original.items.map(\.title), ["Keep this task"])
    XCTAssertEqual(store.items.map(\.title), ["Keep this task"])
  }

  func testBackupRestoresMissingTasksWithoutOverwritingNewerEditsOrDuplicatingTasks() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "tasks.store")
    let container = try ModelContainer(
      for: TaskRecord.self,
      configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
    let store = try TaskStore(container: container)
    let existingID = try store.add(title: "Original", note: "Keep me")
    let archivedID = try store.add(title: "Déjà fait ☕️")
    let archived = try XCTUnwrap(store.items.first { $0.id == archivedID })
    try store.complete(
      id: archivedID, expectedCycle: archived.cycleToken,
      at: Date(timeIntervalSince1970: 1_780_000_000))
    let repeatID = try store.add(title: "Plantes", recurrence: Recurrence(interval: 2, unit: .week))
    let freshContext = try TaskStore(container: container)
    let original = try XCTUnwrap(freshContext.items.first { $0.id == existingID })
    try freshContext.edit(
      original: original, title: "Included in export", note: "Keep me", recurrence: nil)
    let backup = try TaskBackup.decode(store.exportBackup())
    XCTAssertEqual(backup.items.first { $0.id == existingID }?.title, "Included in export")
    // The preview is already open when another context edits the existing task.
    let previewed = try XCTUnwrap(freshContext.items.first { $0.id == existingID })
    try freshContext.edit(
      original: previewed, title: "Newer title", note: "Newer note", recurrence: nil)
    try store.delete(archivedID)
    try store.delete(repeatID)
    XCTAssertEqual(try store.restoreBackup(backup), 2)
    XCTAssertEqual(try store.restoreBackup(backup), 0)
    let reopenedContainer = try ModelContainer(
      for: TaskRecord.self,
      configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
    let reopened = try TaskStore(container: reopenedContainer)
    XCTAssertEqual(reopened.items.count, 3)
    XCTAssertEqual(reopened.items.first { $0.id == existingID }?.title, "Newer title")
    XCTAssertEqual(reopened.items.first { $0.id == existingID }?.note, "Newer note")
    XCTAssertEqual(
      reopened.items.first { $0.id == archivedID }?.completedAt,
      Date(timeIntervalSince1970: 1_780_000_000))
    let restored = try XCTUnwrap(reopened.items.first { $0.id == repeatID })
    let saved = try XCTUnwrap(backup.items.first { $0.id == repeatID })
    XCTAssertEqual(restored.recurrence, Recurrence(interval: 2, unit: .week))
    XCTAssertNotEqual(restored.cycleToken, saved.cycleToken)
    XCTAssertNil(try reopened.complete(id: restored.id, expectedCycle: saved.cycleToken))
  }

  func testCompletingATaskPreservesContentEditedByAnotherContext() throws {
    let container = try ModelContainer(
      for: TaskRecord.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    let firstDevice = try TaskStore(container: container)
    let id = try firstDevice.add(title: "Coffee")
    let snapshot = try XCTUnwrap(firstDevice.items.first)
    let otherDevice = try TaskStore(container: container)
    let edited = try XCTUnwrap(otherDevice.items.first)
    try otherDevice.edit(
      original: edited, title: "Coffee and tea", note: edited.note, recurrence: edited.recurrence)
    try firstDevice.complete(id: snapshot.id, expectedCycle: snapshot.cycleToken)
    try otherDevice.reload()
    XCTAssertEqual(otherDevice.items.first?.id, id)
    XCTAssertEqual(otherDevice.items.first?.title, "Coffee and tea")
    XCTAssertNotNil(otherDevice.items.first?.completedAt)
  }

  func testUndoPreservesEditsAndRejectsAnOldNotificationAction() throws {
    let container = try ModelContainer(
      for: TaskRecord.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    let store = try TaskStore(container: container)
    try store.add(title: "Plants", recurrence: Recurrence(interval: 1, unit: .week))
    let initial = try XCTUnwrap(store.items.first)
    let undo = try XCTUnwrap(store.complete(id: initial.id, expectedCycle: initial.cycleToken))
    let completed = try XCTUnwrap(store.items.first)
    try store.edit(
      original: completed, title: "Water the plants", note: "A little water",
      recurrence: Recurrence(interval: 2, unit: .week))
    try store.undoCompletion(undo)
    let restored = try XCTUnwrap(store.items.first)
    XCTAssertEqual(restored.title, "Water the plants")
    XCTAssertEqual(restored.note, "A little water")
    XCTAssertEqual(restored.recurrence, Recurrence(interval: 2, unit: .week))
    XCTAssertNil(restored.completedAt)
    XCTAssertNotEqual(restored.cycleToken, initial.cycleToken)
    XCTAssertNil(try store.complete(id: initial.id, expectedCycle: initial.cycleToken))
    XCTAssertNil(store.items.first?.completedAt)
  }

  func testEditingOnlyATitlePreservesANewerNoteAndCompletion() throws {
    let container = try ModelContainer(
      for: TaskRecord.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    let local = try TaskStore(container: container)
    try local.add(title: "Coffee", note: "Original note")
    let formSnapshot = try XCTUnwrap(local.items.first)
    let remote = try TaskStore(container: container)
    try remote.edit(
      original: formSnapshot, title: "Coffee", note: "New note from another device", recurrence: nil
    )
    try remote.complete(id: formSnapshot.id, expectedCycle: formSnapshot.cycleToken)
    try local.edit(
      original: formSnapshot, title: "Coffee and tea", note: "Original note", recurrence: nil)
    XCTAssertEqual(local.items.first?.note, "New note from another device")
    XCTAssertNotNil(local.items.first?.completedAt)
  }
}
