package com.example.aim_nonsul

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*
import android.util.Log
import android.view.View
import android.graphics.Color
import java.util.concurrent.TimeUnit
import android.content.Intent
import android.app.PendingIntent
import android.content.ComponentName

class ExamWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        Log.d("ExamWidget", "=== 안드로이드 위젯 업데이트 시작 ===")
        
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
        
        Log.d("ExamWidget", "=== 안드로이드 위젯 업데이트 완료 ===")
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        val action = intent.action
        Log.d("ExamWidget", "onReceive 호출됨 - Action: $action")
        
        when (action) {
            ACTION_NAVIGATE_NEXT -> {
                handleCarouselNavigation(context, "next")
            }
            ACTION_NAVIGATE_PREVIOUS -> {
                handleCarouselNavigation(context, "previous")
            }
        }
    }
    
    private fun handleCarouselNavigation(context: Context, direction: String) {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            
            // Flutter의 selectedSchedules 데이터 로드
            val selectedSchedulesJson = prefs.getString("flutter.flutter.selectedSchedules", null)
            val currentIndex = prefs.getInt("flutter.current_index", 0)
            
            if (!selectedSchedulesJson.isNullOrEmpty() && selectedSchedulesJson != "[]") {
                val schedulesArray = JSONArray(selectedSchedulesJson)
                val totalCount = schedulesArray.length()
                
                if (totalCount > 1) {
                    var newIndex = currentIndex
                    if (direction == "next") {
                        newIndex = (currentIndex + 1) % totalCount
                    } else if (direction == "previous") {
                        newIndex = if (currentIndex == 0) totalCount - 1 else currentIndex - 1
                    }
                    
                    // 새로운 인덱스 저장
                    prefs.edit()
                        .putInt("flutter.current_index", newIndex)
                        .apply()
                    
                    Log.d("ExamWidget", "Carousel 네비게이션: $direction -> 인덱스 $currentIndex -> $newIndex")
                    
                    // 모든 위젯 업데이트
                    val appWidgetManager = AppWidgetManager.getInstance(context)
                    val thisWidget = ComponentName(context, ExamWidget::class.java)
                    val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
                    
                    for (appWidgetId in appWidgetIds) {
                        updateAppWidget(context, appWidgetManager, appWidgetId)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e("ExamWidget", "Carousel 네비게이션 오류", e)
        }
    }

    override fun onEnabled(context: Context) {
        Log.d("ExamWidget", "위젯이 활성화됨")
    }

    override fun onDisabled(context: Context) {
        Log.d("ExamWidget", "위젯이 비활성화됨")
    }

    companion object {
        const val ACTION_NAVIGATE_NEXT = "com.example.aim_nonsul.ACTION_NAVIGATE_NEXT"
        const val ACTION_NAVIGATE_PREVIOUS = "com.example.aim_nonsul.ACTION_NAVIGATE_PREVIOUS"
        const val EXTRA_APPWIDGET_ID = "appwidget_id"
        
        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            Log.d("ExamWidget", "updateAppWidget 호출됨, ID: $appWidgetId")
            
            val views = RemoteViews(context.packageName, R.layout.carousel_widget)
            
            try {
                // SharedPreferences에서 데이터 읽기
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val selectedSchedulesJson = prefs.getString("flutter.flutter.selectedSchedules", null)
                val currentIndex = prefs.getInt("flutter.current_index", 0)
                val totalCount = prefs.getInt("flutter.total_count", 0)
                
                Log.d("ExamWidget", "Carousel 데이터 - JSON: $selectedSchedulesJson, Index: $currentIndex, Total: $totalCount")
                
                if (selectedSchedulesJson != null && selectedSchedulesJson.isNotEmpty() && selectedSchedulesJson != "[]") {
                    val schedulesArray = JSONArray(selectedSchedulesJson)
                    
                    if (schedulesArray.length() > 0) {
                        // 현재 인덱스에 해당하는 일정 선택
                        val validIndex = if (currentIndex < schedulesArray.length()) currentIndex else 0
                        val schedule = schedulesArray.getJSONObject(validIndex)
                        
                        val university = schedule.optString("university", "")
                        val department = schedule.optString("department", "")
                        val examDateTimeStr = schedule.optString("examDateTime", "")
                        val isPrimary = schedule.optBoolean("isPrimary", false)
                        
                        Log.d("ExamWidget", "일정 데이터 - 대학: $university, 학과: $department, 날짜: $examDateTimeStr, 대표: $isPrimary")
                        
                        if (university.isNotEmpty() && department.isNotEmpty() && examDateTimeStr.isNotEmpty()) {
                            // D-Day 계산
                            val dDay = calculateDDay(examDateTimeStr)
                            val dDayText = if (dDay == 0) "D-Day" else if (dDay < 0) "종료" else "D-$dDay"
                            
                            Log.d("ExamWidget", "D-Day 계산 결과: $dDayText")
                            
                            // 일정 데이터 표시
                            views.setViewVisibility(R.id.empty_layout, View.GONE)
                            views.setViewVisibility(R.id.content_container, View.VISIBLE)
                            
                            // 헤더
                            views.setViewVisibility(R.id.star_indicator, if (isPrimary) View.VISIBLE else View.GONE)
                            
                            // 대학명, 학과명
                            views.setTextViewText(R.id.university_name, university)
                            views.setTextViewText(R.id.department_name, department.replace("⭐ ", ""))
                            
                            // 시험일 표시
                            val formattedDate = formatExamDate(examDateTimeStr)
                            views.setTextViewText(R.id.exam_date, formattedDate)
                            
                            // D-Day 뱃지
                            views.setTextViewText(R.id.dday_badge, dDayText)
                            
                            // D-Day에 따른 색상 설정 (iOS와 동일하게)
                            val dDayColor = if (dDay <= 0) "#6C757D" else "#D63384"
                            views.setInt(R.id.dday_badge, "setTextColor", android.graphics.Color.parseColor(dDayColor))
                            
                            // 네비게이션 버튼 및 페이지 인디케이터 설정
                            val actualTotalCount = schedulesArray.length()
                            if (actualTotalCount > 1) {
                                // 페이지 인디케이터 표시
                                views.setViewVisibility(R.id.page_indicator, View.VISIBLE)
                                views.setTextViewText(R.id.page_indicator, "${validIndex + 1}/$actualTotalCount")
                                
                                // 네비게이션 버튼 표시 및 클릭 이벤트 설정
                                views.setViewVisibility(R.id.nav_previous, View.VISIBLE)
                                views.setViewVisibility(R.id.nav_next, View.VISIBLE)
                                
                                // 이전 버튼 PendingIntent
                                val previousIntent = Intent(context, ExamWidget::class.java).apply {
                                    action = ACTION_NAVIGATE_PREVIOUS
                                    putExtra(EXTRA_APPWIDGET_ID, appWidgetId)
                                }
                                val previousPendingIntent = PendingIntent.getBroadcast(
                                    context,
                                    appWidgetId * 100 + 1, // 고유 request code
                                    previousIntent,
                                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                                )
                                views.setOnClickPendingIntent(R.id.nav_previous, previousPendingIntent)
                                
                                // 다음 버튼 PendingIntent
                                val nextIntent = Intent(context, ExamWidget::class.java).apply {
                                    action = ACTION_NAVIGATE_NEXT
                                    putExtra(EXTRA_APPWIDGET_ID, appWidgetId)
                                }
                                val nextPendingIntent = PendingIntent.getBroadcast(
                                    context,
                                    appWidgetId * 100 + 2, // 고유 request code
                                    nextIntent,
                                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                                )
                                views.setOnClickPendingIntent(R.id.nav_next, nextPendingIntent)
                                
                            } else {
                                // 단일 항목인 경우 네비게이션 버튼 숨기기
                                views.setViewVisibility(R.id.nav_previous, View.GONE)
                                views.setViewVisibility(R.id.nav_next, View.GONE)
                                views.setViewVisibility(R.id.page_indicator, View.GONE)
                            }
                            
                        } else {
                            Log.d("ExamWidget", "필수 데이터가 누락됨")
                            showEmptyState(views)
                        }
                    } else {
                        Log.d("ExamWidget", "스케줄 배열이 비어있음")
                        showEmptyState(views)
                    }
                } else {
                    Log.d("ExamWidget", "저장된 데이터가 없거나 빈 배열")
                    showEmptyState(views)
                }
                
            } catch (e: Exception) {
                Log.e("ExamWidget", "위젯 업데이트 오류", e)
                showEmptyState(views)
            }
            
            // 위젯 클릭 시 앱 실행하도록 PendingIntent 설정
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }
            
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // 전체 위젯에 클릭 리스너 설정
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            
            // 위젯 업데이트
            appWidgetManager.updateAppWidget(appWidgetId, views)
            Log.d("ExamWidget", "위젯 업데이트 완료")
        }
        
        private fun showEmptyState(views: RemoteViews) {
            Log.d("ExamWidget", "빈 상태 표시")
            views.setViewVisibility(R.id.empty_layout, View.VISIBLE)
            views.setViewVisibility(R.id.content_container, View.GONE)
            views.setViewVisibility(R.id.nav_previous, View.GONE)
            views.setViewVisibility(R.id.nav_next, View.GONE)
        }
        
        private fun calculateDDay(examDateTimeStr: String): Int {
            return try {
                // ISO 8601 형식 파싱 (Flutter의 toIso8601String() 출력)
                val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.getDefault())
                val examDate = dateFormat.parse(examDateTimeStr)
                
                val currentDate = Calendar.getInstance().apply {
                    set(Calendar.HOUR_OF_DAY, 0)
                    set(Calendar.MINUTE, 0)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }.time
                
                val examCalendar = Calendar.getInstance().apply {
                    time = examDate
                    set(Calendar.HOUR_OF_DAY, 0)
                    set(Calendar.MINUTE, 0)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }
                
                val diffInMillis = examCalendar.timeInMillis - currentDate.time
                val diffInDays = (diffInMillis / (24 * 60 * 60 * 1000)).toInt()
                
                Log.d("ExamWidget", "D-Day 계산: $examDateTimeStr -> $diffInDays")
                diffInDays
            } catch (e: Exception) {
                Log.e("ExamWidget", "D-Day 계산 오류", e)
                0
            }
        }
        
        private fun formatExamDate(examDateTimeStr: String): String {
            return try {
                val inputFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.getDefault())
                val outputFormat = SimpleDateFormat("yyyy.MM.dd", Locale.getDefault())
                val date = inputFormat.parse(examDateTimeStr)
                outputFormat.format(date)
            } catch (e: Exception) {
                Log.e("ExamWidget", "날짜 포맷 오류", e)
                examDateTimeStr
            }
        }
    }
}