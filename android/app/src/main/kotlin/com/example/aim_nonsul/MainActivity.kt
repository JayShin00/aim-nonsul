package com.example.aim_nonsul

import android.os.Bundle
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.ComponentName
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.aim.aimNonsul/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateAndroidWidget" -> {
                    // Android 위젯 강제 업데이트
                    updateAllWidgets(this)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun updateAllWidgets(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        
        // Update legacy XML widget
        val examWidgetComponent = ComponentName(context, ExamWidget::class.java)
        val examWidgetIds = appWidgetManager.getAppWidgetIds(examWidgetComponent)
        
        val examIntent = Intent(context, ExamWidget::class.java)
        examIntent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        examIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, examWidgetIds)
        context.sendBroadcast(examIntent)
        
        // Update Glance widget
        val glanceWidgetComponent = ComponentName(context, ExamGlanceWidgetReceiver::class.java)
        val glanceWidgetIds = appWidgetManager.getAppWidgetIds(glanceWidgetComponent)
        
        val glanceIntent = Intent(context, ExamGlanceWidgetReceiver::class.java)
        glanceIntent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        glanceIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, glanceWidgetIds)
        context.sendBroadcast(glanceIntent)
    }
}
