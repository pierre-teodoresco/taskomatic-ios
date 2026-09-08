import Foundation

/// A portable snapshot of all task states. Notification permissions stay on the device.
public struct TaskBackup: Sendable {
  public static let maximumFileSize = 10 * 1_024 * 1_024
  public let items: [TaskItem]
  public let createdAt: Date

  public init(items: [TaskItem], createdAt: Date = .now) throws {
    guard items.count <= 10_000 else { throw BackupError.tooLarge }
    guard Self.validDate(createdAt), Set(items.map(\.id)).count == items.count,
      items.allSatisfy({ item in
        !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          && Self.validDate(item.createdAt)
          && (item.completedAt.map(Self.validDate) ?? true)
          && (item.recurrence.map { (1...99).contains($0.interval) } ?? true)
      })
    else { throw BackupError.invalidFile }
    self.items = items
    self.createdAt = createdAt
  }

  public func encoded() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .millisecondsSince1970
    let data = try encoder.encode(Envelope(createdAt: createdAt, items: items))
    guard data.count <= Self.maximumFileSize else { throw BackupError.tooLarge }
    return data
  }

  public static func decode(_ data: Data) throws -> TaskBackup {
    guard data.count <= maximumFileSize else { throw BackupError.tooLarge }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .millisecondsSince1970
    let envelope = try decoder.decode(Envelope.self, from: data)
    guard envelope.format == "com.pierreteodoresco.taskomatic.backup" else {
      throw BackupError.invalidFile
    }
    guard envelope.version == 1 else { throw BackupError.unsupportedVersion }
    return try TaskBackup(items: envelope.items, createdAt: envelope.createdAt)
  }

  private static func validDate(_ date: Date) -> Bool {
    date.timeIntervalSince1970.isFinite && date >= .distantPast && date <= .distantFuture
  }

  public enum BackupError: Error, Equatable {
    case invalidFile, unsupportedVersion, tooLarge
  }

  private struct Envelope: Codable {
    var format = "com.pierreteodoresco.taskomatic.backup"
    var version = 1
    let createdAt: Date
    let items: [TaskItem]
  }
}
