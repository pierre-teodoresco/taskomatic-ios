import Foundation
import Observation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
  case system, en, fr
  var id: String { rawValue }
}

enum AppAppearance: String, CaseIterable, Identifiable {
  case system, light, dark
  var id: String { rawValue }
  var colorScheme: ColorScheme? {
    switch self {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
  }
}

@MainActor @Observable
final class AppSettings {
  private let defaults: UserDefaults
  var language: AppLanguage { didSet { defaults.set(language.rawValue, forKey: "language") } }
  var appearance: AppAppearance {
    didSet { defaults.set(appearance.rawValue, forKey: "appearance") }
  }
  var remindersEnabled: Bool {
    didSet { defaults.set(remindersEnabled, forKey: "remindersEnabled") }
  }
  var reminderHour: Int { didSet { defaults.set(reminderHour, forKey: "reminderHour") } }
  var reminderMinute: Int { didSet { defaults.set(reminderMinute, forKey: "reminderMinute") } }
  var weekdays: Set<Int> { didSet { defaults.set(Array(weekdays), forKey: "weekdays") } }
  var reminderPromptDismissed: Bool {
    didSet { defaults.set(reminderPromptDismissed, forKey: "reminderPromptDismissed") }
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    language = AppLanguage(rawValue: defaults.string(forKey: "language") ?? "system") ?? .system
    appearance =
      AppAppearance(rawValue: defaults.string(forKey: "appearance") ?? "system") ?? .system
    remindersEnabled = defaults.bool(forKey: "remindersEnabled")
    reminderHour = defaults.object(forKey: "reminderHour") as? Int ?? 9
    reminderMinute = defaults.integer(forKey: "reminderMinute")
    weekdays = Set(defaults.array(forKey: "weekdays") as? [Int] ?? Array(1...7))
    reminderPromptDismissed = defaults.bool(forKey: "reminderPromptDismissed")
  }

  var strings: AppStrings { AppStrings(language: language) }

  var reminderTime: Date {
    get {
      Calendar.current.date(
        bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: .now) ?? .now
    }
    set {
      let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
      reminderHour = parts.hour ?? 9
      reminderMinute = parts.minute ?? 0
    }
  }
}
