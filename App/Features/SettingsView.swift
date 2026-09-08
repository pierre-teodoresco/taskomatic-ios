import SwiftUI
import UserNotifications

struct SettingsView: View {
  @Environment(AppSettings.self) private var settings
  @Environment(AppRuntime.self) private var runtime
  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var testSent = false
  private var text: AppStrings { settings.strings }

  var body: some View {
    @Bindable var settings = settings
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 28) {
          VStack(alignment: .leading, spacing: 12) {
            SectionCaption(title: text("settings.reminders"))
            Surface {
              VStack(alignment: .leading, spacing: 20) {
                Toggle(
                  isOn: Binding(
                    get: { settings.remindersEnabled },
                    set: { enabled in
                      Task {
                        if enabled {
                          settings.remindersEnabled = await runtime.notifications
                            .requestAuthorization()
                        } else {
                          settings.remindersEnabled = false
                        }
                        await runtime.reschedule()
                      }
                    })
                ) {
                  VStack(alignment: .leading, spacing: 7) {
                    Text(text("settings.reminders")).font(.body.weight(.medium))
                    Text(text("settings.reminder.body")).font(.footnote).foregroundStyle(
                      Theme.secondary)
                  }
                }.tint(Theme.accent).accessibilityIdentifier("remindersToggle")
                if settings.remindersEnabled {
                  Divider().overlay(Theme.line)
                  DatePicker(
                    text("settings.time"), selection: $settings.reminderTime,
                    displayedComponents: .hourAndMinute
                  )
                  .accessibilityIdentifier("reminderTime")
                  VStack(alignment: .leading, spacing: 12) {
                    Text(text("settings.days")).font(.subheadline).foregroundStyle(Theme.secondary)
                    weekdayPicker
                  }
                  Text(text("settings.localtime")).font(.footnote).foregroundStyle(Theme.secondary)
                  Button {
                    Task { testSent = await runtime.notifications.sendTest(strings: text) }
                  } label: {
                    Label(text("settings.test"), systemImage: "bell")
                  }
                  .font(.subheadline.weight(.medium)).accessibilityIdentifier("testNotification")
                  if testSent {
                    Text(text("settings.test.sent")).font(.footnote).foregroundStyle(
                      Theme.secondary)
                  }
                }
                if runtime.notifications.authorization == .denied {
                  Text(text("settings.permission.denied")).font(.footnote).foregroundStyle(
                    Theme.secondary)
                  Button(text("settings.openios")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                      UIApplication.shared.open(url)
                    }
                  }.font(.subheadline.weight(.medium))
                }
              }.padding(20)
            }
            if settings.remindersEnabled { reminderStatus }
          }

          VStack(alignment: .leading, spacing: 12) {
            SectionCaption(title: text("settings.appearance"))
            Surface {
              VStack(spacing: 14) {
                Picker(text("settings.appearance"), selection: $settings.appearance) {
                  ForEach(AppAppearance.allCases) { value in
                    Text(text("settings.\(value.rawValue)")).tag(value)
                  }
                }.pickerStyle(.segmented).accessibilityIdentifier("appearancePicker")
                Divider().overlay(Theme.line)
                languageLayout {
                  Label(text("settings.language"), systemImage: "globe")
                    .font(.subheadline)
                  if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
                  Picker(text("settings.language"), selection: $settings.language) {
                    Text(text("settings.system")).tag(AppLanguage.system)
                    Text("Français").tag(AppLanguage.fr)
                    Text("English").tag(AppLanguage.en)
                  }.labelsHidden().accessibilityIdentifier("languagePicker")
                }
              }.padding(20)
            }
          }

          BackupSettingsSection()

          VStack(alignment: .leading, spacing: 12) {
            SectionCaption(title: text("settings.storage"))
            Surface {
              VStack(alignment: .leading, spacing: 12) {
                Label(
                  text(
                    !runtime.cloudEnabled
                      ? "settings.icloud.unavailable"
                      : runtime.cloudAvailable == nil
                        ? "settings.icloud.checking"
                        : runtime.cloudAvailable == true
                          ? "settings.icloud.available" : "settings.icloud.unavailable"),
                  systemImage: runtime.cloudAvailable == true ? "icloud" : "iphone"
                )
                .font(.subheadline.weight(.medium))
                Text(
                  text(
                    runtime.isolated
                      ? "settings.icloud.local"
                      : runtime.cloudEnabled ? "settings.icloud.body" : "settings.icloud.localbuild"
                  )
                )
                .font(.footnote).foregroundStyle(Theme.secondary).lineSpacing(3)
              }.padding(20)
            }
          }

          VStack(spacing: 8) {
            BrandMark(size: 32)
            Text("Taskomatic").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
            Text(
              text(
                "settings.version",
                Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
            )
            .font(.caption).foregroundStyle(Theme.secondary)
          }.frame(maxWidth: .infinity).padding(.vertical, 12)
        }.padding(Theme.pagePadding)
      }
      .background(Theme.canvas)
      .foregroundStyle(Theme.ink)
      .navigationTitle(text("settings.title"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(text("done")) { dismiss() }.accessibilityIdentifier("closeSettings")
        }
      }
    }
    .tint(Theme.accent)
    .presentationDragIndicator(.visible)
    .task { await runtime.notifications.refreshAuthorization() }
  }

  private var languageLayout: AnyLayout {
    dynamicTypeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
      : AnyLayout(HStackLayout())
  }

  private var weekdayPicker: some View {
    let calendar = Calendar.current
    let days = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
    var localized = calendar
    localized.locale = text.locale
    return LazyVGrid(
      columns: [
        GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 100 : 64), spacing: 8)
      ], spacing: 8
    ) {
      ForEach(days, id: \.self) { day in
        let selected = settings.weekdays.contains(day)
        Button {
          if selected && settings.weekdays.count > 1 {
            settings.weekdays.remove(day)
          } else {
            settings.weekdays.insert(day)
          }
        } label: {
          Text(localized.shortStandaloneWeekdaySymbols[day - 1].uppercased())
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(selected ? Theme.onAccent : Theme.secondary)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
            .background(
              selected ? Theme.accent : Theme.raised, in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
          .accessibilityLabel(localized.weekdaySymbols[day - 1])
          .accessibilityAddTraits(selected ? .isSelected : [])
      }
    }
    .sensoryFeedback(.selection, trigger: settings.weekdays)
  }

  @ViewBuilder private var reminderStatus: some View {
    if let error = runtime.notifications.error {
      Text(text("notification.error")).font(.footnote).foregroundStyle(.red)
        .accessibilityHint(error.localizedDescription)
    } else if runtime.notifications.plan?.repeatsIndefinitely == true {
      Text(text("notification.repeating")).font(.footnote).foregroundStyle(Theme.secondary)
    } else if let date = runtime.notifications.plan?.coverageUntil {
      VStack(alignment: .leading, spacing: 6) {
        Text(
          text(
            "notification.coverage",
            date.formatted(.dateTime.day().month(.abbreviated).locale(text.locale)))
        )
        .font(.footnote.weight(.medium))
        Text(text("notification.limit")).font(.footnote).foregroundStyle(Theme.secondary)
      }
    } else {
      Text(text("notification.none")).font(.footnote).foregroundStyle(Theme.secondary)
    }
  }
}
