import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exam_schedule.dart';
import 'package:intl/intl.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static const String _channelId = 'exam_dday_channel';
  static const String _channelName = 'Exam D-Day Notifications';
  static const String _channelDescription = 'Persistent notifications showing exam D-Day countdown';
  static const int _notificationId = 1000;

  /// Initialize the notification service
  Future<void> initialize() async {
    // Android initialization settings
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS initialization settings  
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channel for Android
    await _createNotificationChannel();
  }

  /// Create Android notification channel
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      showBadge: true,
      enableVibration: true,
      enableLights: true,
    );

    await _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Handle notification tap
  void _onNotificationTap(NotificationResponse response) {
    // When notification is tapped, the app will open automatically
    // Additional handling can be added here if needed
    if (kDebugMode) {
      print('Notification tapped: ${response.id}');
    }
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = 
        _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    final bool? granted = await androidPlugin?.requestNotificationsPermission();
    return granted ?? false;
  }

  /// Show or update the D-Day notification
  Future<void> showDDayNotification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // LocalScheduleService에서 저장하는 키와 일치하도록 수정
      final selectedSchedulesJsonList = prefs.getStringList('selectedSchedules') ?? [];
      
      if (kDebugMode) {
        print('=== Notification Service Debug ===');
        print('selectedSchedulesJsonList: $selectedSchedulesJsonList');
        
        // Print all SharedPreferences keys for debugging
        final allKeys = prefs.getKeys();
        print('All SharedPreferences keys:');
        for (String key in allKeys) {
          print('  $key: ${prefs.get(key)}');
        }
      }
      
      if (selectedSchedulesJsonList.isEmpty) {
        // No schedules selected, hide notification
        if (kDebugMode) {
          print('No schedules found, canceling notification');
        }
        await cancelDDayNotification();
        return;
      }

      // Convert StringList to actual ExamSchedule objects
      final schedules = selectedSchedulesJsonList.map((jsonString) {
        return jsonDecode(jsonString);
      }).toList();
      if (schedules.isEmpty) {
        await cancelDDayNotification();
        return;
      }

      // Find primary schedule or use first one
      Map<String, dynamic> selectedScheduleJson = schedules.first;
      for (var schedule in schedules) {
        if (schedule['isPrimary'] == true) {
          selectedScheduleJson = schedule;
          break;
        }
      }

      final schedule = ExamSchedule.fromMap(selectedScheduleJson);
      
      // Calculate D-Day
      final now = DateTime.now();
      final examDate = schedule.examDateTime;
      final daysUntilExam = examDate.difference(DateTime(now.year, now.month, now.day)).inDays;
      
      String dDayText;
      if (daysUntilExam == 0) {
        dDayText = 'D-Day';
      } else if (daysUntilExam < 0) {
        dDayText = '종료';
      } else {
        dDayText = 'D-$daysUntilExam';
      }

      // Format exam date
      final formattedDate = DateFormat('yyyy.MM.dd').format(schedule.examDateTime);
      
      // Create notification
      if (kDebugMode) {
        print('Creating notification: $dDayText for ${schedule.university} ${schedule.department}');
      }
      
      await _showPersistentNotification(
        dDayText: dDayText,
        university: schedule.university,
        department: schedule.department,
        examDate: formattedDate,
        isPrimary: schedule.isPrimary,
      );
      
      if (kDebugMode) {
        print('Notification created successfully');
      }

    } catch (e) {
      if (kDebugMode) {
        print('Error showing D-Day notification: $e');
      }
    }
  }

  /// Show persistent notification with exam info
  Future<void> _showPersistentNotification({
    required String dDayText,
    required String university,
    required String department,
    required String examDate,
    required bool isPrimary,
  }) async {
    // Clean department name (remove star if present)
    final cleanDepartment = department.replaceAll('⭐ ', '');
    
    // Create big text style with exam details
    final String bigText = '$university\n$cleanDepartment\n시험일: $examDate';
    
    // Notification title with D-Day and star if primary
    final String title = isPrimary ? '$dDayText ⭐ AIM 논술' : '$dDayText AIM 논술';

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true, // Makes notification persistent
      autoCancel: false, // Prevents swipe to dismiss
      showWhen: false,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public, // Shows on lock screen
      color: const Color(0xFFD63384), // AIM Pink color
      colorized: true,
      styleInformation: BigTextStyleInformation(
        bigText,
        htmlFormatBigText: false,
        contentTitle: title,
        htmlFormatContentTitle: false,
        summaryText: 'AIM 논술 D-Day',
        htmlFormatSummaryText: false,
      ),
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'open_app',
          '앱 열기',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'dismiss',
          '해제',
          cancelNotification: true,
        ),
      ],
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
      interruptionLevel: InterruptionLevel.active,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      _notificationId,
      title,
      university,
      details,
    );
  }

  /// Cancel the D-Day notification
  Future<void> cancelDDayNotification() async {
    await _notifications.cancel(_notificationId);
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? false;
  }

  /// Set notification enabled state
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
    
    if (enabled) {
      await showDDayNotification();
    } else {
      await cancelDDayNotification();
    }
  }

  /// Schedule daily notification updates
  Future<void> scheduleDailyUpdate() async {
    // Cancel any existing scheduled notifications
    await _notifications.cancelAll();
    
    // For now, we'll rely on app launches to trigger updates
    // In a production app, you might want to use background tasks
    // or schedule multiple notifications in advance
  }
}