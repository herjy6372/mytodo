package com.terablack.mytodo.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.widget.RemoteViews
import com.terablack.mytodo.R
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.util.Calendar

/** 날짜별 [완료, 전체] 통계를 읽어 오는 공통 함수. */
internal fun readStats(prefs: SharedPreferences): Map<String, IntArray> {
    val result = HashMap<String, IntArray>()
    try {
        val o = JSONObject(WidgetUtil.str(prefs, "todo_stats").ifEmpty { "{}" })
        for (key in o.keys()) {
            val a = o.getJSONArray(key)
            result[key] = intArrayOf(a.optInt(0), a.optInt(1))
        }
    } catch (_: Exception) {}
    return result
}

internal fun isNight(context: Context): Boolean =
    (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
        Configuration.UI_MODE_NIGHT_YES

/** 최근 7일 할 일 완료율 막대그래프. */
class DailyDoneWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val stats = readStats(widgetData)
        val today = stats[WidgetUtil.dayKey()] ?: intArrayOf(0, 0)
        val summary = if (today[1] == 0) "오늘 예정된 할 일이 없어요"
        else "오늘 ${today[0]}/${today[1]} 완료 · ${today[0] * 100 / today[1]}%"
        val chart = drawWeek(context, stats)
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_daily)
            views.setTextViewText(R.id.daily_summary, summary)
            views.setImageViewBitmap(R.id.daily_chart, chart)
            views.setOnClickPendingIntent(R.id.root, WidgetUtil.open(context, "graph"))
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun drawWeek(context: Context, stats: Map<String, IntArray>): Bitmap {
        val w = 700; val h = 260
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val night = isNight(context)
        val track = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (night) Color.parseColor("#35333F") else Color.parseColor("#EFEDF8") }
        val bar = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (night) Color.parseColor("#B3ABF2") else Color.parseColor("#5B5592") }
        val todayBar = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#FFA94D") }
        val label = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (night) Color.parseColor("#A9A6B8") else Color.parseColor("#6E6A80")
            textSize = 30f; textAlign = Paint.Align.CENTER }
        val names = arrayOf("일", "월", "화", "수", "목", "금", "토")
        val cal = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, -6) }
        val slot = w / 7f
        val barW = slot * 0.5f
        val top = 10f; val bottom = h - 50f
        for (i in 0 until 7) {
            val s = stats[WidgetUtil.dayKey(cal)] ?: intArrayOf(0, 0)
            val ratio = if (s[1] == 0) 0f else s[0].toFloat() / s[1]
            val cx = slot * i + slot / 2
            c.drawRoundRect(RectF(cx - barW / 2, top, cx + barW / 2, bottom), 18f, 18f, track)
            if (ratio > 0f) {
                val y = bottom - (bottom - top) * ratio
                c.drawRoundRect(RectF(cx - barW / 2, y, cx + barW / 2, bottom), 18f, 18f,
                    if (i == 6) todayBar else bar)
            }
            c.drawText(if (i == 6) "오늘" else names[cal.get(Calendar.DAY_OF_WEEK) - 1],
                cx, h - 12f, label)
            cal.add(Calendar.DAY_OF_YEAR, 1)
        }
        return bmp
    }
}

/** 1년 동안 완료한 할 일을 잔디(히트맵)로 표시. */
class YearlyWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val stats = readStats(widgetData)
        val (bmp, total) = drawYear(context, stats)
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_yearly)
            views.setTextViewText(R.id.yearly_total, "최근 1년 완료 ${total}개")
            views.setImageViewBitmap(R.id.yearly_map, bmp)
            views.setOnClickPendingIntent(R.id.root, WidgetUtil.open(context, "calendar"))
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun drawYear(context: Context, stats: Map<String, IntArray>): Pair<Bitmap, Int> {
        val weeks = 53; val cell = 16f; val gap = 4f
        val gridH = 7 * (cell + gap)
        val w = (weeks * (cell + gap)).toInt(); val h = (gridH + 78f).toInt()
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val night = isNight(context)
        val levels = if (night) arrayOf("#35333F", "#4A4580", "#6A62B8", "#8F86E0", "#B3ABF2")
        else arrayOf("#EFEDF8", "#CFC9F0", "#A59CE3", "#7B71CC", "#5B5592")
        val paints = levels.map { Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor(it) } }
        // 마지막 열이 이번 주(일요일 시작), 오늘 이후 칸은 비움
        val today = Calendar.getInstance()
        val start = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, -(today.get(Calendar.DAY_OF_WEEK) - 1))
            add(Calendar.WEEK_OF_YEAR, -(weeks - 1))
        }
        val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (night) Color.parseColor("#A9A6B8") else Color.parseColor("#6E6A80")
            textSize = 28f }
        var total = 0
        var lastLabelCol = -10
        var lastMonth = -1
        val todayKey = WidgetUtil.dayKey(today)
        var reachedToday = false
        for (col in 0 until weeks) {
            // 달이 바뀌는 주에 "N월" 표시 (첫 열의 잘린 달은 생략)
            val month = start.get(Calendar.MONTH)
            if (month != lastMonth) {
                if (lastMonth != -1 && col - lastLabelCol >= 4 && col < weeks - 2) {
                    c.drawText("${month + 1}월", col * (cell + gap), gridH + 30f, text)
                    lastLabelCol = col
                }
                lastMonth = month
            }
            for (row in 0 until 7) {
                if (reachedToday) break
                val key = WidgetUtil.dayKey(start)
                val done = stats[key]?.get(0) ?: 0
                total += done
                val level = when {
                    done <= 0 -> 0
                    done == 1 -> 1
                    done == 2 -> 2
                    done <= 4 -> 3
                    else -> 4
                }
                val x = col * (cell + gap); val y = row * (cell + gap)
                c.drawRoundRect(RectF(x, y, x + cell, y + cell), 4f, 4f, paints[level])
                if (key == todayKey) reachedToday = true
                start.add(Calendar.DAY_OF_YEAR, 1)
            }
        }
        // 범례: 적음 ■■■■■ 많음
        val ly = gridH + 48f
        var lx = w - 5 * (cell + gap) - 64f
        c.drawText("적음", lx - 62f, ly + cell + 4f, text)
        for (p in paints) {
            c.drawRoundRect(RectF(lx, ly, lx + cell, ly + cell), 4f, 4f, p)
            lx += cell + gap
        }
        c.drawText("많음", lx + 4f, ly + cell + 4f, text)
        return bmp to total
    }
}
