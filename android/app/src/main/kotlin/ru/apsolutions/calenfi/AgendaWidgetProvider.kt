package ru.apsolutions.calenfi

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

/// Домашний виджет «agenda на сегодня».
///
/// Данные пишет Flutter через home_widget в SharedPreferences
/// `HomeWidgetPreferences`; список рисует [AgendaRemoteViewsService].
class AgendaWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val prefs = HomeWidgetPlugin.getData(context)
        val date = prefs.getString("agenda_date", "Сегодня")
        val updated = prefs.getString("agenda_updated", "")

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_agenda)
            views.setTextViewText(R.id.widget_date, date)
            views.setTextViewText(
                R.id.widget_updated,
                if (updated.isNullOrEmpty()) "" else "обновлено $updated",
            )

            // Список повестки через RemoteViewsService (уникальный data-URI на id,
            // иначе адаптеры виджетов переиспользуются ошибочно).
            val svc = Intent(context, AgendaRemoteViewsService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.widget_list, svc)
            views.setEmptyView(R.id.widget_list, R.id.widget_empty)

            // Тап по шапке — открыть приложение.
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launch != null) {
                val pi = PendingIntent.getActivity(
                    context, 0, launch,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                )
                views.setOnClickPendingIntent(R.id.widget_header, pi)
            }

            // Шаблон клика по элементу списка — тоже открыть приложение.
            val itemTemplate = Intent(context, MainActivity::class.java)
            val itemPi = PendingIntent.getActivity(
                context, 1, itemTemplate,
                PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            views.setPendingIntentTemplate(R.id.widget_list, itemPi)

            manager.updateAppWidget(id, views)
        }
        // Сообщаем фабрике, что данные изменились — перечитать SharedPreferences.
        manager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.widget_list)
    }
}
