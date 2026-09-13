import Foundation
import SwiftUI

/// Снимок повестки, который пишет приложение
/// (`lib/features/widget/agenda_widget_service.dart`, `_writeMacosSnapshot`).
///
/// Обмен идёт файлом, а не App Group: группы требуют provisioning profile от
/// Apple Developer, а Calenfi подписывается ad-hoc. Расширение собрано без
/// песочницы, поэтому читает тот же конфиг-каталог, что и приложение —
/// `~/Library/Application Support/calenfi` (см. `data_dir.dart`).
/// Идентификаторы таймлайнов. Вынесены из типов виджетов: те изолированы
/// главным актором, и обращение к их свойствам из AppIntent — предупреждение,
/// которое в Swift 6 станет ошибкой.
enum WidgetKinds {
  static let agenda = "CalenfiAgendaWidget"
  static let miniCalendar = "CalenfiMiniCalendarWidget"
}

enum SnapshotLocation {
  /// Настоящий домашний каталог пользователя. В песочнице (а расширение обязано
  /// быть в ней, иначе macOS его не регистрирует) `homeDirectoryForCurrentUser`
  /// отдаёт контейнер расширения, где снимка нет, — берём путь из passwd.
  private static var realHome: URL {
    if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
      return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
    }
    return FileManager.default.homeDirectoryForCurrentUser
  }

  static var fileURL: URL {
    realHome
      .appendingPathComponent("Library/Application Support/calenfi", isDirectory: true)
      .appendingPathComponent("widget_snapshot.json", isDirectory: false)
  }
}

struct WidgetEvent: Decodable, Identifiable {
  let startMs: Int
  let endMs: Int
  let allDay: Bool
  let startDate: String?
  let endDate: String?
  let time: String
  let title: String
  let location: String
  let colorValue: Int

  var id: String { "\(startMs)-\(endMs)-\(title)" }

  enum CodingKeys: String, CodingKey {
    case startMs = "start_ms"
    case endMs = "end_ms"
    case allDay = "all_day"
    case startDate = "start_date"
    case endDate = "end_date"
    case time, title, location
    case colorValue = "color"
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    startMs = try c.decodeIfPresent(Int.self, forKey: .startMs) ?? 0
    endMs = try c.decodeIfPresent(Int.self, forKey: .endMs) ?? 0
    allDay = try c.decodeIfPresent(Bool.self, forKey: .allDay) ?? false
    startDate = try c.decodeIfPresent(String.self, forKey: .startDate)
    endDate = try c.decodeIfPresent(String.self, forKey: .endDate)
    time = try c.decodeIfPresent(String.self, forKey: .time) ?? ""
    title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
    location = try c.decodeIfPresent(String.self, forKey: .location) ?? ""
    colorValue = try c.decodeIfPresent(Int.self, forKey: .colorValue) ?? 0xFF8AB4F8
  }

  var start: Date { Date(timeIntervalSince1970: Double(startMs) / 1000) }
  var end: Date { Date(timeIntervalSince1970: Double(endMs) / 1000) }

  /// Цвет календаря приходит как ARGB-число Flutter (`Color.value`).
  var color: Color {
    Color(
      .sRGB,
      red: Double((colorValue >> 16) & 0xFF) / 255,
      green: Double((colorValue >> 8) & 0xFF) / 255,
      blue: Double(colorValue & 0xFF) / 255,
      opacity: 1
    )
  }

  /// Идёт ли событие в этот локальный день. All-day хранится плавающими
  /// датами (без часового пояса), остальное — моментами времени.
  func occurs(on day: Date, calendar: Calendar) -> Bool {
    let dayStart = calendar.startOfDay(for: day)
    guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return false }
    if allDay {
      guard let first = WidgetEvent.floatingDate(startDate, calendar: calendar) else { return false }
      let exclusive = WidgetEvent.floatingDate(endDate, calendar: calendar)
        ?? calendar.date(byAdding: .day, value: 1, to: first)!
      let last = exclusive > first ? exclusive : calendar.date(byAdding: .day, value: 1, to: first)!
      return dayStart >= first && dayStart < last
    }
    // Встреча, кончающаяся ровно в полночь, принадлежит предыдущему дню.
    return start < dayEnd && (end > dayStart || (end == start && start >= dayStart))
  }

  private static func floatingDate(_ raw: String?, calendar: Calendar) -> Date? {
    guard let raw, raw.count >= 10 else { return nil }
    let parts = raw.prefix(10).split(separator: "-")
    guard parts.count == 3,
      let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2])
    else { return nil }
    return calendar.date(from: DateComponents(year: y, month: m, day: d))
  }
}

struct WidgetSnapshot {
  let updated: Date?
  let events: [WidgetEvent]
  let dayCounts: [String: Int]

  static let empty = WidgetSnapshot(updated: nil, events: [], dayCounts: [:])

  static func load() -> WidgetSnapshot {
    guard let data = try? Data(contentsOf: SnapshotLocation.fileURL),
      let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return .empty }

    var events: [WidgetEvent] = []
    if let rawEvents = root["events"],
      let eventData = try? JSONSerialization.data(withJSONObject: rawEvents) {
      events = (try? JSONDecoder().decode([WidgetEvent].self, from: eventData)) ?? []
    }
    let counts = (root["day_counts"] as? [String: Int]) ?? [:]
    let updatedMs = root["updated_epoch_ms"] as? Double
    return WidgetSnapshot(
      updated: updatedMs.map { Date(timeIntervalSince1970: $0 / 1000) },
      events: events,
      dayCounts: counts
    )
  }

  /// Повестка на конкретный день: события «весь день» сверху, дальше по началу.
  func agenda(for day: Date, calendar: Calendar) -> [WidgetEvent] {
    events
      .filter { $0.occurs(on: day, calendar: calendar) }
      .sorted { lhs, rhs in
        if lhs.allDay != rhs.allDay { return lhs.allDay }
        return lhs.startMs < rhs.startMs
      }
  }

  func count(for day: Date, calendar: Calendar) -> Int {
    dayCounts[WidgetSnapshot.key(for: day, calendar: calendar)] ?? 0
  }

  static func key(for day: Date, calendar: Calendar) -> String {
    let c = calendar.dateComponents([.year, .month, .day], from: day)
    return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
  }
}
