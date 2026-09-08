import SwiftUI
import TaskomaticCore
import UniformTypeIdentifiers

struct BackupDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.json] }
  let data: Data

  init(data: Data) { self.data = data }

  init(configuration: ReadConfiguration) throws {
    guard let data = configuration.file.regularFileContents else {
      throw TaskBackup.BackupError.invalidFile
    }
    _ = try TaskBackup.decode(data)
    self.data = data
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: data)
  }
}

enum BackupFile {
  /// Coordinates with Files providers (including iCloud Drive) and bounds memory use.
  nonisolated static func read(_ url: URL) throws -> Data {
    let access = url.startAccessingSecurityScopedResource()
    defer { if access { url.stopAccessingSecurityScopedResource() } }
    var coordinationError: NSError?
    var result: Result<Data, Error>?
    NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) {
      localURL in
      result = Result {
        let file = try FileHandle(forReadingFrom: localURL)
        defer { try? file.close() }
        var data = Data()
        while let chunk = try file.read(
          upToCount: min(65_536, TaskBackup.maximumFileSize + 1 - data.count)), !chunk.isEmpty
        {
          data.append(chunk)
          guard data.count <= TaskBackup.maximumFileSize else {
            throw TaskBackup.BackupError.tooLarge
          }
        }
        return data
      }
    }
    if let coordinationError { throw coordinationError }
    guard let result else { throw TaskBackup.BackupError.invalidFile }
    return try result.get()
  }
}
