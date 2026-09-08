import SwiftUI
import TaskomaticCore

struct RecurrencePicker: View {
  @Binding var recurrence: Recurrence?
  @Environment(AppSettings.self) private var settings
  @Environment(\.dismiss) private var dismiss
  @State private var custom = false
  @State private var interval = 1
  @State private var unit: Recurrence.Unit = .week

  private var text: AppStrings { settings.strings }
  private let presets: [(String, Recurrence?)] = [
    ("repeat.never", nil),
    ("repeat.daily", Recurrence(interval: 1, unit: .day)),
    ("repeat.weekly", Recurrence(interval: 1, unit: .week)),
    ("repeat.fortnightly", Recurrence(interval: 2, unit: .week)),
    ("repeat.monthly", Recurrence(interval: 1, unit: .month)),
  ]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Surface {
          VStack(spacing: 0) {
            ForEach(presets, id: \.0) { key, value in
              Button {
                recurrence = value
                dismiss()
              } label: {
                HStack {
                  Text(text(key)).foregroundStyle(Theme.ink)
                  Spacer()
                  if recurrence == value {
                    Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                  }
                }.padding(18).frame(minHeight: 54)
              }.buttonStyle(.plain).accessibilityIdentifier(key)
              if key != "repeat.monthly" { Divider().overlay(Theme.line).padding(.leading, 18) }
            }
          }
        }
        VStack(alignment: .leading, spacing: 16) {
          Toggle(text("repeat.custom"), isOn: $custom).font(.body.weight(.medium))
            .tint(Theme.accent).accessibilityIdentifier("customRecurrence")
          if custom {
            Stepper(value: $interval, in: 1...99) {
              Text("\(text("repeat.every")) \(interval)").monospacedDigit()
            }.accessibilityIdentifier("recurrenceInterval")
            Picker(text("repeat.interval"), selection: $unit) {
              ForEach(Recurrence.Unit.allCases, id: \.self) { unit in
                Text(text("repeat.\(unit.rawValue)")).tag(unit)
              }
            }.pickerStyle(.segmented)
            PrimaryButton(title: text("done")) {
              recurrence = Recurrence(interval: interval, unit: unit)
              dismiss()
            }
          }
        }.padding(20).background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.corner))
        Text(text("repeat.explanation")).font(.footnote).foregroundStyle(Theme.secondary)
          .lineSpacing(4)
      }.padding(Theme.pagePadding)
    }
    .background(Theme.canvas)
    .navigationTitle(text("repeat.title"))
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      if let recurrence {
        interval = recurrence.interval
        unit = recurrence.unit
        custom = !presets.contains { $0.1 == recurrence }
      }
    }
  }
}
