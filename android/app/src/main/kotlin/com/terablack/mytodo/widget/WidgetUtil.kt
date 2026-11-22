package com.terablack.mytodo.widget

import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import com.terablack.mytodo.MainActivity
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/** 위젯 공통 도우미. 데이터는 Flutter(WidgetService)가 문자열로 저장합니다. */
object WidgetUtil {
    private val dayFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)

    fun dayKey(date: Date = Date()): String = dayFormat.format(date)

    fun dayKey(cal: Calendar): String = dayFormat.format(cal.time)

    fun str(prefs: SharedPreferences, key: String): String =
        try { prefs.getString(key, "") ?: "" } catch (_: ClassCastException) { "" }

    fun long(prefs: SharedPreferences, key: String): Long = str(prefs, key).toLongOrNull() ?: 0L

    /** 위젯을 누르면 앱의 해당 화면을 엽니다 (mytodo://open/<screen>). */
    fun open(context: Context, screen: String) =
        HomeWidgetLaunchIntent.getActivity(
            context, MainActivity::class.java, Uri.parse("mytodo://open/$screen"))

    /** 앱을 열지 않고 백그라운드 Dart 코드를 실행합니다. */
    fun background(context: Context, uri: String) =
        HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse(uri))

    fun won(amount: Long): String =
        NumberFormat.getNumberInstance(Locale.KOREA).format(amount) + "원"

    fun monthDayLabel(key: String): String {
        val parts = key.split("-")
        if (parts.size != 3) return key
        return "${parts[1].toInt()}월 ${parts[2].toInt()}일"
    }
}
