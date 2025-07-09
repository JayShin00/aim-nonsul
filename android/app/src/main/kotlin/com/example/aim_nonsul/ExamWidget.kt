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

class ExamWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        Log.d("ExamWidget", "=== 안드로이드 위젯 업데이트 시작 ===")
        
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
        
        Log.d("ExamWidget", "=== 안드로이드 위젯 업데이트 완료 ===")
    }

    override fun onEnabled(context: Context) {
        Log.d("ExamWidget", "위젯이 활성화됨")
    }

    override fun onDisabled(context: Context) {
        Log.d("ExamWidget", "위젯이 비활성화됨")
    }

    companion object {
        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            Log.d("ExamWidget", "updateAppWidget 호출됨, ID: $appWidgetId")
            
            val views = RemoteViews(context.packageName, R.layout.exam_widget)
            
            try {
                // SharedPreferences에서 데이터 읽기
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                // Flutter가 실제로 저장하는 키는 "flutter.flutter.selectedSchedules"입니다
                val selectedSchedulesJson = prefs.getString("flutter.flutter.selectedSchedules", null)
                
                Log.d("ExamWidget", "SharedPreferences 데이터: $selectedSchedulesJson")
                
                // 저장된 모든 키 확인 (디버깅용)
                val allKeys = prefs.all
                Log.d("ExamWidget", "=== 저장된 모든 키들 ===")
                for ((key, value) in allKeys) {
                    Log.d("ExamWidget", "키: '$key' → 값: '$value'")
                }
                Log.d("ExamWidget", "=== 키 목록 끝 ===")
                
                // 특정 키들도 직접 확인
                Log.d("ExamWidget", "직접 확인:")
                Log.d("ExamWidget", "flutter.selectedSchedules = ${prefs.getString("flutter.selectedSchedules", "NULL")}")
                Log.d("ExamWidget", "selectedSchedules = ${prefs.getString("selectedSchedules", "NULL")}")
                Log.d("ExamWidget", "StringList selectedSchedules = ${prefs.getStringSet("selectedSchedules", null)}")
                
                if (selectedSchedulesJson != null && selectedSchedulesJson.isNotEmpty() && selectedSchedulesJson != "[]") {
                    val schedulesArray = JSONArray(selectedSchedulesJson)
                    
                    if (schedulesArray.length() > 0) {
                        // isPrimary가 true인 일정을 우선 선택, 없으면 첫 번째 일정 사용
                        var schedule = schedulesArray.getJSONObject(0)
                        for (i in 0 until schedulesArray.length()) {
                            val currentSchedule = schedulesArray.getJSONObject(i)
                            if (currentSchedule.optBoolean("isPrimary", false)) {
                                schedule = currentSchedule
                                break
                            }
                        }
                        
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
            
            // 위젯 업데이트
            appWidgetManager.updateAppWidget(appWidgetId, views)
            Log.d("ExamWidget", "위젯 업데이트 완료")
        }
        
        private fun showEmptyState(views: RemoteViews) {
            Log.d("ExamWidget", "빈 상태 표시")
            views.setViewVisibility(R.id.empty_layout, View.VISIBLE)
            views.setViewVisibility(R.id.star_indicator, View.GONE)
            views.setTextViewText(R.id.university_name, "")
            views.setTextViewText(R.id.department_name, "")
            views.setTextViewText(R.id.exam_date, "")
            views.setTextViewText(R.id.dday_badge, "")
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