package com.kachaj96.kalendarz.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.view.View
import android.widget.RemoteViews
import com.kachaj96.kalendarz.R
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Calendar

/** Bieżący tydzień: siedem kolumn z kolorowymi paskami wpisów. */
class WeekWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val items = WidgetData.load(widgetData) ?: emptyList()
        val today = WidgetData.today()
        val todayKey = WidgetData.key(today)
        val monday = WidgetData.mondayOf(today)
        val sunday = WidgetData.plusDays(monday, 6)
        val onAccent = WidgetData.color(context, R.color.widget_on_accent)
        val fg = WidgetData.color(context, R.color.widget_fg)

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_week)
            views.setTextViewText(R.id.w_title, "Ten tydzień")
            views.setTextViewText(
                R.id.w_subtitle,
                "${monday.get(Calendar.DAY_OF_MONTH)} - ${sunday.get(Calendar.DAY_OF_MONTH)} " +
                    WidgetData.monthsGenitive[sunday.get(Calendar.MONTH)].take(3),
            )
            views.setOnClickPendingIntent(R.id.w_root, WidgetData.launch(context, "week"))
            for (d in 0 until 7) {
                val day = WidgetData.plusDays(monday, d)
                val key = WidgetData.key(day)
                val isToday = key == todayKey
                views.setTextViewText(WidgetIds.weekName[d], WidgetData.weekdayShort[d])
                views.setTextViewText(WidgetIds.weekNum[d], day.get(Calendar.DAY_OF_MONTH).toString())
                views.setInt(WidgetIds.weekNum[d], "setBackgroundResource", if (isToday) R.drawable.widget_today else 0)
                views.setTextColor(WidgetIds.weekNum[d], if (isToday) onAccent else fg)
                val dayItems = WidgetData.onDay(items, key)
                for (b in 0 until WidgetIds.WEEK_BARS) {
                    val barId = WidgetIds.weekBar[d * WidgetIds.WEEK_BARS + b]
                    val o = dayItems.getOrNull(b)
                    views.setViewVisibility(barId, if (o == null) View.GONE else View.VISIBLE)
                    if (o != null) {
                        views.setTextViewText(barId, o.title)
                        views.setInt(barId, "setBackgroundColor", o.color)
                    }
                }
                val more = dayItems.size - WidgetIds.WEEK_BARS
                views.setViewVisibility(WidgetIds.weekMore[d], if (more > 0) View.VISIBLE else View.GONE)
                views.setTextViewText(WidgetIds.weekMore[d], "+$more")
                views.setOnClickPendingIntent(WidgetIds.weekCol[d], WidgetData.launch(context, "day", key))
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}

/** Bieżący miesiąc: siatka dni z kropkami w kolorach kategorii. */
class MonthWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val items = WidgetData.load(widgetData) ?: emptyList()
        val byDay = items.groupBy { it.day }
        val today = WidgetData.today()
        val todayKey = WidgetData.key(today)
        val first = (today.clone() as Calendar).apply { set(Calendar.DAY_OF_MONTH, 1) }
        val month = first.get(Calendar.MONTH)
        val leading = WidgetData.mondayIndex(first)
        val daysInMonth = first.getActualMaximum(Calendar.DAY_OF_MONTH)
        val weeks = (leading + daysInMonth + 6) / 7
        val start = WidgetData.plusDays(first, -leading)
        val onAccent = WidgetData.color(context, R.color.widget_on_accent)
        val fg = WidgetData.color(context, R.color.widget_fg)
        val fg2 = WidgetData.color(context, R.color.widget_fg2)

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_month)
            views.setTextViewText(R.id.w_title, WidgetData.months[month])
            views.setTextViewText(R.id.w_subtitle, first.get(Calendar.YEAR).toString())
            views.setOnClickPendingIntent(R.id.w_root, WidgetData.launch(context, "month"))
            for (c in 0 until 7) views.setTextViewText(WidgetIds.monthHeader[c], WidgetData.weekdayLetter[c])
            for (r in 0 until WidgetIds.MONTH_ROWS) {
                views.setViewVisibility(WidgetIds.monthRow[r], if (r < weeks) View.VISIBLE else View.GONE)
                if (r >= weeks) continue
                for (c in 0 until 7) {
                    val idx = r * 7 + c
                    val day = WidgetData.plusDays(start, idx)
                    val key = WidgetData.key(day)
                    val inMonth = day.get(Calendar.MONTH) == month
                    val isToday = key == todayKey
                    val numId = WidgetIds.monthNum[idx]
                    views.setTextViewText(numId, day.get(Calendar.DAY_OF_MONTH).toString())
                    views.setInt(numId, "setBackgroundResource", if (isToday) R.drawable.widget_today else 0)
                    views.setTextColor(numId, if (isToday) onAccent else if (inMonth) fg else fg2)
                    views.setTextViewText(WidgetIds.monthDots[idx], dots(byDay[key].orEmpty(), fg2))
                    views.setOnClickPendingIntent(WidgetIds.monthCell[idx], WidgetData.launch(context, "day", key))
                }
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    /** Do trzech kropek w kolorach kategorii, przy większej liczbie wpisów znak "+". */
    private fun dots(dayItems: List<Occ>, moreColor: Int): CharSequence {
        val sb = SpannableStringBuilder()
        for (o in dayItems.take(3)) {
            val startPos = sb.length
            sb.append("●")
            sb.setSpan(ForegroundColorSpan(o.color), startPos, sb.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        if (dayItems.size > 3) {
            val startPos = sb.length
            sb.append("+")
            sb.setSpan(ForegroundColorSpan(moreColor), startPos, sb.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        return sb
    }
}
