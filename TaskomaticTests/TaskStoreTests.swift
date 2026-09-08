import SwiftData
import TaskomaticCore
import XCTest

@testable import Taskomatic

@MainActor
final class TaskStoreTests: XCTestCase {
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
