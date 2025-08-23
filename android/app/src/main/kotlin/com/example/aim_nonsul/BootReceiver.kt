package com.example.aim_nonsul

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "BootReceiver"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val NOTIFICATION_ENABLED_KEY = "flutter.notifications_enabled"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Received intent: ${intent.action}")
        
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_PACKAGE_REPLACED -> {
                restartNotificationsIfNeeded(context)
            }
        }
    }
    
    private fun restartNotificationsIfNeeded(context: Context) {
        try {
            // Check if notifications were enabled before reboot
            val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val notificationsEnabled = prefs.getBoolean(NOTIFICATION_ENABLED_KEY, false)
            
            Log.d(TAG, "Notifications enabled: $notificationsEnabled")
            
            if (notificationsEnabled) {
                // Create an intent to launch the app and trigger notification update
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    putExtra("trigger_notification_update", true)
                }
                
                context.startActivity(launchIntent)
                Log.d(TAG, "App launch triggered to restart notifications")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error restarting notifications after boot", e)
        }
    }
}