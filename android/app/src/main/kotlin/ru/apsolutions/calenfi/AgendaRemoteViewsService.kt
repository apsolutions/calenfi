package ru.apsolutions.calenfi

import android.content.Context
import android.content.Intent
import android.graphics.Paint
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

/// Поставщик строк списка повестки для [AgendaWidgetProvider].
class AgendaRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        AgendaFactory(applicationContext)
}

private class AgendaFactory(
    private val context: Context,
) : RemoteViewsService.RemoteViewsFactory {

    private data class Item(
        val time: String,
        val title: String,
        val sub: String,
        val color: Int,
        val cancelled: Boolean,
    )

    private var items: List<Item> = emptyList()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        val json = HomeWidgetPlugin.getData(context).getString("agenda_json", "[]") ?: "[]"
        val arr = runCatching { JSONArray(json) }.getOrDefault(JSONArray())
        items = (0 until arr.length()).map { i ->
            val o = arr.getJSONObject(i)
            Item(
                time = o.optString("time", ""),
                title = o.optString("title", ""),
                sub = o.optString("sub", ""),
                color = o.optInt("color", 0xFF8AB4F8.toInt()),
                cancelled = o.optBoolean("cancelled", false),
            )
        }
    }

    override fun onDestroy() {
        items = emptyList()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews {
        val it = items[position]
        val v = RemoteViews(context.packageName, R.layout.widget_agenda_item)
        v.setTextViewText(R.id.item_time, it.time)
        v.setTextViewText(R.id.item_title, it.title)
        v.setTextViewText(R.id.item_sub, it.sub)
        v.setViewVisibility(R.id.item_sub, if (it.sub.isEmpty()) View.GONE else View.VISIBLE)
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
}
