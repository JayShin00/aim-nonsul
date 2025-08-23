package com.example.aim_nonsul

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.glance.color.ColorProvider
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.cornerRadius
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.action.clickable
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*
import android.util.Log
import androidx.glance.state.GlanceStateDefinition
import androidx.glance.state.PreferencesGlanceStateDefinition
import androidx.glance.appwidget.state.updateAppWidgetState
import androidx.glance.appwidget.updateAll
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey

class ExamGlanceWidget : GlanceAppWidget() {

    override val stateDefinition: GlanceStateDefinition<Preferences> = PreferencesGlanceStateDefinition

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            GlanceTheme {
                ExamWidgetContent(context)
            }
        }
    }

    @Composable
    private fun ExamWidgetContent(context: Context) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val selectedSchedulesJson = prefs.getString("flutter.selectedSchedules", null)
        val currentIndex = prefs.getInt("current_index", 0)

        // Check if we have valid data (moved try-catch logic outside composable)
        val examData = parseExamData(selectedSchedulesJson, currentIndex)
        
        if (examData != null) {
            ExamContentView(
                university = examData.university,
                department = examData.department,
                examDateTimeStr = examData.examDateTimeStr,
                isPrimary = examData.isPrimary,
                currentIndex = examData.currentIndex,
                totalCount = examData.totalCount
            )
        } else {
            // Empty state
            EmptyStateView()
        }
    }
    
    // Data class to hold exam information
    private data class ExamData(
        val university: String,
        val department: String,
        val examDateTimeStr: String,
        val isPrimary: Boolean,
        val currentIndex: Int,
        val totalCount: Int
    )
    
    // Non-composable function to parse exam data
    private fun parseExamData(selectedSchedulesJson: String?, currentIndex: Int): ExamData? {
        return try {
            if (selectedSchedulesJson != null && selectedSchedulesJson.isNotEmpty() && selectedSchedulesJson != "[]") {
                val schedulesArray = JSONArray(selectedSchedulesJson)
                if (schedulesArray.length() > 0) {
                    val validIndex = if (currentIndex < schedulesArray.length()) currentIndex else 0
                    val schedule = schedulesArray.getJSONObject(validIndex)
                    
                    val university = schedule.optString("university", "")
                    val department = schedule.optString("department", "")
                    val examDateTimeStr = schedule.optString("examDateTime", "")
                    val isPrimary = schedule.optBoolean("isPrimary", false)

                    if (university.isNotEmpty() && department.isNotEmpty() && examDateTimeStr.isNotEmpty()) {
                        return ExamData(university, department, examDateTimeStr, isPrimary, validIndex, schedulesArray.length())
                    }
                }
            }
            null
        } catch (e: Exception) {
            Log.e("ExamGlanceWidget", "데이터 파싱 오류", e)
            null
        }
    }

    @Composable
    private fun ExamContentView(
        university: String,
        department: String,
        examDateTimeStr: String,
        isPrimary: Boolean,
        currentIndex: Int,
        totalCount: Int
    ) {
        val dDay = calculateDDay(examDateTimeStr)
        val dDayText = if (dDay == 0) "D-Day" else if (dDay < 0) "종료" else "D-$dDay"
        val dDayColor = if (dDay <= 0) ColorProvider(Color(0xFF6C757D), Color(0xFF6C757D)) else ColorProvider(Color(0xFFD63384), Color(0xFFD63384))
        val formattedDate = formatExamDate(examDateTimeStr)

        Row(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(ColorProvider(Color.White, Color.White))
                .cornerRadius(16.dp)
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Previous navigation button
            if (totalCount > 1) {
                Box(
                    modifier = GlanceModifier
                        .size(24.dp)
                        .clickable(
                            actionRunCallback<NavigationActionCallback>(
                                actionParametersOf(NavigationActionCallback.directionKey to "previous")
                            )
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "‹",
                        style = TextStyle(
                            color = ColorProvider(Color(0xFFD63384), Color(0xFFD63384)),
                            fontSize = 18.sp,
                            fontWeight = FontWeight.Bold
                        )
                    )
                }
                Spacer(modifier = GlanceModifier.width(8.dp))
            }

            // Main content
            Column(
                modifier = GlanceModifier
                    .defaultWeight()
                    .fillMaxSize()
            ) {
                // D-Day header with star
                Row(
                    modifier = GlanceModifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = dDayText,
                        style = TextStyle(
                            color = dDayColor,
                            fontSize = 30.sp,
                            fontWeight = FontWeight.Bold
                        ),
                        modifier = GlanceModifier.defaultWeight()
                    )
                    
                    if (isPrimary) {
                        Text(
                            text = "⭐",
                            style = TextStyle(
                                color = ColorProvider(Color(0xFFFFC107), Color(0xFFFFC107)),
                                fontSize = 12.sp
                            )
                        )
                    }
                }

                // Dot indicators (if multiple items)
                if (totalCount > 1) {
                    Spacer(modifier = GlanceModifier.height(8.dp))
                    Row(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = GlanceModifier.fillMaxWidth()
                    ) {
                        for (i in 0 until totalCount) {
                            Text(
                                text = "●",
                                style = TextStyle(
                                    color = if (i == currentIndex) ColorProvider(Color(0xFFD63384), Color(0xFFD63384)) else ColorProvider(Color(0x4D6C757D), Color(0x4D6C757D)),
                                    fontSize = 8.sp
                                )
                            )
                            if (i < totalCount - 1) {
                                Spacer(modifier = GlanceModifier.width(4.dp))
                            }
                        }
                    }
                }

                Spacer(modifier = GlanceModifier.defaultWeight())

                // University name
                Text(
                    text = university,
                    style = TextStyle(
                        color = ColorProvider(Color(0xFF2C3E50), Color(0xFF2C3E50)),
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium
                    ),
                    maxLines = 1
                )

                // Department name
                Text(
                    text = department.replace("⭐ ", ""),
                    style = TextStyle(
                        color = ColorProvider(Color(0xFF6C757D), Color(0xFF6C757D)),
                        fontSize = 14.sp
                    ),
                    maxLines = 2,
                    modifier = GlanceModifier.padding(bottom = 4.dp)
                )

                // Exam date
                Text(
                    text = formattedDate,
                    style = TextStyle(
                        color = ColorProvider(Color(0xFF6C757D), Color(0xFF6C757D)),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium
                    )
                )
            }
            
            // Next navigation button
            if (totalCount > 1) {
                Spacer(modifier = GlanceModifier.width(8.dp))
                Box(
                    modifier = GlanceModifier
                        .size(24.dp)
                        .clickable(
                            actionRunCallback<NavigationActionCallback>(
                                actionParametersOf(NavigationActionCallback.directionKey to "next")
                            )
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "›",
                        style = TextStyle(
                            color = ColorProvider(Color(0xFFD63384), Color(0xFFD63384)),
                            fontSize = 18.sp,
                            fontWeight = FontWeight.Bold
                        )
                    )
                }
            }
        }
    }

    @Composable
    private fun EmptyStateView() {
        Box(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(ColorProvider(Color.White, Color.White))
                .cornerRadius(16.dp)
                .padding(16.dp),
            contentAlignment = Alignment.Center
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = "📅",
                    style = TextStyle(fontSize = 24.sp),
                    modifier = GlanceModifier.padding(bottom = 8.dp)
                )

                Text(
                    text = "AIM 논술",
                    style = TextStyle(
                        color = ColorProvider(Color(0xFFD63384), Color(0xFFD63384)),
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium
                    ),
                    modifier = GlanceModifier.padding(bottom = 4.dp)
                )

                Text(
                    text = "모집단위를 추가해주세요",
                    style = TextStyle(
                        color = ColorProvider(Color(0xFF6C757D), Color(0xFF6C757D)),
                        fontSize = 12.sp
                    )
                )
            }
        }
    }

    private fun calculateDDay(examDateTimeStr: String): Int {
        return try {
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
            (diffInMillis / (24 * 60 * 60 * 1000)).toInt()
        } catch (e: Exception) {
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
            examDateTimeStr
        }
    }
}

class NavigationActionCallback : ActionCallback {
    companion object {
        val directionKey = ActionParameters.Key<String>("direction")
    }

    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters
    ) {
        val direction = parameters[directionKey] ?: return
        
        try {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
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
                    
                    prefs.edit()
                        .putInt("flutter.current_index", newIndex)
                        .apply()
                    
                    // Update all Glance widgets
                    ExamGlanceWidget().updateAll(context)
                }
            }
        } catch (e: Exception) {
            Log.e("NavigationActionCallback", "Navigation error", e)
        }
    }
}

class ExamGlanceWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = ExamGlanceWidget()
}