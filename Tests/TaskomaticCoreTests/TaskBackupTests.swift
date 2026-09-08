import Foundation
import TaskomaticCore
import Testing

struct TaskBackupTests {
  @Test func backupLimitsRejectOversizedDocumentsAndTaskCollections() throws {
    #expect(throws: TaskBackup.BackupError.tooLarge) {
      try TaskBackup.decode(Data(repeating: 32, count: TaskBackup.maximumFileSize + 1))
    }
    #expect(throws: TaskBackup.BackupError.tooLarge) {
      try TaskBackup(items: (0...10_000).map { TaskItem(title: "Task \($0)") })
    }
  }

  @Test func malformedOrIncompatibleBackupIsRejectedInFull() throws {
    let backup = try TaskBackup(items: [TaskItem(title: "Valid")])
    let data = try backup.encoded()
    let original = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    var cases: [[String: Any]] = []
    var wrongFormat = original
    wrongFormat["format"] = "another.app"
    cases.append(wrongFormat)
    var future = original
    future["version"] = 2
    cases.append(future)
    let records = try #require(original["items"] as? [[String: Any]])
    var duplicate = original
    duplicate["items"] = records + records
    cases.append(duplicate)
    for invalidField in [
      ["title": " \n "],
      ["recurrence": ["interval": 0, "unit": "week"]],
      ["recurrence": ["interval": 100, "unit": "month"]],
      ["recurrence": ["interval": 1, "unit": "year"]],
      ["createdAt": 1e100],
    ] as [[String: Any]] {
      var invalid = records[0]
      invalid["id"] = UUID().uuidString
      invalid.merge(invalidField) { _, new in new }
      var document = original
      document["items"] = records + [invalid]
      cases.append(document)
    }
    for document in cases {
      let invalidData = try JSONSerialization.data(withJSONObject: document)
      #expect(throws: (any Error).self) { try TaskBackup.decode(invalidData) }
    }
  }

  @Test func backupPreservesEveryTaskStateAndUnicodeContent() throws {
    let created = Date(timeIntervalSince1970: 1_780_000_000)
    let completed = Date(timeIntervalSince1970: 1_780_100_000)
    let items = [
      TaskItem(title: "Acheter du café ☕️", note: "Grains\nDécaféiné", createdAt: created),
      TaskItem(title: "Réservation", createdAt: created, completedAt: completed),
      TaskItem(
        title: "Arroser", createdAt: created, completedAt: completed,
        recurrence: Recurrence(interval: 2, unit: .week)),
    ]
    let backup = try TaskBackup(items: items, createdAt: completed)
    let restored = try TaskBackup.decode(backup.encoded())
    #expect(restored.items == items)
    #expect(restored.createdAt == completed)
  }
}
