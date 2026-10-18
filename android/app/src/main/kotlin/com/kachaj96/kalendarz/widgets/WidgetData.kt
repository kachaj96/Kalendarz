package com.kachaj96.kalendarz.widgets

import android.app.PendingIntent
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import com.kachaj96.kalendarz.MainActivity
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale

/** Jedno wystąpienie wpisu w danym dniu, tak jak zapisała je aplikacja (lib/device/widget_snapshot.dart). */
data class Occ(
    val day: String,
    val start: Int,
    val end: Int,
    val title: String,
    val color: Int,
    val local: Boolean,
    val task: Boolean,
    val done: Boolean,
    val place: String,
) {
    val allDay: Boolean get() = start < 0
}

object WidgetData {
    val weekdayShort = arrayOf("pon", "wt", "śr", "czw", "pt", "sob", "nd")
    val weekdayLetter = arrayOf("P", "W", "Ś", "C", "P", "S", "N")
    val weekdayLong = arrayOf("poniedziałek", "wtorek", "środa", "czwartek", "piątek", "sobota", "niedziela")
    val months = arrayOf(
        "Styczeń", "Luty", "Marzec", "Kwiecień", "Maj", "Czerwiec",
        "Lipiec", "Sierpień", "Wrzesień", "Październik", "Listopad", "Grudzień",
    )
    val monthsGenitive = arrayOf(
        "stycznia", "lutego", "marca", "kwietnia", "maja", "czerwca",
        "lipca", "sierpnia", "września", "października", "listopada", "grudnia",
    )

    /** Uszkodzone albo brakujące dane dają pustą listę, nigdy wyjątek (widżet musi się narysować). */
    fun load(prefs: SharedPreferences): List<Occ>? {
        val raw = prefs.getString("snapshot", null) ?: return null
        return try {
            val arr = JSONObject(raw).getJSONArray("items")
            (0 until arr.length()).map { i ->
                val o = arr.getJSONObject(i)
                Occ(
                    day = o.getString("d"),
                    start = o.getInt("s"),
                    end = o.getInt("e"),
                    title = o.getString("t"),
                    color = o.getLong("c").toInt(),
                    local = o.optBoolean("l"),
                    task = o.optBoolean("k"),
                    done = o.optBoolean("x"),
                    place = o.optString("p", ""),
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    fun today(): Calendar = Calendar.getInstance().apply {
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }

    fun nowMinutes(): Int {
        val c = Calendar.getInstance()
        return c.get(Calendar.HOUR_OF_DAY) * 60 + c.get(Calendar.MINUTE)
    }

    fun key(c: Calendar): String = String.format(
        Locale.US, "%04d-%02d-%02d",
        c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH),
    )

    fun plusDays(c: Calendar, n: Int): Calendar = (c.clone() as Calendar).apply { add(Calendar.DAY_OF_MONTH, n) }

    /** 0 = poniedziałek ... 6 = niedziela. */
    fun mondayIndex(c: Calendar): Int = (c.get(Calendar.DAY_OF_WEEK) + 5) % 7

    fun mondayOf(c: Calendar): Calendar = plusDays(c, -mondayIndex(c))

    fun hm(minutes: Int): String = String.format(Locale.US, "%02d:%02d", (minutes / 60) % 24, minutes % 60)

    /** Wpisy jednego dnia: najpierw całodniowe, potem według godziny. */
    fun onDay(items: List<Occ>, dayKey: String): List<Occ> =
        items.filter { it.day == dayKey }.sortedWith(compareBy({ !it.allDay }, { it.start }, { it.title.lowercase() }))

    /** Otwiera aplikację w danym widoku, opcjonalnie na konkretnym dniu. */
    fun launch(context: Context, tab: String, dayKey: String? = null): PendingIntent {
        val uri = Uri.parse("kalendarz://open?tab=$tab" + (dayKey?.let { "&date=$it" } ?: ""))
        return HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri)
    }

    fun color(context: Context, id: Int): Int = context.getColor(id)
}
