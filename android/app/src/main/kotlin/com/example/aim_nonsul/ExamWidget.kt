package com.example.aim_nonsul

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.SimpleDateFormat
import java.util.*

class ExamWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.exam_widget)

        // SharedPreferences에서 데이터 가져오기
        val prefs = context.getSharedPreferences("HomeWidgetPlugin", Context.MODE_PRIVATE)
        val examTitle = prefs.getString("exam_title", "다음 시험") ?: "다음 시험"
        val examDate = prefs.getString("exam_date", "날짜 없음") ?: "날짜 없음"
        val examTime = prefs.getString("exam_time", "시간 없음") ?: "시간 없음"
        val examRoom = prefs.getString("exam_room", "장소 없음") ?: "장소 없음"
        val daysLeft = prefs.getString("days_left", "D-Day") ?: "D-Day"

        // 위젯 뷰 업데이트
        views.setTextViewText(R.id.exam_title, examTitle)
        views.setTextViewText(R.id.exam_date, examDate)
        views.setTextViewText(R.id.exam_time, examTime)
        views.setTextViewText(R.id.exam_room, examRoom)
        views.setTextViewText(R.id.days_left, daysLeft)

        // 위젯 클릭 시 앱 실행
        val intent = Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

        // 위젯 업데이트
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
} 