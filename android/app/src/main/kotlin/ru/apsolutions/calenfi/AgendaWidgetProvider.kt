package ru.apsolutions.calenfi

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

/// Домашний виджет «agenda на сегодня».
///
/// Данные пишет Flutter через home_widget в SharedPreferences
/// `HomeWidgetPreferences`; список рисует [AgendaRemoteViewsService].
class AgendaWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action
        if (action != null && action in refreshActions) {
            refreshAll(context)
        }
    }

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        render(context, manager, appWidgetIds)
        scheduleNextRollover(context, appWidgetIds)
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        scheduleNextRollover(context, widgetIds(context))
    }

    override fun onDisabled(context: Context) {
        cancelRollover(context)
        super.onDisabled(context)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        val remaining = widgetIds(context)
        if (remaining.isEmpty()) cancelRollover(context)
    }

    override fun onRestored(
        context: Context,
        oldWidgetIds: IntArray,
        newWidgetIds: IntArray,
    ) {
        super.onRestored(context, oldWidgetIds, newWidgetIds)
        render(context, AppWidgetManager.getInstance(context), newWidgetIds)
        scheduleNextRollover(context, newWidgetIds)
    }

    private fun render(
        context: Context,
        manager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val prefs = HomeWidgetPlugin.getData(context)
        val now = System.currentTimeMillis()
        val date = AgendaWidgetSchedule.dateLabel(now)
        val updatedEpoch = prefs.getLong("agenda_updated_epoch_ms", 0L)
        val updated = if (updatedEpoch > 0L) {
            java.time.Instant.ofEpochMilli(updatedEpoch)
                .atZone(java.time.ZoneId.systemDefault())
                .format(java.time.format.DateTimeFormatter.ofPattern("HH:mm"))
        } else {
            prefs.getString("agenda_updated", "")
        }

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

    private fun refreshAll(context: Context) {
        val ids = widgetIds(context)
        if (ids.isEmpty()) {
            cancelRollover(context)
            return
        }
        render(context, AppWidgetManager.getInstance(context), ids)
        scheduleNextRollover(context, ids)
    }

    private fun scheduleNextRollover(context: Context, appWidgetIds: IntArray) {
        if (appWidgetIds.isEmpty()) {
            cancelRollover(context)
            return
        }
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val triggerAt = AgendaWidgetSchedule.nextRolloverMillis(System.currentTimeMillis())
        val pendingIntent = rolloverPendingIntent(context)

        // Одна alarm в сутки — основной rollover-механизм на современных
        // Android. Exact используем только когда ОС его разрешает; иначе
        // allow-while-idle доставит единственный дневной сигнал с допустимой
        // системной задержкой, не включая частый polling.
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarm.canScheduleExactAlarms()) {
                alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarm.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            } else {
                alarm.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            }
        } catch (_: SecurityException) {
            // Разрешение exact alarm могло быть отозвано между проверкой и
            // вызовом. Не роняем receiver: ставим разрешённую inexact alarm.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            } else {
                alarm.set(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            }
        }
    }

    private fun cancelRollover(context: Context) {
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarm.cancel(rolloverPendingIntent(context))
    }

    private fun rolloverPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, AgendaWidgetProvider::class.java).apply {
            action = ACTION_DAY_ROLLOVER
        }
        return PendingIntent.getBroadcast(
            context,
            ROLLOVER_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    private fun widgetIds(context: Context): IntArray =
        AppWidgetManager.getInstance(context).getAppWidgetIds(
            ComponentName(context, AgendaWidgetProvider::class.java),
        )

    companion object {
        private const val ACTION_DAY_ROLLOVER =
            "ru.apsolutions.calenfi.action.AGENDA_DAY_ROLLOVER"
        private const val ROLLOVER_REQUEST_CODE = 24002
        private val refreshActions = setOf(
            ACTION_DAY_ROLLOVER,
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_LOCALE_CHANGED,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
        )
    }
}
