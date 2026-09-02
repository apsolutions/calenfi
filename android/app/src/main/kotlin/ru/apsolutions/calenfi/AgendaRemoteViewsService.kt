package ru.apsolutions.calenfi

import android.content.Context
import android.content.Intent
import android.graphics.Paint
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/// Поставщик строк списка повестки для [AgendaWidgetProvider].
class AgendaRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        AgendaFactory(applicationContext)
}

private class AgendaFactory(
    private val context: Context,
) : RemoteViewsService.RemoteViewsFactory {

    private data class Item(
        val startMillis: Long?,
        val endMillis: Long?,
        val allDay: Boolean,
        val legacyTime: String,
        val title: String,
        val location: String,
        val legacySub: String,
        val color: Int,
        val cancelled: Boolean,
    )

    private var items: List<Item> = emptyList()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        val prefs = HomeWidgetPlugin.getData(context)
        val json = prefs.getString("agenda_json", "[]") ?: "[]"
        val arr = runCatching { JSONArray(json) }.getOrDefault(JSONArray())
        val now = System.currentTimeMillis()
        val legacyIsCurrent = AgendaWidgetSchedule.legacySnapshotMatchesToday(
            prefs.getString("agenda_date", null),
            now,
        )
        items = (0 until arr.length())
            .mapNotNull { i ->
                val o = runCatching { arr.getJSONObject(i) }.getOrNull() ?: return@mapNotNull null
                val start = o.optEpochMillis("start_ms")
                val end = o.optEpochMillis("end_ms")
                val allDay = o.optBoolean("all_day", false)
                val startDate = o.optLocalDate("start_date")
                val endDate = o.optLocalDate("end_date")
                val belongsToToday = when {
                    allDay && startDate != null && endDate != null ->
                        AgendaWidgetSchedule.allDayOverlapsCurrentDay(
                            startDate,
                            endDate,
                            now,
                        )
                    start != null && end != null ->
                        AgendaWidgetSchedule.overlapsCurrentDay(start, end, now)
                    else -> {
                        // До schema 2 JSON не содержал дат. В день записи он ещё
                        // валиден; после полуночи лучше пустая agenda, чем вчерашняя.
                        legacyIsCurrent
                    }
                }
                if (!belongsToToday) return@mapNotNull null
                Item(
                    startMillis = start,
                    endMillis = end,
                    allDay = allDay,
                    legacyTime = o.optString("time", ""),
                    title = o.optString("title", ""),
                    location = o.optString("location", ""),
                    legacySub = o.optString("sub", ""),
                    color = o.optInt("color", 0xFF8AB4F8.toInt()),
                    cancelled = o.optBoolean("cancelled", false),
                )
            }
            .sortedWith(compareBy<Item>({ !it.allDay }, { it.startMillis ?: Long.MAX_VALUE }))
    }

    override fun onDestroy() {
        items = emptyList()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews {
        val it = items[position]
        val start = it.startMillis
        val end = it.endMillis
        val v = RemoteViews(context.packageName, R.layout.widget_agenda_item)
        val time = when {
            it.allDay -> "весь день"
            start != null -> formatTime(start)
            else -> it.legacyTime
        }
        val sub = if (start != null && end != null) {
            buildList {
                if (!it.allDay) add("${formatTime(start)}–${formatTime(end)}")
                if (it.location.isNotBlank()) add(it.location.trim())
            }.joinToString("  ·  ")
        } else {
            it.legacySub
        }
        v.setTextViewText(R.id.item_time, time)
        v.setTextViewText(R.id.item_title, it.title)
        v.setTextViewText(R.id.item_sub, sub)
        v.setViewVisibility(R.id.item_sub, if (sub.isEmpty()) View.GONE else View.VISIBLE)
        v.setInt(R.id.item_dot, "setColorFilter", it.color)
        // Зачёркивание для отменённых событий.
        val flags = if (it.cancelled) Paint.STRIKE_THRU_TEXT_FLAG else 0
        v.setInt(R.id.item_title, "setPaintFlags", flags or Paint.ANTI_ALIAS_FLAG)
        v.setOnClickFillInIntent(R.id.item_row, Intent())
        return v
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = false

    private fun formatTime(epochMillis: Long): String =
        Instant.ofEpochMilli(epochMillis)
            .atZone(ZoneId.systemDefault())
            .format(timeFormatter)

    private fun org.json.JSONObject.optEpochMillis(key: String): Long? =
        if (has(key) && !isNull(key)) optLong(key) else null

    private fun org.json.JSONObject.optLocalDate(key: String): LocalDate? =
        if (has(key) && !isNull(key)) {
            runCatching { LocalDate.parse(optString(key)) }.getOrNull()
        } else {
            null
        }

    companion object {
        private val timeFormatter = DateTimeFormatter.ofPattern("HH:mm")
    }
}
