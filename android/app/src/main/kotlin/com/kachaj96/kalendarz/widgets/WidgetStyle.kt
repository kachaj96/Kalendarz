package com.kachaj96.kalendarz.widgets

import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.widget.RemoteViews
import com.kachaj96.kalendarz.R
import org.json.JSONObject

/**
 * Wygląd widżetów wybrany w ustawieniach aplikacji (lib/settings/app_settings.dart):
 * krycie tła 100/75/50/0 i kolor tekstu auto/light/dark.
 */
class WidgetStyle(private val opacity: Int, private val text: String) {
    companion object {
        fun load(prefs: SharedPreferences): WidgetStyle {
            val raw = prefs.getString("style", null) ?: return WidgetStyle(100, "auto")
            return try {
                val o = JSONObject(raw)
                WidgetStyle(o.optInt("o", 100), o.optString("t", "auto"))
            } catch (e: Exception) {
                WidgetStyle(100, "auto")
            }
        }
    }

    private fun isNight(context: Context): Boolean =
        (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES

    private fun lightText(context: Context): Boolean = when (text) {
        "light" -> true
        "dark" -> false
        else -> isNight(context)
    }

    /** Cień tylko pod jasnym tekstem na prześwitującym tle (na pełnym tle jest zbędny). */
    private fun shadow(context: Context): Boolean = opacity < 75 && lightText(context)

    fun layout(context: Context, normal: Int, withShadow: Int): Int = if (shadow(context)) withShadow else normal

    fun fg(context: Context): Int = when (text) {
        "light" -> 0xFFFFFFFF.toInt()
        "dark" -> 0xFF171B2B.toInt()
        else -> context.getColor(R.color.widget_fg)
    }

    fun fg2(context: Context): Int = when (text) {
        "light" -> 0xFFE2E6F0.toInt()
        "dark" -> 0xFF454D61.toInt()
        else -> context.getColor(R.color.widget_fg2)
    }

    private fun backgroundRes(): Int = when {
        opacity >= 100 -> R.drawable.widget_background
        opacity >= 75 -> R.drawable.widget_background_75
        opacity >= 50 -> R.drawable.widget_background_50
        else -> 0
    }

    /** Tło i nagłówek; pozostałe teksty koloruje każdy widżet sam. */
    fun apply(context: Context, views: RemoteViews) {
        views.setInt(R.id.w_root, "setBackgroundResource", backgroundRes())
        views.setTextColor(R.id.w_title, fg(context))
        views.setTextColor(R.id.w_subtitle, fg2(context))
    }
}
