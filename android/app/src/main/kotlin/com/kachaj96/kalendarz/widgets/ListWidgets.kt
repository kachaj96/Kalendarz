package com.kachaj96.kalendarz.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import com.kachaj96.kalendarz.R
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/** Wiersz listy: etykieta czasu po lewej, tytuł i opis po prawej. */
data class ListRow(val time: String, val title: String, val sub: String, val color: Int, val live: Boolean, val dayKey: String)

/** Wspólna część widżetów "Najbliższe" i "Dziś" (ten sam układ widget_list). */
abstract class ListWidget : HomeWidgetProvider() {
    abstract val tab: String
    abstract fun title(): String
    abstract fun subtitle(): String
    abstract val emptyText: String
    abstract fun rows(items: List<Occ>): List<ListRow>

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) render(context, appWidgetManager, id, widgetData)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        render(context, appWidgetManager, appWidgetId, HomeWidgetPlugin.getData(context))
    }

    /** Ile wierszy mieści się w aktualnej wysokości widżetu. */
    private fun capacity(manager: AppWidgetManager, id: Int): Int {
        val h = manager.getAppWidgetOptions(id).getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 110)
        return ((h - 44) / 40).coerceIn(1, WidgetIds.LIST_ROWS)
    }

    private fun render(context: Context, manager: AppWidgetManager, id: Int, prefs: SharedPreferences) {
        val views = RemoteViews(context.packageName, R.layout.widget_list)
        views.setTextViewText(R.id.w_title, title())
        views.setTextViewText(R.id.w_subtitle, subtitle())
        views.setOnClickPendingIntent(R.id.w_root, WidgetData.launch(context, tab))

        val items = WidgetData.load(prefs)
        val rows = if (items == null) emptyList() else rows(items).take(capacity(manager, id))
        views.setViewVisibility(R.id.w_empty, if (rows.isEmpty()) View.VISIBLE else View.GONE)
        views.setTextViewText(
            R.id.w_empty,
            if (items == null) "Otwórz aplikację, żeby wczytać wpisy." else emptyText,
        )

        val accent = WidgetData.color(context, R.color.widget_accent)
        val fg2 = WidgetData.color(context, R.color.widget_fg2)
        for (i in 0 until WidgetIds.LIST_ROWS) {
            val row = rows.getOrNull(i)
            views.setViewVisibility(WidgetIds.row[i], if (row == null) View.GONE else View.VISIBLE)
            if (row == null) continue
            views.setTextViewText(WidgetIds.rowTime[i], row.time)
            views.setTextColor(WidgetIds.rowTime[i], if (row.live) accent else fg2)
            views.setInt(WidgetIds.rowBar[i], "setBackgroundColor", row.color)
            views.setTextViewText(WidgetIds.rowTitle[i], row.title)
            views.setTextViewText(WidgetIds.rowSub[i], row.sub)
            views.setOnClickPendingIntent(WidgetIds.row[i], WidgetData.launch(context, "day", row.dayKey))
        }
        manager.updateAppWidget(id, views)
    }

    protected fun titleOf(o: Occ): String = (if (o.task && o.done) "✓ " else "") + o.title

    protected fun timeRange(o: Occ): String =
        if (o.allDay) "Cały dzień" else WidgetData.hm(o.start) + " - " + WidgetData.hm(if (o.end >= 1440) 0 else o.end)

    protected fun withLocal(text: String, o: Occ): String = if (o.local) "$text · tylko ja" else text

    protected fun makeRow(time: String, o: Occ, sub: String, live: Boolean) =
        ListRow(time, titleOf(o), withLocal(sub, o), o.color, live, o.day)
}

/** Najbliższe wpisy: dziś od teraz, potem kolejne dni. */
class AgendaWidget : ListWidget() {
    override val tab = "agenda"
    override val emptyText = "Nic w najbliższych tygodniach."
    override fun title() = "Najbliższe"
    override fun subtitle(): String {
        val t = WidgetData.today()
        return WidgetData.weekdayShort[WidgetData.mondayIndex(t)] + " " +
            t.get(java.util.Calendar.DAY_OF_MONTH) + " " +
            WidgetData.monthsGenitive[t.get(java.util.Calendar.MONTH)].take(3)
    }

    override fun rows(items: List<Occ>): List<ListRow> {
        val today = WidgetData.today()
        val now = WidgetData.nowMinutes()
        val out = ArrayList<ListRow>()
        for (offset in 0..30) {
            val day = WidgetData.plusDays(today, offset)
            val key = WidgetData.key(day)
            for (o in WidgetData.onDay(items, key)) {
                if (o.task && o.done) continue
                if (offset == 0 && !o.allDay && o.end <= now) continue
                val live = offset == 0 && !o.allDay && o.start <= now
                val time = when {
                    offset == 0 -> if (o.allDay) "dziś" else WidgetData.hm(o.start)
                    offset == 1 -> "jutro"
                    else -> WidgetData.weekdayShort[WidgetData.mondayIndex(day)]
                }
                val sub = when {
                    live -> "trwa do " + WidgetData.hm(if (o.end >= 1440) 0 else o.end)
                    offset == 0 -> timeRange(o)
                    else -> "${day.get(java.util.Calendar.DAY_OF_MONTH)}.${"%02d".format(day.get(java.util.Calendar.MONTH) + 1)} · ${timeRange(o)}"
                }
                out.add(makeRow(time, o, sub, live))
                if (out.size >= WidgetIds.LIST_ROWS) return out
            }
        }
        return out
    }
}

/** Wszystkie wpisy z dzisiaj. */
class DayWidget : ListWidget() {
    override val tab = "day"
    override val emptyText = "Na dziś nic nie ma."
    override fun title() = "Dziś"
    override fun subtitle(): String {
        val t = WidgetData.today()
        return WidgetData.weekdayLong[WidgetData.mondayIndex(t)] + ", " +
            t.get(java.util.Calendar.DAY_OF_MONTH) + " " + WidgetData.monthsGenitive[t.get(java.util.Calendar.MONTH)]
    }

    override fun rows(items: List<Occ>): List<ListRow> {
        val key = WidgetData.key(WidgetData.today())
        val now = WidgetData.nowMinutes()
        return WidgetData.onDay(items, key).map { o ->
            val live = !o.allDay && o.start <= now && o.end > now
            makeRow(if (o.allDay) "cały" else WidgetData.hm(o.start), o, timeRange(o), live)
        }
    }
}
