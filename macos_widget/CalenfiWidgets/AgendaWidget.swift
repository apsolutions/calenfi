import SwiftUI
import WidgetKit

/// «Сегодня» — повестка дня из снимка приложения.
struct AgendaEntry: TimelineEntry {
  let date: Date
  let snapshot: WidgetSnapshot
}

struct AgendaProvider: TimelineProvider {
  func placeholder(in context: Context) -> AgendaEntry {
    AgendaEntry(date: Date(), snapshot: .empty)
  }

  func getSnapshot(in context: Context, completion: @escaping (AgendaEntry) -> Void) {
    completion(AgendaEntry(date: Date(), snapshot: WidgetSnapshot.load()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<AgendaEntry>) -> Void) {
    let now = Date()
    let snapshot = WidgetSnapshot.load()
    // Перерисовываем каждые 15 минут (прошедшие встречи гаснут) и обязательно
    // сразу после полуночи, чтобы день сменился без запуска приложения.
    var entries: [AgendaEntry] = []
    for step in 0..<8 {
      let date = now.addingTimeInterval(Double(step) * 900)
      entries.append(AgendaEntry(date: date, snapshot: snapshot))
    }
    let calendar = Calendar.current
    let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
    let refresh = min(midnight, now.addingTimeInterval(2 * 3600))
    completion(Timeline(entries: entries, policy: .after(refresh)))
  }
}

struct AgendaWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: AgendaEntry

  private var calendar: Calendar { Calendar.current }

  private var limit: Int {
    switch family {
    case .systemSmall: return 3
    case .systemMedium: return 5
    default: return 12
    }
  }

  private var events: [WidgetEvent] {
    entry.snapshot.agenda(for: entry.date, calendar: calendar)
  }

  private var header: String {
    let f = DateFormatter()
    f.locale = Locale.current
    f.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
    return f.string(from: entry.date)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline) {
        Text(header)
          .font(.headline)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
        Spacer(minLength: 4)
        if !events.isEmpty {
          Text("\(events.count)")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
      if events.isEmpty {
        Spacer(minLength: 0)
        Text("Встреч нет")
          .font(.callout)
          .foregroundStyle(.secondary)
        Spacer(minLength: 0)
      } else {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 4 : 6) {
          ForEach(events.prefix(limit)) { event in
            AgendaRow(event: event, compact: family == .systemSmall, now: entry.date)
          }
          if events.count > limit {
            Text("+ ещё \(events.count - limit)")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
        Spacer(minLength: 0)
      }
    }
  }
}

private struct AgendaRow: View {
  let event: WidgetEvent
  let compact: Bool
  let now: Date

  /// Прошедшие встречи приглушаем — виджет читается «сверху вниз по времени».
  private var past: Bool { !event.allDay && event.end < now }

  var body: some View {
    HStack(alignment: .top, spacing: 6) {
      RoundedRectangle(cornerRadius: 1.5)
        .fill(event.color)
        .frame(width: 3)
        .frame(maxHeight: .infinity)
      VStack(alignment: .leading, spacing: 1) {
        Text(event.title.isEmpty ? "(без названия)" : event.title)
          .font(compact ? .caption : .subheadline)
          .lineLimit(1)
        HStack(spacing: 4) {
          Text(event.allDay ? "весь день" : event.time)
          if !compact, !event.location.isEmpty {
            Text("·")
            Text(event.location).lineLimit(1)
          }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
      }
      Spacer(minLength: 0)
    }
    .fixedSize(horizontal: false, vertical: true)
    .opacity(past ? 0.45 : 1)
  }
}

struct AgendaWidget: Widget {
  static let kind = WidgetKinds.agenda

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Self.kind, provider: AgendaProvider()) { entry in
      AgendaWidgetView(entry: entry)
        .containerBackground(for: .widget) { Color.clear }
    }
    .configurationDisplayName("Calenfi — сегодня")
    .description("Дела на сегодня из всех подключённых календарей.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}
