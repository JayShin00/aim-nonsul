package com.aim.aim_nonsul

import android.os.Bundle
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.ComponentName
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.aim.aimNonsul/widget"
    private val NOTIFICATION_CHANNEL = "com.aim.aimNonsul/notification"
    
    companion object {
        private const val TAG = "MainActivity"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateAndroidWidget" -> {
                    // Android 위젯 강제 업데이트
                    updateAllWidgets(this)
                    result.success(null)
                }
                "setAutoScrollEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    setAutoScrollEnabled(this, enabled)
                    result.success(null)
                }
                "getAutoScrollEnabled" -> {
                    val enabled = getAutoScrollEnabled(this)
                    result.success(enabled)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Notification channel for handling boot receiver triggers
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "triggerNotificationUpdate" -> {
                    Log.d(TAG, "Triggered notification update from native")
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Check if app was launched by boot receiver
        val triggerUpdate = intent?.getBooleanExtra("trigger_notification_update", false) ?: false
        if (triggerUpdate) {
            Log.d(TAG, "App launched by boot receiver, will trigger notification update")
            // We'll trigger the notification update once Flutter is ready
        }
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        
        val triggerUpdate = intent.getBooleanExtra("trigger_notification_update", false)
        if (triggerUpdate) {
            Log.d(TAG, "New intent with notification update trigger")
        }
    }
    
    private fun updateAllWidgets(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        
        // Update XML widget
        val examWidgetComponent = ComponentName(context, ExamWidget::class.java)
        val examWidgetIds = appWidgetManager.getAppWidgetIds(examWidgetComponent)
        
        val examIntent = Intent(context, ExamWidget::class.java)
        examIntent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        examIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, examWidgetIds)
        context.sendBroadcast(examIntent)
    }
    
    private fun setAutoScrollEnabled(context: Context, enabled: Boolean) {
        // Save preference
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        prefs.edit()
            .putBoolean("auto_scroll_enabled", enabled)
            .apply()
        
        // Send broadcast to toggle auto-scroll
        val toggleIntent = Intent(context, ExamWidget::class.java)
        toggleIntent.action = "com.example.aim_nonsul.ACTION_TOGGLE_AUTO_SCROLL"
        context.sendBroadcast(toggleIntent)
        
        Log.d(TAG, "Auto-scroll set to: $enabled")
    }
    
    private fun getAutoScrollEnabled(context: Context): Boolean {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        return prefs.getBoolean("auto_scroll_enabled", true)
    }
}
