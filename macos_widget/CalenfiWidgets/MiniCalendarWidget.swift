import AppIntents
import SwiftUI
import WidgetKit

/// Смещение показанного месяца относительно текущего. Живёт в UserDefaults
/// самого расширения: AppIntent выполняется в его же процессе, приложению это
/// состояние не нужно.
enum MonthOffsetStore {
  private static let key = "mini_calendar_month_offset"
  private static let limit = 120  // ±10 лет, чтобы клик не увёл в бесконечность

  static var value: Int {
    get { UserDefaults.standard.integer(forKey: key) }
    set {
      UserDefaults.standard.set(max(-limit, min(limit, newValue)), forKey: key)
    }
  }

  static func shift(by delta: Int) { value = value + delta }
  static func reset() { value = 0 }
}

/// Листание месяцев прямо в виджете (интерактивные виджеты — macOS 14+).
struct ShiftMonthIntent: AppIntent {
  static var title: LocalizedStringResource = "Пролистать месяц"
  static var isDiscoverable: Bool = false

  @Parameter(title: "Смещение")
  var delta: Int

  init() {}
  init(delta: Int) { self.delta = delta }

  func perform() async throws -> some IntentResult {
    MonthOffsetStore.shift(by: delta)
    WidgetCenter.shared.reloadTimelines(ofKind: WidgetKinds.miniCalendar)
    return .result()
  }
}

struct ResetMonthIntent: AppIntent {
  static var title: LocalizedStringResource = "Вернуться к текущему месяцу"
  static var isDiscoverable: Bool = false

  init() {}

  func perform() async throws -> some IntentResult {
    MonthOffsetStore.reset()
    WidgetCenter.shared.reloadTimelines(ofKind: WidgetKinds.miniCalendar)
    return .result()
  }
}

struct MiniCalendarEntry: TimelineEntry {
  let date: Date
  let monthOffset: Int
  let snapshot: WidgetSnapshot
}

struct MiniCalendarProvider: TimelineProvider {
  func placeholder(in context: Context) -> MiniCalendarEntry {
    MiniCalendarEntry(date: Date(), monthOffset: 0, snapshot: .empty)
  }

  func getSnapshot(in context: Context, completion: @escaping (MiniCalendarEntry) -> Void) {
    completion(
      MiniCalendarEntry(
        date: Date(), monthOffset: MonthOffsetStore.value, snapshot: WidgetSnapshot.load()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<MiniCalendarEntry>) -> Void)
  {
    let now = Date()
    let entry = MiniCalendarEntry(
      date: now, monthOffset: MonthOffsetStore.value, snapshot: WidgetSnapshot.load())
    // Сетка меняется только в полночь; чаще перерисовывать нечего.
    let calendar = Calendar.current
    let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
    completion(Timeline(entries: [entry], policy: .after(midnight)))
  }
}

struct MiniCalendarView: View {
  @Environment(\.widgetFamily) private var family
  let entry: MiniCalendarEntry

  private var calendar: Calendar { Calendar.current }

  private var shownMonth: Date {
    let base = calendar.startOfDay(for: entry.date)
    let firstOfMonth = calendar.date(
      from: calendar.dateComponents([.year, .month], from: base))!
    return calendar.date(byAdding: .month, value: entry.monthOffset, to: firstOfMonth)!
  }

  private var title: String {
    let f = DateFormatter()
    f.locale = Locale.current
    f.setLocalizedDateFormatFromTemplate(
      calendar.component(.year, from: shownMonth) == calendar.component(.year, from: entry.date)
        ? "LLLL" : "LLLL yyyy")
    return f.string(from: shownMonth).capitalized(with: Locale.current)
  }

  /// Символы дней недели, начиная с первого дня недели текущей локали.
  private var weekdaySymbols: [String] {
    let symbols = calendar.veryShortStandaloneWeekdaySymbols
    let shift = calendar.firstWeekday - 1
    return Array(symbols[shift...] + symbols[..<shift])
  }

  /// 6 недель по 7 дней: фиксированная высота, чтобы сетка не «прыгала».
  private var gridDays: [Date] {
    let firstOfMonth = shownMonth
    let weekday = calendar.component(.weekday, from: firstOfMonth)
    let lead = (weekday - calendar.firstWeekday + 7) % 7
    let start = calendar.date(byAdding: .day, value: -lead, to: firstOfMonth)!
    return (0..<42).map { calendar.date(byAdding: .day, value: $0, to: start)! }
  }

  private var compact: Bool { family == .systemSmall }

  var body: some View {
    VStack(spacing: compact ? 2 : 4) {
      header
      HStack(spacing: 0) {
        ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
          Text(symbol)
            .font(.system(size: compact ? 8 : 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
        }
      }
      LazyVGrid(
        columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
        spacing: compact ? 1 : 3
      ) {
        ForEach(gridDays, id: \.timeIntervalSince1970) { day in
          DayCell(
            day: day,
            inMonth: calendar.isDate(day, equalTo: shownMonth, toGranularity: .month),
            isToday: calendar.isDate(day, inSameDayAs: entry.date),
            events: entry.snapshot.count(for: day, calendar: calendar),
            compact: compact
          )
        }
      }
      Spacer(minLength: 0)
    }
  }

  private var header: some View {
    HStack(spacing: 2) {
      Button(intent: ShiftMonthIntent(delta: -1)) {
        Image(systemName: "chevron.left")
          .font(.system(size: compact ? 9 : 11, weight: .bold))
      }
      .buttonStyle(.plain)

      if entry.monthOffset == 0 {
        Text(title)
          .font(.system(size: compact ? 11 : 13, weight: .semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .frame(maxWidth: .infinity)
      } else {
        // Тап по названию месяца возвращает к текущему — как в системном
        // календаре кнопка «Сегодня».
        Button(intent: ResetMonthIntent()) {
          Text(title)
            .font(.system(size: compact ? 11 : 13, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
      }

      Button(intent: ShiftMonthIntent(delta: 1)) {
        Image(systemName: "chevron.right")
          .font(.system(size: compact ? 9 : 11, weight: .bold))
      }
      .buttonStyle(.plain)
    }
    .foregroundStyle(.primary)
  }
}

private struct DayCell: View {
  let day: Date
  let inMonth: Bool
  let isToday: Bool
  let events: Int
  let compact: Bool

  private var number: String {
    String(Calendar.current.component(.day, from: day))
  }

  var body: some View {
    VStack(spacing: compact ? 0 : 1) {
      Text(number)
        .font(.system(size: compact ? 9.5 : 11, weight: isToday ? .bold : .regular))
        .foregroundStyle(
          isToday ? Color.white : (inMonth ? Color.primary : Color.secondary.opacity(0.45))
        )
        .frame(width: compact ? 15 : 18, height: compact ? 15 : 18)
        .background {
          if isToday {
            Circle().fill(Color.accentColor.opacity(0.85))
          }
        }
      Circle()
        .fill(events > 0 && inMonth ? Color.accentColor : Color.clear)
        .frame(width: compact ? 2.5 : 3, height: compact ? 2.5 : 3)
    }
    .frame(maxWidth: .infinity)
  }
}

struct MiniCalendarWidget: Widget {
  static let kind = WidgetKinds.miniCalendar

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Self.kind, provider: MiniCalendarProvider()) { entry in
      MiniCalendarView(entry: entry)
        .containerBackground(for: .widget) { Color.clear }
    }
    .configurationDisplayName("Calenfi — календарь")
    .description("Месяц с листанием стрелками и точками в дни со встречами.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
