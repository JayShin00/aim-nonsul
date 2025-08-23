import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

/// Background service that handles persistent notification updates
/// This service ensures notifications are updated even when the app is not active
class BackgroundNotificationService {
  static const String _isolateName = 'background_notification_isolate';
  static const String _lastUpdateKey = 'last_notification_update';
  
  /// Initialize the background service
  static Future<void> initialize() async {
    // Register the isolate callback
    IsolateNameServer.registerPortWithName(
      _createReceivePort().sendPort,
      _isolateName,
    );
    
    // Start periodic updates when the app launches
    await _schedulePeriodicUpdates();
  }

  /// Create a receive port for background communication
  static ReceivePort _createReceivePort() {
    final receivePort = ReceivePort();
    receivePort.listen((dynamic data) {
      if (data == 'update_notifications') {
        _updateNotificationsInBackground();
      }
    });
    return receivePort;
  }

  /// Schedule periodic notification updates
  static Future<void> _schedulePeriodicUpdates() async {
    try {
      // Update immediately
      await _updateNotificationsInBackground();
      
      // Set up timer for daily updates
      Timer.periodic(const Duration(days: 1), (timer) async {
        await _updateNotificationsInBackground();
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error scheduling periodic updates: $e');
      }
    }
  }

  /// Update notifications in the background
  static Future<void> _updateNotificationsInBackground() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isNotificationEnabled = prefs.getBool('notifications_enabled') ?? false;
      
      if (!isNotificationEnabled) {
        if (kDebugMode) {
          print('Notifications disabled, skipping background update');
        }
        return;
      }

      // Check if we need to update (avoid excessive updates)
      final lastUpdate = prefs.getInt(_lastUpdateKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final updateInterval = const Duration(hours: 12).inMilliseconds; // Allow update twice a day if needed
      
      if (now - lastUpdate < updateInterval) {
        if (kDebugMode) {
          print('Skipping background update, too soon since last update');
        }
        return;
      }

      // Update notifications
      final notificationService = NotificationService();
      await notificationService.showDDayNotification();
      
      // Record the update time
      await prefs.setInt(_lastUpdateKey, now);
      
      if (kDebugMode) {
        print('Background notification update completed at ${DateTime.now()}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating notifications in background: $e');
      }
    }
  }

  /// Trigger immediate notification update from main isolate
  static void triggerUpdate() {
    try {
      final sendPort = IsolateNameServer.lookupPortByName(_isolateName);
      sendPort?.send('update_notifications');
    } catch (e) {
      if (kDebugMode) {
        print('Error triggering notification update: $e');
      }
      // Fallback: update directly
      _updateNotificationsInBackground();
    }
  }

  /// Handle app lifecycle changes
  static Future<void> onAppLifecycleChanged(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        // App became active, update notifications
        await _updateNotificationsInBackground();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // App is going to background, ensure notifications are up to date
        await _updateNotificationsInBackground();
        break;
      case AppLifecycleState.hidden:
        // App is hidden but still running
        break;
    }
  }

  /// Force update all notifications
  static Future<void> forceUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastUpdateKey, 0); // Reset update time to force update
    await _updateNotificationsInBackground();
  }

  /// Check if background updates are working properly
  static Future<bool> isBackgroundUpdateWorking() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getInt(_lastUpdateKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final maxInterval = const Duration(days: 1).inMilliseconds;
      
      return (now - lastUpdate) < maxInterval;
    } catch (e) {
      return false;
    }
  }

  /// Clean up background service
  static void dispose() {
    try {
      IsolateNameServer.removePortNameMapping(_isolateName);
    } catch (e) {
      if (kDebugMode) {
        print('Error disposing background notification service: $e');
      }
    }
  }
}