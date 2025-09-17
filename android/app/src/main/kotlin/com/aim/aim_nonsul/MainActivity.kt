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
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.UpdateAvailability
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.gms.tasks.Task

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.aim.aimNonsul/widget"
    private val NOTIFICATION_CHANNEL = "com.aim.aimNonsul/notification"
    private val IN_APP_UPDATE_CHANNEL = "in_app_update"
    
    private lateinit var appUpdateManager: AppUpdateManager
    private val REQUEST_CODE_UPDATE = 1001
    
    companion object {
        private const val TAG = "MainActivity"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // App Update Manager 초기화
        appUpdateManager = AppUpdateManagerFactory.create(this)
        
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
        
        // 인앱 업데이트 채널 설정
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, IN_APP_UPDATE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isUpdateAvailable" -> {
                    checkForUpdate(result)
                }
                "startFlexibleUpdate" -> {
                    startFlexibleUpdate(result)
                }
                "startImmediateUpdate" -> {
                    startImmediateUpdate(result)
                }
                "completeFlexibleUpdate" -> {
                    completeFlexibleUpdate(result)
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
        toggleIntent.action = "com.aim.aim_nonsul.ACTION_TOGGLE_AUTO_SCROLL"
        context.sendBroadcast(toggleIntent)
        
        Log.d(TAG, "Auto-scroll set to: $enabled")
    }
    
    private fun getAutoScrollEnabled(context: Context): Boolean {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        return prefs.getBoolean("auto_scroll_enabled", true)
    }
    
    // 인앱 업데이트 관련 메서드들
    private fun checkForUpdate(result: MethodChannel.Result) {
        val appUpdateInfoTask: Task<AppUpdateInfo> = appUpdateManager.appUpdateInfo
        
        appUpdateInfoTask.addOnSuccessListener { appUpdateInfo: AppUpdateInfo ->
            val isUpdateAvailable = appUpdateInfo.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE
            result.success(isUpdateAvailable)
        }
        
        appUpdateInfoTask.addOnFailureListener { exception: Exception ->
            Log.e(TAG, "업데이트 확인 실패", exception)
            result.success(false)
        }
    }
    
    private fun startFlexibleUpdate(result: MethodChannel.Result) {
        val appUpdateInfoTask: Task<AppUpdateInfo> = appUpdateManager.appUpdateInfo
        
        appUpdateInfoTask.addOnSuccessListener { appUpdateInfo: AppUpdateInfo ->
            if (appUpdateInfo.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE) {
                try {
                    appUpdateManager.startUpdateFlowForResult(
                        appUpdateInfo,
                        AppUpdateType.FLEXIBLE,
                        this,
                        REQUEST_CODE_UPDATE
                    )
                    result.success(true)
                } catch (e: Exception) {
                    Log.e(TAG, "유연한 업데이트 시작 실패", e)
                    result.success(false)
                }
            } else {
                result.success(false)
            }
        }
        
        appUpdateInfoTask.addOnFailureListener { exception: Exception ->
            Log.e(TAG, "유연한 업데이트 시작 실패", exception)
            result.success(false)
        }
    }
    
    private fun startImmediateUpdate(result: MethodChannel.Result) {
        val appUpdateInfoTask: Task<AppUpdateInfo> = appUpdateManager.appUpdateInfo
        
        appUpdateInfoTask.addOnSuccessListener { appUpdateInfo: AppUpdateInfo ->
            if (appUpdateInfo.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE) {
                try {
                    appUpdateManager.startUpdateFlowForResult(
                        appUpdateInfo,
                        AppUpdateType.IMMEDIATE,
                        this,
                        REQUEST_CODE_UPDATE
                    )
                    result.success(true)
                } catch (e: Exception) {
                    Log.e(TAG, "즉시 업데이트 시작 실패", e)
                    result.success(false)
                }
            } else {
                result.success(false)
            }
        }
        
        appUpdateInfoTask.addOnFailureListener { exception: Exception ->
            Log.e(TAG, "즉시 업데이트 시작 실패", exception)
            result.success(false)
        }
    }
    
    private fun completeFlexibleUpdate(result: MethodChannel.Result) {
        appUpdateManager.completeUpdate()
        result.success(null)
    }
    
    override fun onResume() {
        super.onResume()
        
        // 유연한 업데이트가 완료되었는지 확인
        appUpdateManager.appUpdateInfo.addOnSuccessListener { appUpdateInfo: AppUpdateInfo ->
            if (appUpdateInfo.installStatus() == InstallStatus.DOWNLOADED) {
                // 업데이트가 다운로드되었음을 사용자에게 알림
                Log.d(TAG, "업데이트가 다운로드되었습니다. 재시작이 필요합니다.")
            }
        }
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == REQUEST_CODE_UPDATE) {
            if (resultCode != RESULT_OK) {
                Log.d(TAG, "업데이트가 취소되었습니다.")
            }
        }
    }
}
