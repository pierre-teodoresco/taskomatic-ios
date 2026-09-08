import SwiftUI
import TaskomaticCore

struct TaskEditorView: View {
  @Environment(TaskStore.self) private var store
  @Environment(AppSettings.self) private var settings
  @Environment(AppRuntime.self) private var runtime
  @Environment(\.dismiss) private var dismiss
  private let item: TaskItem?
  private let onCreated: () -> Void
  private let initialTitle: String
  @State private var title: String
  @State private var note: String
  @State private var recurrence: Recurrence?
  private enum Confirmation { case deletion, discard }
  @State private var confirmation: Confirmation?
  @State private var saveFailed = false
  @FocusState private var titleFocused: Bool

  init(item: TaskItem?, initialTitle: String = "", onCreated: @escaping () -> Void = {}) {
    self.item = item
    self.onCreated = onCreated
    self.initialTitle = initialTitle
    _title = State(initialValue: item?.title ?? initialTitle)
    _note = State(initialValue: item?.note ?? "")
    _recurrence = State(initialValue: item?.recurrence)
  }

  private var text: AppStrings { settings.strings }
  private var hasChanges: Bool {
    title != (item?.title ?? initialTitle) || note != (item?.note ?? "")
      || recurrence != item?.recurrence
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          Surface {
            VStack(alignment: .leading, spacing: 0) {
              TextField(text("editor.title"), text: $title, axis: .vertical)
                .font(.title2.weight(.semibold)).foregroundStyle(Theme.ink)
                .focused($titleFocused).lineLimit(1...5)
                .accessibilityIdentifier("editorTitle")
                .padding(20)
              Rectangle().fill(Theme.line).frame(height: 0.5).padding(.horizontal, 20)
              TextField(text("editor.note"), text: $note, axis: .vertical)
                .font(.body).foregroundStyle(Theme.ink).lineLimit(4...12)
                .accessibilityIdentifier("editorNote")
                .padding(20)
            }
          }

          VStack(alignment: .leading, spacing: 12) {
            SectionCaption(title: text("editor.repeat"))
            Surface {
              NavigationLink {
                RecurrencePicker(recurrence: $recurrence)
              } label: {
                HStack(spacing: 12) {
                  Image(systemName: "repeat").foregroundStyle(Theme.accent)
                    .frame(width: 36, height: 36).background(
                      Theme.accentSoft, in: RoundedRectangle(cornerRadius: 10))
                  Text(recurrence.map(text.recurrence) ?? text("editor.once"))
                    .font(.body.weight(.medium)).foregroundStyle(Theme.ink)
                  Spacer()
                  Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondary)
                }.padding(16)
              }.accessibilityIdentifier("editRecurrence")
            }
            if recurrence != nil {
              Text(text("editor.after")).font(.footnote).foregroundStyle(Theme.secondary)
            }
          }

          if let completed = item?.completedAt {
            VStack(spacing: 14) {
              detail(text("editor.last"), date: completed)
              if let next = recurrence?.nextActivation(after: completed, calendar: .current) {
                detail(text("editor.next"), date: next)
              }
            }.padding(.horizontal, 4)
          }

          if item != nil {
            Button(role: .destructive) {
              confirmation = .deletion
            } label: {
              Label(text("editor.delete"), systemImage: "trash")
                .font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: 48)
            }.accessibilityIdentifier("deleteTask")
          }
        }
        .padding(Theme.pagePadding)
      }
      .scrollDismissesKeyboard(.interactively)
      .background(Theme.canvas)
      .navigationTitle(text(item == nil ? "editor.new" : "editor.edit"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(text("cancel")) {
            if hasChanges { confirmation = .discard } else { dismiss() }
          }.foregroundStyle(Theme.secondary)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(text(item == nil ? "editor.add" : "editor.save")) { save() }
            .fontWeight(.semibold)
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("saveTask")
        }
      }
      .confirmationDialog(
        text(confirmation == .deletion ? "editor.delete.title" : "editor.discard.title"),
        isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } }),
        titleVisibility: .visible
      ) {
        if confirmation == .deletion {
          Button(text("delete"), role: .destructive) {
            guard let item else { return }
            do {
              try store.delete(item.id)
              dismiss()
            } catch { saveFailed = true }
          }
          Button(text("cancel"), role: .cancel) {}
        } else {
          Button(text("editor.discard"), role: .destructive) { dismiss() }
          Button(text("editor.keepEditing")) { confirmation = nil }
        }
      } message: {
        Text(
          text(
            confirmation == .deletion
              ? (runtime.cloudEnabled ? "editor.delete.body" : "editor.delete.localBody")
              : "editor.discard.body"))
      }
      .alert(text("error.title"), isPresented: $saveFailed) {
        Button(text("done")) {}
      } message: {
        Text(text("error.save"))
      }
      .task {
        if item == nil {
          try? await Task.sleep(for: .milliseconds(300))
          guard !Task.isCancelled else { return }
          titleFocused = true
        }
      }
    }
    .tint(Theme.accent)
    .presentationDragIndicator(.visible)
    .interactiveDismissDisabled(hasChanges)
  }

  private func detail(_ title: String, date: Date) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(title).foregroundStyle(Theme.secondary)
      Spacer()
      Text(date.formatted(.dateTime.day().month(.abbreviated).year().locale(text.locale)))
        .foregroundStyle(Theme.ink)
    }.font(.footnote)
  }

  private func save() {
    do {
      if let item {
        try store.edit(original: item, title: title, note: note, recurrence: recurrence)
      } else {
        try store.add(title: title, note: note, recurrence: recurrence)
        onCreated()
      }
      dismiss()
    } catch { saveFailed = true }
  }
}
