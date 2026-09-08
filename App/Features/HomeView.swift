import SwiftUI
import TaskomaticCore

struct HomeView: View {
  @Environment(TaskStore.self) private var store
  @Environment(AppSettings.self) private var settings
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.colorScheme) private var colorScheme
  @State private var completedFilter = false
  @State private var waitingExpanded = true
  @State private var quickTitle = ""
  @State private var editor: EditorPresentation?
  @State private var settingsPresented = false
  @State private var undoneItem: CompletionUndo?
  @State private var undoFailed = false
  @State private var completionCount = 0
  @FocusState private var quickFocused: Bool

  private var text: AppStrings { settings.strings }

  var body: some View {
    TimelineView(.periodic(from: .now, by: 30)) { timeline in
      let active = store.items.filter { $0.isActive(at: timeline.date, calendar: .current) }
      let waiting = store.items.filter {
        $0.recurrence != nil && !$0.isActive(at: timeline.date, calendar: .current)
      }
      .sorted {
        ($0.nextActivation(calendar: .current) ?? .distantFuture)
          < ($1.nextActivation(calendar: .current) ?? .distantFuture)
      }
      let completed = store.items.filter { $0.recurrence == nil && $0.completedAt != nil }
        .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }

      ScrollView {
        VStack(alignment: .leading, spacing: 26) {
          header
          title
          filters(activeCount: active.count)
          if completedFilter {
            if completed.isEmpty {
              emptyState(kind: .archive)
            } else {
              taskList(completed, state: .completed)
            }
          } else {
            if active.isEmpty {
              emptyState(kind: store.items.isEmpty ? .first : .done)
            } else {
              taskList(active, state: .active)
            }

            if !waiting.isEmpty {
              VStack(spacing: 12) {
                Button {
                  withAnimation(animation) { waitingExpanded.toggle() }
                } label: {
                  HStack {
                    SectionCaption(title: text("section.waiting"))
                    Text("\(waiting.count)").font(.caption.weight(.medium)).foregroundStyle(
                      Theme.secondary)
                    Spacer()
                    Image(systemName: waitingExpanded ? "chevron.up" : "chevron.down")
                      .font(.caption.weight(.semibold)).foregroundStyle(Theme.secondary)
                  }.frame(minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain)
                if waitingExpanded { taskList(waiting, state: .waiting) }
              }
            }
            if !store.items.isEmpty && !settings.remindersEnabled
              && !settings.reminderPromptDismissed
            {
              reminderPrompt
            }
          }
        }
        .padding(.horizontal, Theme.pagePadding)
        .padding(.top, 12)
        .padding(.bottom, 28)
      }
      .scrollDismissesKeyboard(.interactively)
      .contentShape(Rectangle())
      .simultaneousGesture(TapGesture().onEnded { quickFocused = false })
    }
    .background(Theme.canvas)
    .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
    .sheet(item: $editor) { presentation in
      TaskEditorView(item: presentation.item, initialTitle: presentation.initialTitle) {
        quickTitle = ""
        completedFilter = false
      }
    }
    .sheet(isPresented: $settingsPresented) {
      // Forward the window's resolved appearance, including System, to this presentation.
      SettingsView().preferredColorScheme(colorScheme)
    }
    .sensoryFeedback(.success, trigger: completionCount)
    .alert(
      text("error.title"),
      isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })
    ) {
      Button(text("done")) { store.error = nil }
    } message: {
      Text(
        text(
          store.error as? TaskStore.StoreError == .refreshAfterSave
            ? "error.refreshAfterSave" : "error.save"))
    }
  }

  private var animation: Animation? { reduceMotion ? nil : .snappy(duration: 0.25) }

  private var header: some View {
    HStack(spacing: 9) {
      BrandMark()
      Text("Taskomatic").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
      Spacer()
      IconButton(symbol: "slider.horizontal.3", label: text("settings.title")) {
        quickFocused = false
        settingsPresented = true
      }.accessibilityIdentifier("openSettings")
    }
  }

  private var title: some View {
    VStack(alignment: .leading, spacing: 9) {
      Text(text("home.title"))
        .font(.largeTitle.weight(.bold)).tracking(-1.0).foregroundStyle(Theme.ink)
        .accessibilityAddTraits(.isHeader)
      Text(text("home.subtitle")).font(.subheadline).foregroundStyle(Theme.secondary)
    }.padding(.top, 6)
  }

  private func filters(activeCount: Int) -> some View {
    let layout =
      dynamicTypeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 4))
    return layout {
      filterButton(text("filter.active"), count: activeCount, selected: !completedFilter) {
        withAnimation(animation) { completedFilter = false }
      }.accessibilityIdentifier("filter.active")
      filterButton(text("filter.completed"), selected: completedFilter) {
        withAnimation(animation) { completedFilter = true }
      }.accessibilityIdentifier("filter.completed")
    }
    .padding(4)
    .background(Theme.raised, in: RoundedRectangle(cornerRadius: 14))
  }

  private func filterButton(
    _ title: String, count: Int? = nil, selected: Bool, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 7) {
        Text(title).font(.subheadline.weight(.semibold))
        if let count {
          Text("\(count)").font(.caption.weight(.semibold)).monospacedDigit()
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(selected ? Theme.accentSoft : Theme.line, in: Capsule())
            .foregroundStyle(selected ? Theme.accent : Theme.secondary)
        }
      }
      .foregroundStyle(selected ? Theme.ink : Theme.secondary)
      .frame(maxWidth: .infinity, minHeight: 44)
      .contentShape(Rectangle())
      .background(selected ? Theme.surface : .clear, in: RoundedRectangle(cornerRadius: 11))
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  private func taskList(_ items: [TaskItem], state: TaskRow.State) -> some View {
    Surface {
      LazyVStack(spacing: 0) {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
          TaskRow(item: item, state: state, strings: text, toggle: { toggle(item, state: state) }) {
            quickFocused = false
            editor = EditorPresentation(item: item)
          }
          if index < items.count - 1 {
            Rectangle().fill(Theme.line).frame(height: 0.5).padding(.leading, 55)
          }
        }
      }
    }
  }

  private enum EmptyKind { case first, done, archive }

  private func emptyState(kind: EmptyKind) -> some View {
    let title =
      kind == .first ? "empty.title" : kind == .done ? "empty.done.title" : "empty.archive.title"
    let body =
      kind == .first ? "empty.body" : kind == .done ? "empty.done.body" : "empty.archive.body"
    return VStack(spacing: 18) {
      Image(systemName: kind == .archive ? "tray" : kind == .done ? "checkmark" : "text.badge.plus")
        .font(.system(size: 32, weight: .light))
        .foregroundStyle(Theme.accent)
        .frame(width: 82, height: 82)
        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 26))
        .accessibilityHidden(true)
      VStack(spacing: 9) {
        Text(text(title)).font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
        Text(text(body)).font(.subheadline).foregroundStyle(Theme.secondary)
          .multilineTextAlignment(.center).lineSpacing(4).frame(maxWidth: 290)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 48)
  }

  private var bottomBar: some View {
    VStack(spacing: 10) {
      if let undoneItem {
        HStack {
          Label(text("undo.completed"), systemImage: "checkmark.circle.fill")
            .font(.subheadline).foregroundStyle(Theme.ink)
          Spacer()
          Button(text("undo.action")) {
            do {
              try store.undoCompletion(undoneItem)
              self.undoneItem = nil
              undoFailed = false
            } catch {
              undoFailed = true
              store.error = error
            }
          }.font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
        }
        .padding(16).background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .task(id: undoneItem.id) {
          try? await Task.sleep(for: .seconds(6))
          guard !Task.isCancelled, !undoFailed else { return }
          withAnimation(animation) { self.undoneItem = nil }
        }
      }
      HStack(spacing: 8) {
        Button {
          quickFocused = false
          editor = EditorPresentation(initialTitle: quickTitle)
        } label: {
          Image(systemName: "plus").font(.system(size: 20, weight: .medium))
            .foregroundStyle(Theme.accent).frame(width: 44, height: 48)
            .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(text("quick.details")).accessibilityIdentifier(
          "newTaskDetails")
        TextField(text("quick.placeholder"), text: $quickTitle)
          .font(.body).foregroundStyle(Theme.ink).focused($quickFocused)
          .submitLabel(.done).onSubmit(addQuickTask)
          .accessibilityIdentifier("quickAdd")
        if !quickTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          Button(action: addQuickTask) {
            Image(systemName: "arrow.up").font(.system(size: 17, weight: .semibold))
              .foregroundStyle(Theme.onAccent).frame(width: 38, height: 38)
              .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12))
              .frame(width: 44, height: 48)
              .contentShape(Rectangle())
          }.buttonStyle(.plain).accessibilityLabel(text("quick.add")).accessibilityIdentifier(
            "quickAddSubmit")
        }
      }
      .padding(.horizontal, 7).padding(.vertical, 5)
      .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
      .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.line, lineWidth: 1))
      .shadow(color: .black.opacity(0.035), radius: 16, y: 4)
    }
    .padding(.horizontal, Theme.pagePadding).padding(.top, 10).padding(.bottom, 10)
    .background(Theme.canvas.opacity(0.98))
  }

  private var reminderPrompt: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        Image(systemName: "bell.badge").font(.title3).foregroundStyle(Theme.accent)
        VStack(alignment: .leading, spacing: 6) {
          Text(text("permission.title")).font(.subheadline.weight(.semibold)).foregroundStyle(
            Theme.ink)
          Text(text("permission.body")).font(.footnote).foregroundStyle(Theme.secondary)
        }
      }
      HStack {
        Button(text("permission.enable")) { settingsPresented = true }
          .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
        Spacer()
        Button(text("permission.later")) { settings.reminderPromptDismissed = true }
          .font(.subheadline).foregroundStyle(Theme.secondary)
      }.frame(minHeight: 36)
    }.padding(18).background(
      Theme.accentSoft.opacity(0.7), in: RoundedRectangle(cornerRadius: Theme.corner))
  }

  private func addQuickTask() {
    store.perform {
      try store.add(title: quickTitle)
      quickTitle = ""
      completedFilter = false
      quickFocused = false
    }
  }

  private func toggle(_ item: TaskItem, state: TaskRow.State) {
    withAnimation(animation) {
      store.perform {
        if state == .active {
          if let undo = try store.complete(id: item.id, expectedCycle: item.cycleToken) {
            undoFailed = false
            undoneItem = undo
            completionCount += 1
          }
        } else {
          try store.restore(id: item.id, expectedCycle: item.cycleToken)
        }
      }
    }
  }
}

private struct EditorPresentation: Identifiable {
  let id = UUID()
  var item: TaskItem? = nil
  var initialTitle = ""
}
