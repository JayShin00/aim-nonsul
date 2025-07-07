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
        val componentName = ComponentName(context, ExamWidget::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
        
        val intent = Intent(context, ExamWidget::class.java)
        intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
        context.sendBroadcast(intent)
    }
}
