import SwiftUI
import TaskomaticCore

struct HomeView: View {
  @Environment(TaskStore.self) private var store
  @Environment(AppSettings.self) private var settings
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.colorScheme) private var colorScheme
  @State private var completedFilter = false
  @State private var waitingExpanded = true
  @State private var quickTitle = ""
  @State private var editor: EditorPresentation?
  @State private var settingsPresented = false
  @State private var pendingUndo: PendingUndo?
  @State private var undoFailed = false
  @State private var completionCount = 0
  @FocusState private var quickFocused: Bool
  @Namespace private var filterNamespace

  private var text: AppStrings { settings.strings }

  var body: some View {
    NavigationStack {
      content
        .navigationTitle(text("home.title"))
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Button {
              quickFocused = false
              settingsPresented = true
            } label: {
              Label(text("settings.title"), systemImage: "slider.horizontal.3")
            }
            .accessibilityIdentifier("openSettings")
          }
        }
    }
  }

  private var content: some View {
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

      List {
        Section {
          VStack(alignment: .leading, spacing: 24) {
            Text(text("home.subtitle")).font(.subheadline).foregroundStyle(Theme.secondary)
              .padding(.horizontal, 4)
            filters(activeCount: active.count)
          }
          .plainListRow()
        }
        if completedFilter {
          if completed.isEmpty {
            Section { emptyState(kind: .archive).plainListRow() }
          } else {
            taskSection(completed, state: .completed)
          }
        } else {
          if active.isEmpty {
            Section { emptyState(kind: store.items.isEmpty ? .first : .done).plainListRow() }
          } else {
            taskSection(active, state: .active)
          }

          if !waiting.isEmpty {
            Section {
              // A row rather than a header: plain-style headers pin while scrolling.
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
              }
              .buttonStyle(.plain)
              .plainListRow()
              if waitingExpanded {
                ForEach(waiting) { item in taskRow(item, state: .waiting) }
              }
            }
          }
          if !store.items.isEmpty && !settings.remindersEnabled
            && !settings.reminderPromptDismissed
          {
            Section { reminderPrompt.plainListRow() }
          }
        }
      }
      // Plain style, as in Messages and Mail: iOS rounds a swiped row into a platter only here.
      .listStyle(.plain)
      .listSectionSpacing(24)
      .scrollContentBackground(.hidden)
      .contentMargins(.horizontal, Theme.pagePadding, for: .scrollContent)
      .contentMargins(.top, 4, for: .scrollContent)
      .scrollDismissesKeyboard(.interactively)
      .contentShape(Rectangle())
      .simultaneousGesture(TapGesture().onEnded { quickFocused = false })
    }
    .background(Theme.listCanvas)
    .floatingBottomBar { bottomBar }
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

  private var canQuickAdd: Bool {
    !quickTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var animation: Animation? { reduceMotion ? nil : .snappy(duration: 0.25) }

  private static let filterInset: CGFloat = 4

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
    .padding(Self.filterInset)
    .background(Theme.raised, in: Theme.card())
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
      .background {
        if selected {
          // Concentric with the track so the thumb reads as the same material, inset.
          Theme.card(Theme.corner - Self.filterInset).fill(Theme.surface)
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
            .matchedGeometryEffect(id: "filterThumb", in: filterNamespace)
        }
      }
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  private func taskSection(_ items: [TaskItem], state: TaskRow.State) -> some View {
    Section {
      ForEach(items) { item in taskRow(item, state: state) }
    }
  }

  /// A task row with Mail-style swipe actions: leading completes (or restores), trailing deletes.
  /// Full swipes run the first action; VoiceOver exposes both as row actions. The row keeps the
  /// system background: only that background becomes the rounded platter shown while swiping.
  private func taskRow(_ item: TaskItem, state: TaskRow.State) -> some View {
    TaskRow(item: item, state: state, strings: text, toggle: { toggle(item, state: state) }) {
      quickFocused = false
      editor = EditorPresentation(item: item)
    }
    .listRowInsets(EdgeInsets())
    .listRowSeparatorTint(Theme.line)
    .alignmentGuide(.listRowSeparatorLeading) { _ in 55 }
    .swipeActions(edge: .leading, allowsFullSwipe: true) {
      Button {
        toggle(item, state: state)
      } label: {
        Label(
          text(state == .active ? "swipe.complete" : "swipe.restore"),
          systemImage: state == .active ? "checkmark" : "arrow.uturn.backward"
        )
        .labelStyle(.iconOnly)
      }
      .tint(state == .active ? Theme.accent : Color.gray)
      .accessibilityIdentifier(state == .active ? "swipe.complete" : "swipe.restore")
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
      Button(role: .destructive) {
        delete(item)
      } label: {
        Label(text("delete"), systemImage: "trash").labelStyle(.iconOnly)
      }
      // The app-wide accent tint would otherwise override the destructive red.
      .tint(.red)
      .accessibilityIdentifier("swipe.delete")
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
        .background(Theme.accentSoft, in: Theme.card())
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
    // Spacing stays below the 10 pt gaps so the shapes only blend while they animate.
    GlassGroup(spacing: 8) {
      VStack(spacing: 10) {
        if let pendingUndo {
          HStack {
            Label(
              text(pendingUndo.isDeletion ? "undo.deleted" : "undo.completed"),
              systemImage: pendingUndo.isDeletion ? "trash.fill" : "checkmark.circle.fill"
            )
            .font(.subheadline).foregroundStyle(Theme.ink)
            Spacer()
            Button(text("undo.action")) { undo(pendingUndo) }
              .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
              .frame(minHeight: 44)
              .accessibilityIdentifier("undoAction")
          }
          .padding(.leading, 20).padding(.trailing, 16).padding(.vertical, 4)
          .glassLayer(in: Theme.card())
          .transition(.move(edge: .bottom).combined(with: .opacity))
          .task(id: pendingUndo.id) {
            // VoiceOver users hear the result and keep the banner until they act or a new
            // action replaces it; six seconds is too short to reach the button.
            AccessibilityNotification.Announcement(
              text(pendingUndo.isDeletion ? "undo.deleted" : "undo.completed")
            ).post()
            guard !voiceOverEnabled else { return }
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled, !undoFailed else { return }
            withAnimation(animation) { self.pendingUndo = nil }
          }
        }
        HStack(alignment: .bottom, spacing: 10) {
          Button {
            quickFocused = false
            editor = EditorPresentation(initialTitle: quickTitle)
          } label: {
            Image(systemName: "plus").font(.system(size: 20, weight: .medium))
              .foregroundStyle(Theme.ink).frame(width: 52, height: 52)
              .contentShape(Circle())
          }
          .buttonStyle(.plain)
          .glassLayer(in: Circle(), interactive: true)
          .accessibilityLabel(text("quick.details"))
          .accessibilityIdentifier("newTaskDetails")

          HStack(spacing: 4) {
            TextField(text("quick.placeholder"), text: $quickTitle)
              .font(.body).foregroundStyle(Theme.ink).focused($quickFocused)
              .submitLabel(.done).onSubmit(addQuickTask)
              .padding(.leading, 20).padding(.vertical, 14)
              .accessibilityIdentifier("quickAdd")
            if canQuickAdd {
              Button(action: addQuickTask) {
                Image(systemName: "arrow.up").font(.system(size: 17, weight: .semibold))
                  .foregroundStyle(Theme.onAccent).frame(width: 40, height: 40)
                  .background(Theme.accent, in: Circle())
                  .frame(width: 44, height: 52)
                  .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .padding(.trailing, 2)
              .transition(.scale.combined(with: .opacity))
              .accessibilityLabel(text("quick.add"))
              .accessibilityIdentifier("quickAddSubmit")
            }
          }
          .frame(minHeight: 52)
          .glassLayer(in: Theme.card())
        }
      }
    }
    .animation(animation, value: canQuickAdd)
    .padding(.horizontal, Theme.barPadding).padding(.top, 8).padding(.bottom, 8)
  }

  private var reminderPrompt: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "bell.badge").font(.title3).foregroundStyle(Theme.accent)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 6) {
          Text(text("permission.title")).font(.subheadline.weight(.semibold)).foregroundStyle(
            Theme.ink)
          Text(text("permission.body")).font(.footnote).foregroundStyle(Theme.secondary)
        }
      }
      HStack(spacing: 10) {
        Button {
          settingsPresented = true
        } label: {
          Text(text("permission.enable")).foregroundStyle(Theme.onAccent)
        }
        .font(.subheadline.weight(.semibold))
        .glassButtonStyle(prominent: true)
        Button(text("permission.later")) { settings.reminderPromptDismissed = true }
          .font(.subheadline).foregroundStyle(Theme.secondary)
          .glassButtonStyle()
      }
      .buttonBorderShape(.capsule)
      .controlSize(.large)
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Theme.accentSoft.opacity(0.7), in: Theme.card())
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
            pendingUndo = .completion(undo)
            completionCount += 1
          }
        } else {
          try store.restore(id: item.id, expectedCycle: item.cycleToken)
        }
      }
    }
  }

  private func delete(_ item: TaskItem) {
    withAnimation(animation) {
      store.perform {
        try store.delete(item.id)
        undoFailed = false
        pendingUndo = .deletion(item)
      }
    }
  }

  private func undo(_ pending: PendingUndo) {
    do {
      switch pending.kind {
      case .completion(let undo): try store.undoCompletion(undo)
      case .deletion(let item): try store.undoDeletion(item)
      }
      withAnimation(animation) { pendingUndo = nil }
      undoFailed = false
    } catch {
      undoFailed = true
      store.error = error
    }
  }
}

/// The last reversible action, offered in the floating undo banner.
private struct PendingUndo: Identifiable {
  enum Kind {
    case completion(CompletionUndo)
    case deletion(TaskItem)
  }

  let kind: Kind
  /// Unique per action so the banner timer restarts even for the same task.
  let id = UUID()

  static func completion(_ undo: CompletionUndo) -> Self { Self(kind: .completion(undo)) }
  static func deletion(_ item: TaskItem) -> Self { Self(kind: .deletion(item)) }

  var isDeletion: Bool {
    if case .deletion = kind { true } else { false }
  }
}

extension View {
  /// A list row that renders its own content on the page background, without row chrome.
  fileprivate func plainListRow() -> some View {
    listRowInsets(EdgeInsets()).listRowBackground(Color.clear).listRowSeparator(.hidden)
  }
}

private struct EditorPresentation: Identifiable {
  let id = UUID()
  var item: TaskItem? = nil
  var initialTitle = ""
}
