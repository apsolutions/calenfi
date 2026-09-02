package ru.apsolutions.calenfi

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/** Pure date/time rules shared by the agenda provider and its row factory. */
internal object AgendaWidgetSchedule {
    private const val MIDNIGHT_SETTLE_MILLIS = 2_000L

    /** First safe instant just after the next local-calendar midnight. */
    fun nextRolloverMillis(nowMillis: Long, zoneId: ZoneId = ZoneId.systemDefault()): Long {
        val tomorrow = Instant.ofEpochMilli(nowMillis)
            .atZone(zoneId)
            .toLocalDate()
            .plusDays(1)
        return tomorrow.atStartOfDay(zoneId).toInstant().toEpochMilli() + MIDNIGHT_SETTLE_MILLIS
    }

    /** True when [startMillis, endMillis) intersects the current local day. */
    fun overlapsCurrentDay(
        startMillis: Long,
        endMillis: Long,
        nowMillis: Long,
        zoneId: ZoneId = ZoneId.systemDefault(),
    ): Boolean {
        val today = Instant.ofEpochMilli(nowMillis).atZone(zoneId).toLocalDate()
        val dayStart = today.atStartOfDay(zoneId).toInstant().toEpochMilli()
        val dayEnd = today.plusDays(1).atStartOfDay(zoneId).toInstant().toEpochMilli()
        return startMillis < dayEnd && endMillis > dayStart
    }

    /** True when floating all-day [startDate, endDateExclusive) contains today. */
    fun allDayOverlapsCurrentDay(
        startDate: LocalDate,
        endDateExclusive: LocalDate,
        nowMillis: Long,
        zoneId: ZoneId = ZoneId.systemDefault(),
    ): Boolean {
        val today = Instant.ofEpochMilli(nowMillis).atZone(zoneId).toLocalDate()
        return !startDate.isAfter(today) && endDateExclusive.isAfter(today)
    }

    fun dateLabel(
        nowMillis: Long,
        zoneId: ZoneId = ZoneId.systemDefault(),
        locale: Locale = Locale.getDefault(),
    ): String {
        val date = Instant.ofEpochMilli(nowMillis).atZone(zoneId).toLocalDate()
        val text = DateTimeFormatter.ofPattern("EEEE, d MMMM", locale).format(date)
        return text.replaceFirstChar { char ->
            if (char.isLowerCase()) char.titlecase(locale) else char.toString()
        }
    }

    fun legacySnapshotMatchesToday(
        snapshotLabel: String?,
        nowMillis: Long,
        zoneId: ZoneId = ZoneId.systemDefault(),
        locale: Locale = Locale.getDefault(),
    ): Boolean = snapshotLabel == dateLabel(nowMillis, zoneId, locale)
}
