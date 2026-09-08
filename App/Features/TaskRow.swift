import SwiftUI
import TaskomaticCore

struct TaskRow: View {
  let item: TaskItem
  let state: State
  let strings: AppStrings
  let toggle: () -> Void
  let edit: () -> Void

  enum State { case active, waiting, completed }

  var body: some View {
    HStack(alignment: .top, spacing: 4) {
      Button(action: toggle) {
        Image(
          systemName: state == .completed
            ? "checkmark.circle.fill" : state == .waiting ? "arrow.clockwise.circle" : "circle"
        )
        .font(.system(size: 24, weight: .light))
        .foregroundStyle(
          state == .completed
            ? Theme.accent : state == .waiting ? Theme.secondary : Theme.secondary.opacity(0.65)
        )
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(strings(state == .active ? "row.complete" : "row.restore", item.title))
      .accessibilityIdentifier("\(state == .active ? "complete" : "restore").\(item.title)")

      Button(action: edit) {
        VStack(alignment: .leading, spacing: 7) {
          Text(item.title)
            .font(.body.weight(.medium))
            .foregroundStyle(state == .completed ? Theme.secondary : Theme.ink)
            .strikethrough(state == .completed, color: Theme.secondary.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
          if !item.note.isEmpty {
            Text(item.note).font(.subheadline).foregroundStyle(Theme.secondary)
              .lineLimit(2).multilineTextAlignment(.leading)
          }
          if let recurrence = item.recurrence {
            Label {
              Text(
                state == .waiting
                  ? item.nextActivation(calendar: .current).map { strings.returnDate($0) }
                    ?? strings.recurrence(recurrence)
                  : strings.recurrence(recurrence))
            } icon: {
              Image(systemName: "repeat")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(state == .waiting ? Theme.secondary : Theme.accent)
          }
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("taskTitle.\(item.title)")
      .accessibilityHint(strings("editor.edit"))
    }
    .padding(.vertical, 7)
    .padding(.leading, 7)
    .padding(.trailing, 20)
  }
}
