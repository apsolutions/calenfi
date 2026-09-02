package ru.apsolutions.calenfi

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.Locale

class AgendaWidgetScheduleTest {
    private val moscow = ZoneId.of("Europe/Moscow")

    @Test
    fun `next rollover is just after next local midnight`() {
        val now = instant(2026, 9, 2, 23, 58)
        val expected = instant(2026, 9, 3, 0, 0) + 2_000L

        assertEquals(expected, AgendaWidgetSchedule.nextRolloverMillis(now, moscow))
    }

    @Test
    fun `next rollover follows timezone calendar across DST`() {
        val berlin = ZoneId.of("Europe/Berlin")
        val now = ZonedDateTime.of(2026, 3, 28, 23, 58, 0, 0, berlin)
            .toInstant()
            .toEpochMilli()
        val expected = ZonedDateTime.of(2026, 3, 29, 0, 0, 2, 0, berlin)
            .toInstant()
            .toEpochMilli()

        assertEquals(expected, AgendaWidgetSchedule.nextRolloverMillis(now, berlin))
    }

    @Test
    fun `day selection includes overnight event and excludes adjacent boundary`() {
        val now = instant(2026, 9, 3, 12, 0)

        assertTrue(
            AgendaWidgetSchedule.overlapsCurrentDay(
                instant(2026, 9, 2, 23, 30),
                instant(2026, 9, 3, 0, 30),
                now,
                moscow,
            ),
        )
        assertFalse(
            AgendaWidgetSchedule.overlapsCurrentDay(
                instant(2026, 9, 2, 22, 0),
                instant(2026, 9, 3, 0, 0),
                now,
                moscow,
            ),
        )
        assertFalse(
            AgendaWidgetSchedule.overlapsCurrentDay(
                instant(2026, 9, 4, 0, 0),
                instant(2026, 9, 4, 1, 0),
                now,
                moscow,
            ),
        )
    }

    @Test
    fun `all-day selection uses Moscow calendar date instead of UTC offset`() {
        val justAfterMoscowMidnight = instant(2026, 9, 3, 0, 1)

        assertTrue(
            AgendaWidgetSchedule.allDayOverlapsCurrentDay(
                LocalDate.of(2026, 9, 3),
                LocalDate.of(2026, 9, 4),
                justAfterMoscowMidnight,
                moscow,
            ),
        )
    }

    @Test
    fun `all-day selection uses negative-offset date and excludes exact end`() {
        val losAngeles = ZoneId.of("America/Los_Angeles")
        val lateOnThird = instant(2026, 9, 3, 23, 59, losAngeles)
        val exactEnd = instant(2026, 9, 4, 0, 0, losAngeles)
        val startDate = LocalDate.of(2026, 9, 3)
        val endDate = LocalDate.of(2026, 9, 4)

        assertTrue(
            AgendaWidgetSchedule.allDayOverlapsCurrentDay(
                startDate,
                endDate,
                lateOnThird,
                losAngeles,
            ),
        )
        assertFalse(
            AgendaWidgetSchedule.allDayOverlapsCurrentDay(
                startDate,
                endDate,
                exactEnd,
                losAngeles,
            ),
        )
    }

    @Test
    fun `date label and legacy snapshot advance with local date`() {
        val before = instant(2026, 9, 2, 23, 59)
        val after = instant(2026, 9, 3, 0, 1)

        val russian = Locale("ru")
        assertEquals("Среда, 2 сентября", AgendaWidgetSchedule.dateLabel(before, moscow, russian))
        assertEquals("Четверг, 3 сентября", AgendaWidgetSchedule.dateLabel(after, moscow, russian))
        assertFalse(
            AgendaWidgetSchedule.legacySnapshotMatchesToday(
                "Среда, 2 сентября",
                after,
                moscow,
                russian,
            ),
        )
    }

    private fun instant(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        zoneId: ZoneId = moscow,
    ): Long = ZonedDateTime.of(year, month, day, hour, minute, 0, 0, zoneId)
        .toInstant()
        .toEpochMilli()
}
