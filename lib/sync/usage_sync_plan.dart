import 'dart:math' as math;

/// Local wall-clock observations retain the timezone at the time of opening.
class CalendarOpening {
  const CalendarOpening(this.at, this.weekMinute, this.fresh);
  final DateTime at;
  final int weekMinute;
  final bool fresh;
  static int minuteOfWeek(DateTime local) =>
      (local.weekday - 1) * 1440 + local.hour * 60 + local.minute;
}

class SyncTiming {
  const SyncTiming(this.accountId, this.started, this.finished, this.ok);
  final String accountId;
  final DateTime started;
  final DateTime finished;
  final bool ok;
}

/// A small weekday/time histogram, not a guarantee of future behaviour.
/// 95% is target probability mass under this model. Actual opening freshness
/// is measured separately, including cold starts, offline and suspended apps.
class UsageSyncPlan {
  UsageSyncPlan._(
    this.slots,
    this.lead,
    this.modelCoverage,
    this.sampleCount,
    this.observedFreshFraction,
  );
  static const freshness = Duration(minutes: 2);
  static const targetCoverage = .95;
  // Evidence ages only when another day of actual use is observed. Each day
  // contributes one unit of mass, so focus churn cannot replace a habit.
  static const historyHalfLifeDays = 7;
  static const historyDays = 56;
  static int observationDay(DateTime at) =>
      at.toUtc().millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  static const bucketMinutes = 5;
  static const _buckets = 7 * 24 * 60 ~/ bucketMinutes;
  final Set<int> slots;
  final Duration lead;
  final double modelCoverage;
  final int sampleCount;
  final double? observedFreshFraction;

  factory UsageSyncPlan.learn(
    List<CalendarOpening> observations,
    List<SyncTiming> timings,
    DateTime now,
  ) {
    final cutoff = now.subtract(const Duration(days: 56));
    // UTC day boundaries are stable even if the device changes timezone.
    // Predicted windows still use the local weekday/time saved on opening.
    final valid = observations.where((o) => !o.at.isAfter(now)).toList();
    final days = valid.map((o) => observationDay(o.at)).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    final dayAges = {
      for (var i = 0; i < math.min(days.length, historyDays); i++) days[i]: i,
    };
    final recent = valid
        .where((o) => dayAges.containsKey(observationDay(o.at)))
        .toList();
    final dayCounts = <int, int>{};
    for (final o in recent) {
      final day = observationDay(o.at);
      dayCounts[day] = (dayCounts[day] ?? 0) + 1;
    }
    final byAccount = <String, List<int>>{};
    for (final t in timings) {
      if (t.started.isBefore(cutoff) ||
          t.finished.isAfter(now) ||
          !t.ok ||
          t.finished.isBefore(t.started)) {
        continue;
      }
      byAccount
          .putIfAbsent(t.accountId, () => [])
          .add(t.finished.difference(t.started).inSeconds);
    }
    // Use the slowest account's p95; many fast accounts must not conceal one
    // slow calendar. Cold start uses the reported upper duration, 120 seconds.
    var seconds = byAccount.isEmpty ? 120 : 30;
    for (final durations in byAccount.values) {
      durations.sort();
      seconds = math.max(
        seconds,
        durations[(durations.length * .95).ceil() - 1],
      );
    }
    final weights = List<double>.filled(_buckets, 0);
    for (final o in recent) {
      final day = observationDay(o.at);
      final weight =
          math.pow(.5, dayAges[day]! / historyHalfLifeDays).toDouble() /
          dayCounts[day]!;
      final bucket = o.weekMinute ~/ bucketMinutes;
      // Smooth ±5 minutes, including across Sunday/Monday midnight.
      for (final delta in [-1, 0, 1]) {
        weights[(bucket + delta) % _buckets] += weight * (delta == 0 ? .6 : .2);
      }
    }
    final ranked = List<int>.generate(_buckets, (i) => i)
      ..sort((a, b) {
        final c = weights[b].compareTo(weights[a]);
        return c == 0 ? a.compareTo(b) : c;
      });
    final total = weights.fold(0.0, (a, b) => a + b);
    var covered = 0.0;
    final selected = <int>{};
    if (total > 0) {
      for (final slot in ranked) {
        selected.add(slot);
        covered += weights[slot];
        if (covered / total >= targetCoverage) break;
      }
    }
    return UsageSyncPlan._(
      selected,
      Duration(seconds: seconds),
      total == 0 ? 0 : covered / total,
      recent.length,
      recent.isEmpty
          ? null
          : recent.where((o) => o.fresh).length / recent.length,
    );
  }

  /// Include the lead-in before a predicted opening window. DateTime.add
  /// handles timezone/DST transitions in the same way as the running device.
  bool activeAt(DateTime local) {
    for (var seconds = 0; seconds <= lead.inSeconds + 60; seconds += 60) {
      final minute = CalendarOpening.minuteOfWeek(
        local.add(Duration(seconds: seconds)),
      );
      if (slots.contains(minute ~/ bucketMinutes)) return true;
    }
    return false;
  }

  DateTime? nextWake(DateTime local) {
    if (slots.isEmpty) return null;
    // One-minute cadence inside selected windows; the engine serializes
    // passes, including when measured durations exceed this cadence.
    // Advance along the timeline, including during a repeated DST hour.
    // Reconstructing wall-clock components can pick a time in the past.
    var candidate = local
        .subtract(
          Duration(
            seconds: local.second,
            milliseconds: local.millisecond,
            microseconds: local.microsecond,
          ),
        )
        .add(const Duration(minutes: 1));
    for (var i = 0; i <= 7 * 1440; i++) {
      if (activeAt(candidate)) return candidate;
      candidate = candidate.add(const Duration(minutes: 1));
    }
    return null;
  }

  bool needsRefresh({
    required DateTime now,
    required DateTime? lastStarted,
    required DateTime? lastFinished,
    required Duration normalInterval,
    bool opening = false,
    bool foreground = false,
  }) {
    if (normalInterval == Duration.zero) return false;
    if (lastFinished == null) return true;
    if (lastFinished.isAfter(now)) return true; // clock changed
    if (now.difference(lastFinished) >= normalInterval) return true;
    if (!opening && !foreground && !activeAt(now.toLocal())) return false;
    if (lastStarted == null || lastStarted.isAfter(now)) return true;
    // Refresh ahead of expiration, allowing for the observed network cost.
    final ageLimit = opening ? freshness : freshness - lead;
    return now.difference(lastStarted) >=
        (ageLimit.isNegative ? Duration.zero : ageLimit);
  }
}
