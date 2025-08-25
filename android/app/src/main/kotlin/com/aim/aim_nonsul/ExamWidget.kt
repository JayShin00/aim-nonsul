package com.aim.aim_nonsul

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
import android.widget.LinearLayout
import android.app.AlarmManager
import android.os.SystemClock
import android.os.Build

class ExamWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        Log.d("ExamWidget", "=== 안드로이드 위젯 업데이트 시작 ===")
        
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
        
        // Start auto-scroll if enabled
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val autoScrollEnabled = prefs.getBoolean("auto_scroll_enabled", true) // Default to enabled
        if (autoScrollEnabled && appWidgetIds.isNotEmpty()) {
            startAutoScroll(context)
        }
        
        Log.d("ExamWidget", "=== 안드로이드 위젯 업데이트 완료 ===")
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        val action = intent.action
        Log.d("ExamWidget", "onReceive 호출됨 - Action: $action")
        
        when (action) {
            ACTION_NAVIGATE_NEXT -> {
                handleCarouselNavigation(context, "next", false)
            }
            ACTION_NAVIGATE_PREVIOUS -> {
                handleCarouselNavigation(context, "previous", false)
            }
            ACTION_AUTO_SCROLL -> {
                handleCarouselNavigation(context, "next", true)
                // Reschedule next auto-scroll
                val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                if (prefs.getBoolean("auto_scroll_enabled", true)) {
                    scheduleNextAutoScroll(context)
                }
            }
            ACTION_TOGGLE_AUTO_SCROLL -> {
                toggleAutoScroll(context)
            }
        }
    }
    
    private fun handleCarouselNavigation(context: Context, direction: String, isAutoScroll: Boolean = false) {
        try {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            
            // Flutter의 selectedSchedules 데이터 로드
            val selectedSchedulesJson = prefs.getString("flutter.selectedSchedules", null)
            val currentIndex = prefs.getInt("current_index", 0)
            
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
                        .putInt("current_index", newIndex)
                        .apply()
                    
                    // If this is manual navigation, stop auto-scroll temporarily
                    if (!isAutoScroll) {
                        // Stop auto-scroll for manual navigation
                        cancelAutoScroll(context)
                        // Restart auto-scroll after a delay (5 seconds)
                        if (prefs.getBoolean("auto_scroll_enabled", true)) {
                            scheduleAutoScrollRestart(context, 5000)
                        }
                    }
                    
                    Log.d("ExamWidget", "Carousel 네비게이션: $direction -> 인덱스 $currentIndex -> $newIndex (Auto: $isAutoScroll)")
                    
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
        // Start auto-scroll when first widget is added
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        if (prefs.getBoolean("auto_scroll_enabled", true)) {
            startAutoScroll(context)
        }
    }

    override fun onDisabled(context: Context) {
        Log.d("ExamWidget", "위젯이 비활성화됨")
        // Cancel auto-scroll when last widget is removed
        cancelAutoScroll(context)
    }
    
    private fun startAutoScroll(context: Context) {
        Log.d("ExamWidget", "Auto-scroll 시작")
        scheduleNextAutoScroll(context)
    }
    
    private fun scheduleNextAutoScroll(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ExamWidget::class.java).apply {
            action = ACTION_AUTO_SCROLL
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            AUTO_SCROLL_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val triggerTime = SystemClock.elapsedRealtime() + 2000
        
        try {
            // Try to use exact alarm first (more precise timing)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
                Log.d("ExamWidget", "다음 auto-scroll 예약됨 (정확한 알람, 2초 후)")
            } else {
                alarmManager.setExact(
                    AlarmManager.ELAPSED_REALTIME,
                    triggerTime,
                    pendingIntent
                )
                Log.d("ExamWidget", "다음 auto-scroll 예약됨 (정확한 알람, 2초 후)")
            }
        } catch (e: SecurityException) {
            // Fallback to inexact alarm if exact alarm permission is not granted
            Log.w("ExamWidget", "정확한 알람 권한이 없음, 부정확한 알람 사용: ${e.message}")
            alarmManager.set(
                AlarmManager.ELAPSED_REALTIME,
                triggerTime,
                pendingIntent
            )
            Log.d("ExamWidget", "다음 auto-scroll 예약됨 (부정확한 알람, 2초 후)")
        }
    }
    
    private fun scheduleAutoScrollRestart(context: Context, delayMillis: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ExamWidget::class.java).apply {
            action = ACTION_AUTO_SCROLL
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            AUTO_SCROLL_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val triggerTime = SystemClock.elapsedRealtime() + delayMillis
        
        try {
            // Try to use exact alarm first
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.ELAPSED_REALTIME,
                    triggerTime,
                    pendingIntent
                )
            }
            Log.d("ExamWidget", "Auto-scroll 재시작 예약됨 (정확한 알람, ${delayMillis/1000}초 후)")
        } catch (e: SecurityException) {
            // Fallback to inexact alarm
            Log.w("ExamWidget", "정확한 알람 권한이 없음, 부정확한 알람 사용: ${e.message}")
            alarmManager.set(
                AlarmManager.ELAPSED_REALTIME,
                triggerTime,
                pendingIntent
            )
            Log.d("ExamWidget", "Auto-scroll 재시작 예약됨 (부정확한 알람, ${delayMillis/1000}초 후)")
        }
    }
    
    private fun cancelAutoScroll(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ExamWidget::class.java).apply {
            action = ACTION_AUTO_SCROLL
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            AUTO_SCROLL_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        alarmManager.cancel(pendingIntent)
        Log.d("ExamWidget", "Auto-scroll 취소됨")
    }
    
    private fun toggleAutoScroll(context: Context) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val currentEnabled = prefs.getBoolean("auto_scroll_enabled", true)
        val newEnabled = !currentEnabled
        
        prefs.edit()
            .putBoolean("auto_scroll_enabled", newEnabled)
            .apply()
        
        if (newEnabled) {
            startAutoScroll(context)
            Log.d("ExamWidget", "Auto-scroll 활성화됨")
        } else {
            cancelAutoScroll(context)
            Log.d("ExamWidget", "Auto-scroll 비활성화됨")
        }
    }

    companion object {
        const val ACTION_NAVIGATE_NEXT = "com.aim.aim_nonsul.ACTION_NAVIGATE_NEXT"
        const val ACTION_NAVIGATE_PREVIOUS = "com.aim.aim_nonsul.ACTION_NAVIGATE_PREVIOUS"
        const val ACTION_AUTO_SCROLL = "com.aim.aim_nonsul.ACTION_AUTO_SCROLL"
        const val ACTION_TOGGLE_AUTO_SCROLL = "com.aim.aim_nonsul.ACTION_TOGGLE_AUTO_SCROLL"
        const val EXTRA_APPWIDGET_ID = "appwidget_id"
        const val AUTO_SCROLL_REQUEST_CODE = 9999
        
        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            Log.d("ExamWidget", "updateAppWidget 호출됨, ID: $appWidgetId")
            
            val views = RemoteViews(context.packageName, R.layout.carousel_widget)
            
            try {
                // SharedPreferences에서 데이터 읽기
                val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                val selectedSchedulesJson = prefs.getString("flutter.selectedSchedules", null)
                val currentIndex = prefs.getInt("current_index", 0)
                val totalCount = prefs.getInt("total_count", 0)
                
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
                            val dDayText = when {
                                dDay == 0 -> "D-Day"
                                dDay < 0 -> "종료"
                                dDay < 10 -> "D-$dDay"
                                dDay < 100 -> "D-$dDay" 
                                else -> "D-$dDay" // Supports 3-digit numbers (100+)
                            }
                            
                            Log.d("ExamWidget", "D-Day 계산 결과: $dDayText (${dDay}일)")
                            
                            // 일정 데이터 표시
                            views.setViewVisibility(R.id.empty_layout, View.GONE)
                            views.setViewVisibility(R.id.content_container, View.VISIBLE)
                            
                            // 헤더 및 D-Day 배지 스타일링
                            views.setViewVisibility(R.id.star_indicator, if (isPrimary) View.VISIBLE else View.GONE)
                            
                            // 대학명, 학과명 (improved text handling with primary styling)
                            views.setTextViewText(R.id.university_name, university)
                            if (isPrimary) {
                                views.setInt(R.id.university_name, "setTextColor", android.graphics.Color.parseColor("#FF8C00"))
                                views.setFloat(R.id.university_name, "setTextSize", 16f) // Slightly larger for primary
                            } else {
                                views.setInt(R.id.university_name, "setTextColor", android.graphics.Color.parseColor("#2C3E50"))
                                views.setFloat(R.id.university_name, "setTextSize", 14f) // Normal size
                            }
                            
                            val cleanDepartment = department.replace("⭐ ", "").trim()
                            views.setTextViewText(R.id.department_name, cleanDepartment)
                            
                            // 시험일 표시
                            val formattedDate = formatExamDate(examDateTimeStr)
                            views.setTextViewText(R.id.exam_date, formattedDate)
                            
                            // D-Day 뱃지 with enhanced styling
                            views.setTextViewText(R.id.dday_badge, dDayText)
                            
                            // Apply special background and styling for starred exams
                            if (isPrimary) {
                                views.setInt(R.id.dday_badge, "setBackgroundResource", R.drawable.dday_badge_starred)
                                views.setInt(R.id.dday_badge, "setTextColor", android.graphics.Color.parseColor("#FF8C00"))
                                Log.d("ExamWidget", "Primary exam detected - applying starred D-Day badge")
                            } else {
                                views.setInt(R.id.dday_badge, "setBackgroundResource", android.R.color.transparent)
                                // Regular D-Day color scheme
                                val dDayColor = when {
                                    dDay <= 0 -> "#6C757D"  // Gray for past/today
                                    dDay <= 7 -> "#E74C3C"   // Red for urgent (1 week)
                                    dDay <= 30 -> "#D63384"  // Pink for soon (1 month)
                                    else -> "#3498DB"        // Blue for distant future
                                }
                                views.setInt(R.id.dday_badge, "setTextColor", android.graphics.Color.parseColor(dDayColor))
                            }
                            
                            // 네비게이션 버튼 및 페이지 인디케이터 설정
                            val actualTotalCount = schedulesArray.length()
                            if (actualTotalCount > 1) {
                                // 도트 인디케이터 표시
                                views.setViewVisibility(R.id.dot_indicator, View.VISIBLE)
                                setupDotIndicator(context, views, validIndex, actualTotalCount)
                                
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
                                views.setViewVisibility(R.id.dot_indicator, View.GONE)
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
        
        private fun setupDotIndicator(context: Context, views: RemoteViews, currentIndex: Int, totalCount: Int) {
            // Limit to maximum 6 dots for optimal display
            val displayCount = minOf(totalCount, 6)
            
            // Create dots with visual distinction for current position
            val dots = StringBuilder()
            for (i in 0 until displayCount) {
                if (i == currentIndex) {
                    // Use larger, filled circle for active dot
                    dots.append("⬤")  // Large filled circle (active)
                } else {
                    // Use smaller, hollow circle for inactive dots
                    dots.append("○")  // Hollow circle (inactive) 
                }
                if (i < displayCount - 1) {
                    dots.append(" ")  // Single space for tighter spacing
                }
            }
            
            // Add ellipsis indicator if there are more than 6 items
            if (totalCount > 6) {
                dots.append(" ⋯")  // Horizontal ellipsis for overflow
            }
            
            // Set the dots text
            views.setTextViewText(R.id.dot_indicator, dots.toString())
            
            // Always use pink color - the visual distinction comes from the different symbols
            views.setTextColor(R.id.dot_indicator, android.graphics.Color.parseColor("#D63384"))
            
            Log.d("ExamWidget", "Dot indicator setup: ${currentIndex + 1}/$totalCount (showing $displayCount dots)")
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