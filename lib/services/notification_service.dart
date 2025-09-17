import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exam_schedule.dart';
import 'package:intl/intl.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static const MethodChannel _liveActivityChannel = MethodChannel('com.aim.aimNonsul/liveActivity');
  static const String _channelId = 'exam_dday_channel';
  static const String _channelName = 'Exam D-Day Notifications';
  static const String _channelDescription = 'Persistent notifications showing exam D-Day countdown';
  static const String _summaryChannelId = 'exam_summary_channel';
  static const String _summaryChannelName = 'Exam Summary';
  static const String _groupKey = 'com.aim.aimNonsul.EXAM_NOTIFICATIONS';
  static const int _summaryNotificationId = 1000;
  static const int _baseNotificationId = 1001;

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

  /// Create Android notification channels
  Future<void> _createNotificationChannel() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    // Main notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      showBadge: true,
      enableVibration: true,
      enableLights: true,
    );

    // Summary notification channel
    const AndroidNotificationChannel summaryChannel = AndroidNotificationChannel(
      _summaryChannelId,
      _summaryChannelName,
      description: 'Summary of exam notifications',
      importance: Importance.high,
      showBadge: true,
      enableVibration: false,
      enableLights: true,
    );

    await androidPlugin?.createNotificationChannel(channel);
    await androidPlugin?.createNotificationChannel(summaryChannel);
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

  /// Show or update multiple D-Day notifications (one per exam)
  Future<void> showDDayNotification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // LocalScheduleService에서 저장하는 키와 일치하도록 수정
      final selectedSchedulesJsonList = prefs.getStringList('selectedSchedules') ?? [];
      
      if (kDebugMode) {
        print('=== Notification Service Debug ===');
        print('selectedSchedulesJsonList: $selectedSchedulesJsonList');
      }
      
      if (selectedSchedulesJsonList.isEmpty) {
        // No schedules selected, hide all notifications
        if (kDebugMode) {
          print('No schedules found, canceling all notifications');
        }
        await cancelAllDDayNotifications();
        return;
      }

      // Convert StringList to actual ExamSchedule objects
      final scheduleMaps = selectedSchedulesJsonList.map((jsonString) {
        return jsonDecode(jsonString);
      }).toList();
      
      if (scheduleMaps.isEmpty) {
        await cancelAllDDayNotifications();
        return;
      }

      final schedules = scheduleMaps.map((map) => ExamSchedule.fromMap(map)).toList();
      
      // Sort schedules by exam date
      schedules.sort((a, b) => a.examDateTime.compareTo(b.examDateTime));
      
      // Create individual notifications for each exam
      for (int i = 0; i < schedules.length; i++) {
        final schedule = schedules[i];
        await _showIndividualNotification(schedule, i);
      }
      
      // Create summary notification if there are multiple exams
      if (schedules.length > 1) {
        await _showSummaryNotification(schedules);
      }
      
      if (kDebugMode) {
        print('Created ${schedules.length} individual notifications');
      }

    } catch (e) {
      if (kDebugMode) {
        print('Error showing D-Day notifications: $e');
      }
    }
  }

  /// Show individual notification for a single exam
  Future<void> _showIndividualNotification(ExamSchedule schedule, int index) async {
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
    
    // Clean department name (remove star if present)
    final cleanDepartment = schedule.department.replaceAll('⭐ ', '');
    
    // Create notification content
    final String title = schedule.isPrimary ? '$dDayText ⭐ ${schedule.university}' : '$dDayText ${schedule.university}';
    final String body = '$cleanDepartment • $formattedDate';
    final String bigText = '${schedule.university}\n$cleanDepartment\n시험일: $formattedDate\n\n남은 일수: $dDayText';
    
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
      visibility: NotificationVisibility.public, // Shows full content on lock screen
      color: const Color(0xFFD63384), // AIM Pink color
      colorized: true,
      groupKey: _groupKey, // Group notifications together
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

    final notificationId = _baseNotificationId + index;
    await _notifications.show(
      notificationId,
      title,
      body,
      details,
    );
  }

  /// Show summary notification when there are multiple exams
  Future<void> _showSummaryNotification(List<ExamSchedule> schedules) async {
    // Create summary of all exams
    final buffer = StringBuffer();
    for (final schedule in schedules) {
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
      
      final cleanDepartment = schedule.department.replaceAll('⭐ ', '');
      final star = schedule.isPrimary ? '⭐ ' : '';
      buffer.writeln('$star${schedule.university} $cleanDepartment ($dDayText)');
    }

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _summaryChannelId,
      _summaryChannelName,
      channelDescription: 'Summary of all exam notifications',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      color: const Color(0xFFD63384),
      colorized: true,
      groupKey: _groupKey,
      setAsGroupSummary: true, // This makes it the summary notification
      styleInformation: BigTextStyleInformation(
        buffer.toString().trim(),
        htmlFormatBigText: false,
        contentTitle: 'AIM 논술 D-Day (${schedules.length}개 시험)',
        htmlFormatContentTitle: false,
        summaryText: '모든 시험 일정',
        htmlFormatSummaryText: false,
      ),
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'open_app',
          '앱 열기',
          showsUserInterface: true,
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
      _summaryNotificationId,
      'AIM 논술 D-Day',
      '${schedules.length}개 시험 일정',
      details,
    );
  }

  /// Cancel all D-Day notifications
  Future<void> cancelAllDDayNotifications() async {
    // Cancel summary notification
    await _notifications.cancel(_summaryNotificationId);
    
    // Cancel all individual notifications (assuming max 50 notifications)
    for (int i = 0; i < 50; i++) {
      await _notifications.cancel(_baseNotificationId + i);
    }
  }

  /// Cancel the old single D-Day notification (for backwards compatibility)
  Future<void> cancelDDayNotification() async {
    await cancelAllDDayNotifications();
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
      await cancelAllDDayNotifications();
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

  // MARK: - iOS Live Activity Support

  /// Start Live Activity for iOS (requires iOS 16.1+)
  Future<bool> startLiveActivity(ExamSchedule primaryExam) async {
    if (!Platform.isIOS) return false;
    
    try {
      final now = DateTime.now();
      final examDate = primaryExam.examDateTime;
      final daysUntilExam = examDate.difference(DateTime(now.year, now.month, now.day)).inDays;
      
      String dDayText;
      if (daysUntilExam == 0) {
        dDayText = 'D-Day';
      } else if (daysUntilExam < 0) {
        dDayText = '종료';
      } else {
        dDayText = 'D-$daysUntilExam';
      }

      // Calculate time remaining until exam
      final timeRemaining = _formatTimeRemaining(examDate.difference(now));
      
      final activityData = {
        'examTitle': primaryExam.department,
        'university': primaryExam.university,
        'examDate': primaryExam.examDateTime.millisecondsSinceEpoch,
        'examInfo': {
          'university': primaryExam.university,
          'department': primaryExam.department,
          'examDate': primaryExam.examDateTime.millisecondsSinceEpoch,
          'isPrimary': primaryExam.isPrimary,
        },
        'dDayText': dDayText,
        'timeRemaining': timeRemaining,
        'lastUpdated': now.millisecondsSinceEpoch,
      };

      final result = await _liveActivityChannel.invokeMethod('startLiveActivity', activityData);
      
      if (kDebugMode) {
        print('📱 Live Activity started: $result');
      }
      
      return result as bool? ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to start Live Activity: $e');
      }
      return false;
    }
  }

  /// Update Live Activity
  Future<bool> updateLiveActivity(ExamSchedule primaryExam) async {
    if (!Platform.isIOS) return false;
    
    try {
      final now = DateTime.now();
      final examDate = primaryExam.examDateTime;
      final daysUntilExam = examDate.difference(DateTime(now.year, now.month, now.day)).inDays;
      
      String dDayText;
      if (daysUntilExam == 0) {
        dDayText = 'D-Day';
      } else if (daysUntilExam < 0) {
        dDayText = '종료';
      } else {
        dDayText = 'D-$daysUntilExam';
      }

      final timeRemaining = _formatTimeRemaining(examDate.difference(now));
      
      final activityData = {
        'examInfo': {
          'university': primaryExam.university,
          'department': primaryExam.department,
          'examDate': primaryExam.examDateTime.millisecondsSinceEpoch,
          'isPrimary': primaryExam.isPrimary,
        },
        'dDayText': dDayText,
        'timeRemaining': timeRemaining,
        'lastUpdated': now.millisecondsSinceEpoch,
      };

      final result = await _liveActivityChannel.invokeMethod('updateLiveActivity', activityData);
      
      if (kDebugMode) {
        print('📱 Live Activity updated: $result');
      }
      
      return result as bool? ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to update Live Activity: $e');
      }
      return false;
    }
  }

  /// Stop Live Activity
  Future<bool> stopLiveActivity() async {
    if (!Platform.isIOS) return false;
    
    try {
      final result = await _liveActivityChannel.invokeMethod('stopLiveActivity');
      
      if (kDebugMode) {
        print('📱 Live Activity stopped: $result');
      }
      
      return result as bool? ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to stop Live Activity: $e');
      }
      return false;
    }
  }

  /// Check if Live Activities are available
  Future<bool> areLiveActivitiesAvailable() async {
    if (!Platform.isIOS) return false;
    
    try {
      final result = await _liveActivityChannel.invokeMethod('areLiveActivitiesAvailable');
      return result as bool? ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to check Live Activities availability: $e');
      }
      return false;
    }
  }

  /// Enhanced iOS notification with Live Activity integration
  Future<void> showIOSEnhancedNotification(List<ExamSchedule> schedules) async {
    if (!Platform.isIOS) return;

    // Show regular notifications
    await showDDayNotification();

    // Start Live Activity for primary exam if available
    if (schedules.isNotEmpty) {
      final primaryExam = schedules.firstWhere(
        (exam) => exam.isPrimary, 
        orElse: () => schedules.first
      );

      final isLiveActivityAvailable = await areLiveActivitiesAvailable();
      if (isLiveActivityAvailable) {
        await startLiveActivity(primaryExam);
      }
    }
  }

  String _formatTimeRemaining(Duration duration) {
    if (duration.isNegative) return '';
    
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    
    if (days > 0) {
      return '$days일 $hours시간';
    } else if (hours > 0) {
      return '$hours시간 $minutes분';
    } else if (minutes > 0) {
      return '$minutes분';
    } else {
      return '곧 시작';
    }
  }
}