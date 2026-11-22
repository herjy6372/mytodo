package com.terablack.mytodo.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.os.SystemClock
import android.widget.RemoteViews
import com.terablack.mytodo.R
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.util.Calendar

/** 기분 한 줄: 가장 최근 기록. */
class MoodWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager,
                          appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val day = WidgetUtil.str(widgetData, "mood_day")
        val emoji = WidgetUtil.str(widgetData, "mood_emoji")
        appWidgetIds.forEach { id ->
            val v = RemoteViews(context.packageName, R.layout.widget_mood)
            if (day.isEmpty()) {
                v.setTextViewText(R.id.mood_emoji, "📝")
                v.setTextViewText(R.id.mood_label, "오늘 기분은 어때요?")
                v.setTextViewText(R.id.mood_note, "눌러서 기분 한 줄을 남겨 보세요")
                v.setTextViewText(R.id.mood_date, "")
            } else {
                v.setTextViewText(R.id.mood_emoji, emoji)
                v.setTextViewText(R.id.mood_label, WidgetUtil.str(widgetData, "mood_label"))
                v.setTextViewText(R.id.mood_note, WidgetUtil.str(widgetData, "mood_note"))
                v.setTextViewText(R.id.mood_date,
                    if (day == WidgetUtil.dayKey()) "오늘" else WidgetUtil.monthDayLabel(day))
            }
            v.setOnClickPendingIntent(R.id.root, WidgetUtil.open(context, "mood"))
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}

/** 가계부: 이번 달 입금·출금·잔액과 오늘 지출. */
class LedgerWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager,
                          appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val now = Calendar.getInstance()
        val monthPrefix = WidgetUtil.dayKey(now).substring(0, 7)
        val todayKey = WidgetUtil.dayKey(now)
        var income = 0L; var expense = 0L; var todayOut = 0L
        try {
            val o = JSONObject(WidgetUtil.str(widgetData, "ledger_days").ifEmpty { "{}" })
            for (key in o.keys()) {
                val a = o.getJSONArray(key)
                if (key.startsWith(monthPrefix)) {
                    income += a.optLong(0); expense += a.optLong(1)
                }
                if (key == todayKey) todayOut += a.optLong(1)
            }
        } catch (_: Exception) {}
        val balance = income - expense
        appWidgetIds.forEach { id ->
            val v = RemoteViews(context.packageName, R.layout.widget_ledger)
            v.setTextViewText(R.id.ledger_month, "${now.get(Calendar.MONTH) + 1}월")
            v.setTextViewText(R.id.ledger_balance, (if (balance < 0) "-" else "") + WidgetUtil.won(kotlin.math.abs(balance)))
            v.setTextViewText(R.id.ledger_income, "입금 " + WidgetUtil.won(income))
            v.setTextViewText(R.id.ledger_expense, "출금 " + WidgetUtil.won(expense))
            v.setTextViewText(R.id.ledger_today, "오늘 지출 " + WidgetUtil.won(todayOut))
            v.setOnClickPendingIntent(R.id.root, WidgetUtil.open(context, "ledger"))
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}

/** 메모: 고정했거나 가장 최근에 수정한 메모. */
class MemoWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager,
                          appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val title = WidgetUtil.str(widgetData, "memo_title")
        val body = WidgetUtil.str(widgetData, "memo_body")
        val count = WidgetUtil.long(widgetData, "memo_count")
        val color = WidgetUtil.long(widgetData, "memo_color").toInt()
        appWidgetIds.forEach { id ->
            val v = RemoteViews(context.packageName, R.layout.widget_memo)
            if (title.isEmpty()) {
                v.setTextViewText(R.id.memo_title, "메모")
                v.setTextViewText(R.id.memo_body, "눌러서 첫 메모를 남겨 보세요")
                v.setTextViewText(R.id.memo_count, "")
            } else {
                v.setTextViewText(R.id.memo_title, title)
                v.setTextViewText(R.id.memo_body, body)
                v.setTextViewText(R.id.memo_count, "메모 ${count}개")
            }
            // 메모 색상으로 배경 칠하기 (흰색 메모는 그대로)
            if (color != 0 && color != Color.WHITE) v.setInt(R.id.memo_bg, "setColorFilter", color)
            else v.setInt(R.id.memo_bg, "setColorFilter", Color.WHITE)
            v.setOnClickPendingIntent(R.id.root, WidgetUtil.open(context, "memo"))
            v.setOnClickPendingIntent(R.id.memo_add, WidgetUtil.open(context, "memo_new"))
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}

/** 타이머: 버튼으로 시작하고, 남은 시간을 실시간으로 표시. */
class TimerWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager,
                          appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val end = WidgetUtil.long(widgetData, "timer_end_ms")
        val remaining = end - System.currentTimeMillis()
        val running = end > 0 && remaining > 0
        appWidgetIds.forEach { id ->
            val v = RemoteViews(context.packageName, R.layout.widget_timer)
            if (running) {
                v.setChronometer(R.id.timer_chrono, SystemClock.elapsedRealtime() + remaining, null, true)
                v.setChronometerCountDown(R.id.timer_chrono, true)
                v.setTextViewText(R.id.timer_state, "진행 중")
            } else {
                v.setChronometer(R.id.timer_chrono, SystemClock.elapsedRealtime(), "00:00", false)
                v.setChronometerCountDown(R.id.timer_chrono, false)
                v.setTextViewText(R.id.timer_state, if (end > 0) "끝났어요" else "")
            }
            v.setOnClickPendingIntent(R.id.timer_5, WidgetUtil.background(context, "mytodo://timer/start?min=5"))
            v.setOnClickPendingIntent(R.id.timer_10, WidgetUtil.background(context, "mytodo://timer/start?min=10"))
            v.setOnClickPendingIntent(R.id.timer_25, WidgetUtil.background(context, "mytodo://timer/start?min=25"))
            v.setOnClickPendingIntent(R.id.timer_stop, WidgetUtil.background(context, "mytodo://timer/stop"))
            v.setOnClickPendingIntent(R.id.timer_header, WidgetUtil.open(context, "timer"))
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}

/** 세계시각: 메인 도시. TextClock 이라 앱 없이도 시간이 계속 흐릅니다. */
class WorldClockWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager,
                          appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val tz = WidgetUtil.str(widgetData, "clock_main_tz").ifEmpty { "Asia/Seoul" }
        val name = WidgetUtil.str(widgetData, "clock_main_name").ifEmpty { "서울" }
        appWidgetIds.forEach { id ->
            val v = RemoteViews(context.packageName, R.layout.widget_clock)
            v.setTextViewText(R.id.clock_city, name)
            v.setString(R.id.clock_time, "setTimeZone", tz)
            v.setString(R.id.clock_date, "setTimeZone", tz)
            v.setOnClickPendingIntent(R.id.root, WidgetUtil.open(context, "worldclock"))
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}

/** 세계시각: 메인 | 서브 두 도시. */
class WorldClockDualWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager,
                          appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val mainTz = WidgetUtil.str(widgetData, "clock_main_tz").ifEmpty { "Asia/Seoul" }
        val subTz = WidgetUtil.str(widgetData, "clock_sub_tz").ifEmpty { "America/Los_Angeles" }
        appWidgetIds.forEach { id ->
            val v = RemoteViews(context.packageName, R.layout.widget_clock_dual)
            v.setTextViewText(R.id.main_city, WidgetUtil.str(widgetData, "clock_main_name").ifEmpty { "서울" })
            v.setTextViewText(R.id.sub_city, WidgetUtil.str(widgetData, "clock_sub_name").ifEmpty { "로스앤젤레스" })
            v.setString(R.id.main_time, "setTimeZone", mainTz)
            v.setString(R.id.main_date, "setTimeZone", mainTz)
            v.setString(R.id.sub_time, "setTimeZone", subTz)
            v.setString(R.id.sub_date, "setTimeZone", subTz)
            v.setOnClickPendingIntent(R.id.root, WidgetUtil.open(context, "worldclock"))
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}
