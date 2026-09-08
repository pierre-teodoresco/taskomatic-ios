import SwiftUI
import TaskomaticCore
import UniformTypeIdentifiers

struct BackupSettingsSection: View {
  @Environment(TaskStore.self) private var store
  @Environment(AppSettings.self) private var settings
  @Environment(\.colorScheme) private var colorScheme
  @State private var document: BackupDocument?
  @State private var filename = "Taskomatic"
  @State private var exporting = false
  @State private var importing = false
  @State private var reading = false
  @State private var preview: BackupPreview?
  @State private var restoredCount: Int?
  @State private var notice: String?
  private var text: AppStrings { settings.strings }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionCaption(title: text("backup.title"))
      Surface {
        VStack(alignment: .leading, spacing: 0) {
          VStack(alignment: .leading, spacing: 10) {
            Label(text("backup.headline"), systemImage: "externaldrive.badge.icloud")
              .font(.subheadline.weight(.medium))
            Text(text("backup.body"))
              .font(.footnote).foregroundStyle(Theme.secondary).lineSpacing(3)
            if let lastExport = settings.lastExportAt {
              Text(
                text(
                  "backup.last",
                  lastExport.formatted(
                    .dateTime.day().month(.abbreviated).hour().minute().locale(text.locale)))
              )
              .font(.caption).foregroundStyle(Theme.secondary)
            }
          }.padding(20)
          Divider().overlay(Theme.line)
          SettingsActionRow(
            title: text("backup.export"), symbol: "square.and.arrow.up", action: export
          )
          .accessibilityIdentifier("exportBackup")
          .disabled(reading)
          Divider().overlay(Theme.line).padding(.leading, 20)
          SettingsActionRow(title: text("backup.import"), symbol: "square.and.arrow.down") {
            importing = true
          }
          .accessibilityIdentifier("importBackup")
          .disabled(reading)
          if reading {
            ProgressView(text("backup.reading")).font(.footnote).padding(20)
          }
        }
      }
    }
    .fileExporter(
      isPresented: $exporting, document: document, contentType: .json, defaultFilename: filename
    ) { result in
      switch result {
      case .success:
        settings.lastExportAt = .now
        notice = text("backup.exported")
      case .failure(let error):
        if !isCancellation(error) { notice = text("backup.export.error") }
      }
      document = nil
    }
    .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
      switch result {
      case .success(let url):
        reading = true
        Task {
          do {
            let backup = try await Task.detached(priority: .userInitiated) {
              try TaskBackup.decode(BackupFile.read(url))
            }.value
            try store.reload()
            preview = BackupPreview(backup: backup)
          } catch { notice = importError(error) }
          reading = false
        }
      case .failure(let error):
        if !isCancellation(error) { notice = text("backup.import.error") }
      }
    }
    .sheet(
      item: $preview,
      onDismiss: {
        if let restoredCount {
          notice = text("backup.restored", restoredCount)
          self.restoredCount = nil
        }
      }
    ) { preview in
      BackupRestoreView(backup: preview.backup) { count in
        restoredCount = count
        self.preview = nil
      }
      .preferredColorScheme(colorScheme)
    }
    .alert(
      text("backup.title"),
      isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })
    ) {
      Button(text("done")) { notice = nil }
    } message: {
      Text(notice ?? "")
    }
  }

  private func export() {
    do {
      document = BackupDocument(data: try store.exportBackup())
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.dateFormat = "yyyy-MM-dd-HHmmss"
      filename = "Taskomatic-\(formatter.string(from: .now))"
      exporting = true
    } catch { notice = text("backup.export.error") }
  }

  private func isCancellation(_ error: Error) -> Bool {
    let error = error as NSError
    return error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError
  }

  private func importError(_ error: Error) -> String {
    if case TaskBackup.BackupError.unsupportedVersion = error {
      return text("backup.version.error")
    }
    if case TaskBackup.BackupError.tooLarge = error { return text("backup.size.error") }
    return text("backup.import.error")
  }
}

private struct BackupPreview: Identifiable {
  let id = UUID()
  let backup: TaskBackup
}

private struct BackupRestoreView: View {
  let backup: TaskBackup
  let onRestore: (Int) -> Void
  @Environment(TaskStore.self) private var store
  @Environment(AppSettings.self) private var settings
  @Environment(\.dismiss) private var dismiss
  @State private var failed = false
  private var text: AppStrings { settings.strings }
  private var missing: [TaskItem] {
    let existing = Set(store.items.map(\.id))
    return backup.items.filter { !existing.contains($0.id) }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Image(systemName: "arrow.counterclockwise.icloud")
            .font(.system(size: 32, weight: .light)).foregroundStyle(Theme.accent)
            .accessibilityHidden(true)
          Text(text(missing.isEmpty ? "backup.nothing" : "backup.preview.body"))
            .font(.body).foregroundStyle(Theme.ink)
          Surface {
            VStack(alignment: .leading, spacing: 14) {
              Text(
                text(
                  "backup.created",
                  backup.createdAt.formatted(
                    .dateTime.day().month(.abbreviated).year().hour().minute().locale(text.locale)))
              )
              .font(.footnote).foregroundStyle(Theme.secondary)
              Text(text("backup.new", missing.count)).font(.headline)
                .accessibilityIdentifier("backupNewCount")
              Text(text("backup.existing", backup.items.count - missing.count))
                .font(.subheadline).foregroundStyle(Theme.secondary)
              ForEach(missing.prefix(3)) { item in
                Text(item.title).font(.subheadline).lineLimit(2)
              }
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
          }
          Text(text("backup.keep.current")).font(.footnote).foregroundStyle(Theme.secondary)
            .lineSpacing(3)
        }.padding(Theme.pagePadding)
      }
      .background(Theme.canvas)
      .safeAreaInset(edge: .bottom) {
        PrimaryButton(title: text(missing.isEmpty ? "done" : "backup.restore")) {
          if missing.isEmpty {
            dismiss()
            return
          }
          do { onRestore(try store.restoreBackup(backup)) } catch { failed = true }
        }.accessibilityIdentifier("confirmRestoreBackup")
          .padding(Theme.pagePadding).background(Theme.canvas)
      }
      .navigationTitle(text("backup.import"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(text("cancel")) { dismiss() }
        }
      }
      .alert(text("error.title"), isPresented: $failed) {
        Button(text("done")) {}
      } message: {
        Text(text("backup.restore.error"))
      }
    }
    .presentationDragIndicator(.visible)
  }
}
