import Foundation
import TaskomaticCore

struct AppStrings: Sendable {
  let language: AppLanguage

  var code: String {
    switch language {
    case .en: "en"
    case .fr: "fr"
    case .system: Bundle.main.preferredLocalizations.first ?? "en"
    }
  }

  var locale: Locale { Locale(identifier: code) }

  func callAsFunction(_ key: String, _ arguments: CVarArg...) -> String {
    let bundle =
      Bundle.main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
    let value = bundle.localizedString(forKey: key, value: key, table: nil)
    return arguments.isEmpty ? value : String(format: value, locale: locale, arguments: arguments)
  }

  func recurrence(_ recurrence: Recurrence) -> String {
    let suffix = recurrence.interval == 1 ? "one" : "many"
    return self("repeat.\(recurrence.unit.rawValue).\(suffix)", recurrence.interval)
  }

  func returnDate(_ date: Date, now: Date = .now) -> String {
    let calendar = Calendar.current
    let days =
      calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: date).day ?? 0
    if days == 1 { return self("returns.tomorrow") }
    if days < 7 { return self("returns.days", max(0, days)) }
    return self("returns.date", date.formatted(.dateTime.day().month(.abbreviated).locale(locale)))
  }
}
