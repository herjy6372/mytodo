package com.terablack.mytodo.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import com.terablack.mytodo.R
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** 오늘 할 일 목록. 항목을 누르면 앱을 열지 않고 완료/미완료가 바뀝니다. */
class TodoWidgetProvider : HomeWidgetProvider() {
    private val rows = intArrayOf(R.id.row_0, R.id.row_1, R.id.row_2, R.id.row_3, R.id.row_4)
    private val checks = intArrayOf(R.id.check_0, R.id.check_1, R.id.check_2, R.id.check_3, R.id.check_4)
    private val titles = intArrayOf(R.id.title_0, R.id.title_1, R.id.title_2, R.id.title_3, R.id.title_4)
    private val times = intArrayOf(R.id.time_0, R.id.time_1, R.id.time_2, R.id.time_3, R.id.time_4)

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val today = WidgetUtil.dayKey()
        val items = mutableListOf<org.json.JSONObject>()
        try {
            val arr = JSONArray(WidgetUtil.str(widgetData, "todo_items").ifEmpty { "[]" })
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                if (o.optString("day") == today) items.add(o)
            }
        } catch (_: Exception) {}
        // 미완료 먼저, 그다음 시간 순
        items.sortWith(compareBy({ it.optBoolean("done") }, { it.optLong("due") }))
        val doneCount = items.count { it.optBoolean("done") }
        val timeFormat = SimpleDateFormat("HH:mm", Locale.KOREA)

        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_todo)
            views.setOnClickPendingIntent(R.id.todo_header, WidgetUtil.open(context, "todo"))
            views.setOnClickPendingIntent(R.id.todo_empty, WidgetUtil.open(context, "todo"))
            views.setTextViewText(R.id.todo_count,
                if (items.isEmpty()) "" else "$doneCount/${items.size} 완료")
            views.setViewVisibility(R.id.todo_empty, if (items.isEmpty()) View.VISIBLE else View.GONE)

            for (i in rows.indices) {
                if (i < items.size) {
                    val o = items[i]
                    val done = o.optBoolean("done")
                    views.setViewVisibility(rows[i], View.VISIBLE)
                    views.setImageViewResource(checks[i],
                        if (done) R.drawable.widget_check_on else R.drawable.widget_check_off)
                    views.setTextViewText(titles[i], o.optString("title"))
                    views.setInt(titles[i], "setPaintFlags",
                        if (done) android.graphics.Paint.STRIKE_THRU_TEXT_FLAG or android.graphics.Paint.ANTI_ALIAS_FLAG
                        else android.graphics.Paint.ANTI_ALIAS_FLAG)
                    views.setTextViewText(times[i], timeFormat.format(Date(o.optLong("due"))))
                    views.setOnClickPendingIntent(rows[i], WidgetUtil.background(
                        context, "mytodo://todo/toggle?id=${o.optString("id")}"))
                } else {
                    views.setViewVisibility(rows[i], View.GONE)
                }
            }
            val more = items.size - rows.size
            views.setViewVisibility(R.id.todo_more, if (more > 0) View.VISIBLE else View.GONE)
            views.setTextViewText(R.id.todo_more, "외 ${more}개 더 있어요")
            views.setOnClickPendingIntent(R.id.todo_more, WidgetUtil.open(context, "todo"))
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
