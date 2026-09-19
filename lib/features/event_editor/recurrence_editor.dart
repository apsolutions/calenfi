import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Редактор правила повторения (RRULE, RFC 5545) в стиле диалога Outlook:
/// периодичность (день/неделя/месяц/год) + «каждые N», дни недели для
/// еженедельных, «в N-й день» / «в N-й вторник» для месячных/годовых и
/// диапазон: без конца / после N повторений / до даты (FR-E6).
///
/// Работает со строкой RRULE БЕЗ префикса `RRULE:` — как хранит
/// `CalendarEvent.recurrenceRule`.

/// Показать диалог. Возвращает:
///  • новую строку RRULE — «Готово»;
///  • пустую строку — «Не повторять» (сброс правила);
///  • null — «Отмена» (ничего не менять).
Future<String?> showRecurrenceDialog(BuildContext context,
    {String? initial, required DateTime start}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _RecurrenceDialog(initial: initial, start: start),
  );
}

/// Человекочитаемое описание правила для строки в редакторе:
/// «Каждые 2 недели: Пн, Ср · до 30.09.2026».
String describeRecurrence(BuildContext context, String? rrule) {
  final l10n = L10n.of(context);
  if (rrule == null || rrule.trim().isEmpty) return l10n.edDoNotRepeat;
  final r = _Rule.parse(rrule);
  if (r == null) return rrule; // незнакомый RRULE — показываем как есть

  final n = r.interval;
  var s = switch (r.freq) {
    _Freq.daily => n == 1 ? l10n.edDaily : l10n.edEveryNDays(n),
    _Freq.weekly => n == 1 ? l10n.edWeekly : l10n.edEveryNWeeks(n),
    _Freq.monthly => n == 1 ? l10n.edMonthly : l10n.edEveryNMonths(n),
    _Freq.yearly => n == 1 ? l10n.edYearly : l10n.edEveryNYears(n),
  };
  if (r.freq == _Freq.weekly && r.weekdays.isNotEmpty) {
    final short = _weekdayShort(l10n);
    final names = [for (final d in r.weekdays) short[d - 1]];
    s += ': ${names.join(', ')}';
  }
  if (r.freq == _Freq.monthly || r.freq == _Freq.yearly) {
    if (r.bySetDay != null) {
      s += ': ${_ordinalName(l10n, r.bySetPos!)} '
          '${_weekdayAcc(l10n)[r.bySetDay! - 1]}';
    } else if (r.monthDay != null) {
      s += ': ${l10n.edOnDayOfMonth(r.monthDay!)}';
    }
  }
  if (r.count != null) s += ' · ${count(context, r.count!)}';
  if (r.until != null) {
    // Календарная дата UNTIL как есть, без конвертации таймзон: UNTIL хранится
    // концом дня UTC, и toLocal() сдвигал бы «до 31.07» на «до 01.08».
    final u = r.until!;
    final date = '${u.day.toString().padLeft(2, '0')}.'
        '${u.month.toString().padLeft(2, '0')}.${u.year}';
    s += ' · ${l10n.edUntilDate(date)}';
  }
  return s;
}

String count(BuildContext context, int c) => L10n.of(context).edOccurrences(c);

List<String> _weekdayShort(L10n l10n) => [
      l10n.edMon, l10n.edTue, l10n.edWed, l10n.edThu, l10n.edFri, l10n.edSat,
      l10n.edSun,
    ];
// винительный падеж («во 2-й вторник») — только для русского, иначе обычная форма
List<String> _weekdayAcc(L10n l10n) => [
      l10n.edMondayAcc, l10n.edTuesdayAcc, l10n.edWednesdayAcc,
      l10n.edThursdayAcc, l10n.edFridayAcc, l10n.edSaturdayAcc,
      l10n.edSundayAcc,
    ];
const _icalDays = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

String _ordinalName(L10n l10n, int p) => switch (p) {
      1 => l10n.edOrdinal1,
      2 => l10n.edOrdinal2,
      3 => l10n.edOrdinal3,
      4 => l10n.edOrdinal4,
      -1 => l10n.edOrdinalLast,
      _ => l10n.edOrdinalN(p),
    };

enum _Freq { daily, weekly, monthly, yearly }

/// Окончание серии.
enum _EndMode { never, afterCount, byDate }

/// Разобранное правило (подмножество RRULE, которое умеет строить диалог).
class _Rule {
  _Rule({required this.freq, this.interval = 1, Set<int>? weekdays})
      : weekdays = weekdays ?? {};

  _Freq freq;
  int interval;

  /// Дни недели (1=Пн … 7=Вс) для еженедельных.
  final Set<int> weekdays;

  /// «N-го числа» для месячных/годовых (BYMONTHDAY).
  int? monthDay;

  /// «В [bySetPos]-й [bySetDay]» (BYDAY=2TU): позиция 1..4 или -1 (последний).
  int? bySetPos;
  int? bySetDay; // 1=Пн … 7=Вс

  /// Месяц для годовых (BYMONTH).
  int? month;

  int? count;
  DateTime? until;

  static _Rule? parse(String rrule) {
    final p = <String, String>{};
    for (final part in rrule.trim().split(';')) {
      final eq = part.indexOf('=');
      if (eq > 0) p[part.substring(0, eq).toUpperCase()] = part.substring(eq + 1);
    }
    final freq = switch (p['FREQ']?.toUpperCase()) {
      'DAILY' => _Freq.daily,
      'WEEKLY' => _Freq.weekly,
      'MONTHLY' => _Freq.monthly,
      'YEARLY' => _Freq.yearly,
      _ => null,
    };
    if (freq == null) return null;

    final r = _Rule(freq: freq, interval: int.tryParse(p['INTERVAL'] ?? '') ?? 1);

    final byday = p['BYDAY']?.split(',') ?? const [];
    for (final d in byday) {
      final m = RegExp(r'^(-?\d+)?([A-Z]{2})$').firstMatch(d.trim().toUpperCase());
      if (m == null) continue;
      final day = _icalDays.indexOf(m.group(2)!) + 1;
      if (day == 0) continue;
      final pos = m.group(1);
      if (pos != null && pos.isNotEmpty) {
        r.bySetPos = int.tryParse(pos);
        r.bySetDay = day;
      } else {
        r.weekdays.add(day);
      }
    }
    // BYSETPOS=2;BYDAY=TU — эквивалент BYDAY=2TU.
    final setpos = int.tryParse(p['BYSETPOS'] ?? '');
    if (setpos != null && r.weekdays.length == 1) {
      r.bySetPos = setpos;
      r.bySetDay = r.weekdays.first;
      r.weekdays.clear();
    }
    r.monthDay = int.tryParse(p['BYMONTHDAY'] ?? '');
    r.month = int.tryParse(p['BYMONTH'] ?? '');
    r.count = int.tryParse(p['COUNT'] ?? '');
    final until = p['UNTIL'];
    if (until != null) {
      r.until = DateTime.tryParse(until) ??
          DateTime.tryParse(
              '${until.substring(0, 8)}T${until.length > 9 ? until.substring(9) : '000000'}');
    }
    return r;
  }

  String build() {
    final parts = <String>['FREQ=${freq.name.toUpperCase()}'];
    if (interval > 1) parts.add('INTERVAL=$interval');
    if (freq == _Freq.weekly && weekdays.isNotEmpty) {
      final ds = weekdays.toList()..sort();
      parts.add('BYDAY=${ds.map((d) => _icalDays[d - 1]).join(',')}');
    }
    if (freq == _Freq.monthly || freq == _Freq.yearly) {
      if (bySetDay != null && bySetPos != null) {
        parts.add('BYDAY=$bySetPos${_icalDays[bySetDay! - 1]}');
      } else if (monthDay != null) {
        parts.add('BYMONTHDAY=$monthDay');
      }
      if (freq == _Freq.yearly && month != null) parts.add('BYMONTH=$month');
    }
    if (count != null) parts.add('COUNT=$count');
    if (until != null) {
      // Берём календарную дату как выбрана (без toUtc: полночь 31.07 МСК
      // превратилась бы в 30.07 UTC — серия кончалась бы днём раньше).
      final u = until!;
      String two(int v) => v.toString().padLeft(2, '0');
      parts.add('UNTIL=${u.year}${two(u.month)}${two(u.day)}T235959Z');
    }
    return parts.join(';');
  }
}

class _RecurrenceDialog extends StatefulWidget {
  const _RecurrenceDialog({this.initial, required this.start});
  final String? initial;
  final DateTime start;

  @override
  State<_RecurrenceDialog> createState() => _RecurrenceDialogState();
}

class _RecurrenceDialogState extends State<_RecurrenceDialog> {
  late _Rule _rule;
  late _EndMode _end;
  late TextEditingController _intervalCtl;
  late TextEditingController _countCtl;

  /// Месячный/годовой режим: false = «N-го числа», true = «в N-й вторник».
  bool _relative = false;

  @override
  void initState() {
    super.initState();
    final s = widget.start;
    final parsed =
        widget.initial == null ? null : _Rule.parse(widget.initial!);
    _rule = parsed ?? _Rule(freq: _Freq.weekly, weekdays: {s.weekday});
    if (_rule.freq == _Freq.weekly && _rule.weekdays.isEmpty) {
      _rule.weekdays.add(s.weekday);
    }
    _relative = _rule.bySetDay != null;
    _end = _rule.count != null
        ? _EndMode.afterCount
        : _rule.until != null
            ? _EndMode.byDate
            : _EndMode.never;
    _intervalCtl = TextEditingController(text: '${_rule.interval}');
    _countCtl = TextEditingController(text: '${_rule.count ?? 10}');
  }

  @override
  void dispose() {
    _intervalCtl.dispose();
    _countCtl.dispose();
    super.dispose();
  }

  /// Дефолты «N-го числа» / «в N-й вторник» из даты начала события.
  int get _startMonthDay => widget.start.day;
  int get _startWeekday => widget.start.weekday;
  int get _startWeekOrdinal {
    final ord = ((widget.start.day - 1) ~/ 7) + 1;
    return ord >= 5 ? -1 : ord; // 5-я неделя == «последний»
  }

  String _unitLabel(L10n l10n) => switch (_rule.freq) {
        _Freq.daily => l10n.edUnitDay,
        _Freq.weekly => l10n.edUnitWeek,
        _Freq.monthly => l10n.edUnitMonth,
        _Freq.yearly => l10n.edUnitYear,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AlertDialog(
      title: Text(l10n.edRecurrenceTitle),
      content: SizedBox(
        // Жёсткие 380 точек не влезали в телефон: у AlertDialog по 40 точек
        // отступа с каждой стороны, и на экране 400 строка уезжала вправо.
        width: math.min(
            380.0, MediaQuery.of(context).size.width - 80).clamp(240.0, 380.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── периодичность ─────────────────────────────────────────
              SegmentedButton<_Freq>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                segments: [
                  ButtonSegment(value: _Freq.daily, label: Text(l10n.edFreqDay)),
                  ButtonSegment(
                      value: _Freq.weekly, label: Text(l10n.edFreqWeek)),
                  ButtonSegment(
                      value: _Freq.monthly, label: Text(l10n.edFreqMonth)),
                  ButtonSegment(
                      value: _Freq.yearly, label: Text(l10n.edFreqYear)),
                ],
                selected: {_rule.freq},
                onSelectionChanged: (s) => setState(() {
                  _rule.freq = s.first;
                  if (_rule.freq == _Freq.weekly && _rule.weekdays.isEmpty) {
                    _rule.weekdays.add(_startWeekday);
                  }
                }),
              ),
              const SizedBox(height: 12),
              // ── каждые N ──────────────────────────────────────────────
              Row(
                children: [
                  Text(l10n.edEvery),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 56,
                    child: TextField(
                      controller: _intervalCtl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(isDense: true),
                      onChanged: (v) =>
                          _rule.interval = (int.tryParse(v) ?? 1).clamp(1, 99),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_unitLabel(l10n)),
                ],
              ),
              // ── дни недели (еженедельно) ──────────────────────────────
              if (_rule.freq == _Freq.weekly) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: [
                    for (var d = 1; d <= 7; d++)
                      FilterChip(
                        label: Text(_weekdayShort(l10n)[d - 1]),
                        visualDensity: VisualDensity.compact,
                        selected: _rule.weekdays.contains(d),
                        onSelected: (on) => setState(() {
                          if (on) {
                            _rule.weekdays.add(d);
                          } else if (_rule.weekdays.length > 1) {
                            _rule.weekdays.remove(d); // хотя бы один день
                          }
                        }),
                      ),
                  ],
                ),
              ],
              // ── месячные/годовые: число или N-й день недели ───────────
              if (_rule.freq == _Freq.monthly ||
                  _rule.freq == _Freq.yearly) ...[
                const SizedBox(height: 8),
                RadioGroup<bool>(
                  groupValue: _relative,
                  onChanged: (v) => setState(() {
                    _relative = v!;
                    if (_relative) {
                      _rule
                        ..bySetPos = _startWeekOrdinal
                        ..bySetDay = _startWeekday
                        ..monthDay = null;
                    } else {
                      _rule
                        ..bySetPos = null
                        ..bySetDay = null
                        ..monthDay = _startMonthDay;
                    }
                    if (_rule.freq == _Freq.yearly) {
                      _rule.month = widget.start.month;
                    }
                  }),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<bool>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: false,
                        title: Text(l10n.edOnDayOfMonth(_startMonthDay)),
                      ),
                      RadioListTile<bool>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: true,
                        title: Text(
                            '${_ordinalName(l10n, _startWeekOrdinal)} ${_weekdayAcc(l10n)[_startWeekday - 1]}'),
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(height: 20),
              // ── окончание ─────────────────────────────────────────────
              RadioGroup<_EndMode>(
                groupValue: _end,
                onChanged: (v) => setState(() => _end = v!),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<_EndMode>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _EndMode.never,
                      title: Text(l10n.edNoEndDate),
                    ),
                    RadioListTile<_EndMode>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _EndMode.afterCount,
                      title: Row(
                        children: [
                          Flexible(child: Text(l10n.edEndAfter)),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 48,
                            child: TextField(
                              controller: _countCtl,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(isDense: true),
                              onTap: () =>
                                  setState(() => _end = _EndMode.afterCount),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                              child: Text(l10n.edOccurrencesLabel,
                                  overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                    RadioListTile<_EndMode>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _EndMode.byDate,
                      title: Row(
                        children: [
                          Flexible(child: Text(l10n.edUntil)),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () async {
                              final now = widget.start;
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _rule.until ??
                                    now.add(const Duration(days: 90)),
                                firstDate: now,
                                lastDate:
                                    now.add(const Duration(days: 365 * 10)),
                              );
                              if (picked != null) {
                                setState(() {
                                  _end = _EndMode.byDate;
                                  _rule.until = picked;
                                });
                              }
                            },
                            child: Text(_rule.until == null
                                ? l10n.edChoose
                                : '${_rule.until!.day.toString().padLeft(2, '0')}.'
                                    '${_rule.until!.month.toString().padLeft(2, '0')}.'
                                    '${_rule.until!.year}'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.initial != null)
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: Text(l10n.edDoNotRepeat),
          ),
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l10n.edCancel)),
        FilledButton(
          onPressed: () {
            _rule.interval =
                (int.tryParse(_intervalCtl.text) ?? 1).clamp(1, 99);
            // месячные/годовые без выбора режима → «N-го числа» из даты начала
            if ((_rule.freq == _Freq.monthly || _rule.freq == _Freq.yearly) &&
                _rule.monthDay == null &&
                _rule.bySetDay == null) {
              _rule.monthDay = _startMonthDay;
              if (_rule.freq == _Freq.yearly) _rule.month = widget.start.month;
            }
            switch (_end) {
              case _EndMode.never:
                _rule
                  ..count = null
                  ..until = null;
              case _EndMode.afterCount:
                _rule
                  ..count = (int.tryParse(_countCtl.text) ?? 10).clamp(1, 999)
                  ..until = null;
              case _EndMode.byDate:
                _rule
                  ..count = null
                  ..until ??= widget.start.add(const Duration(days: 90));
            }
            Navigator.pop(context, _rule.build());
          },
          child: Text(l10n.edDone),
        ),
      ],
    );
  }
}
