import 'package:shared_preferences/shared_preferences.dart';
import 'package:aim_nonsul/models/exam_schedule.dart';
import 'package:aim_nonsul/services/widget_service.dart';
import 'package:aim_nonsul/services/notification_service.dart';
import 'package:aim_nonsul/services/background_notification_service.dart';
import 'dart:convert';

class LocalScheduleService {
  static const String _selectedSchedulesKey = 'selectedSchedules';
  static const String _firstLaunchKey = 'isFirstLaunch';
  static const String _suneungPrimaryKey = 'suneungPrimary';

  // 선택된 일정들 불러오기 (수능 포함)
  Future<List<ExamSchedule>> loadSelectedSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_selectedSchedulesKey) ?? [];
    final userSchedules = jsonList.map((e) => ExamSchedule.fromMap(jsonDecode(e))).toList();
    
    // 수능 고정 상태 확인
    final suneungPrimary = prefs.getBool(_suneungPrimaryKey) ?? false;
    
    // 수능이 이미 있는지 확인
    final hasSuneung = userSchedules.any((schedule) => schedule.id == -1);
    
    if (!hasSuneung) {
      // 수능 스케줄 생성
      final suneungExam = ExamSchedule(
        id: -1,
        university: '대학수학능력시험',
        department: '수능',
        category: '수능',
        examDateTime: DateTime(2025, 11, 13),
        isPrimary: suneungPrimary,
      );
      userSchedules.add(suneungExam);
    } else {
      // 수능이 있으면 고정 상태 업데이트
      for (int i = 0; i < userSchedules.length; i++) {
        if (userSchedules[i].id == -1) {
          final schedule = userSchedules[i];
          userSchedules[i] = ExamSchedule(
            id: schedule.id,
            university: schedule.university,
            category: schedule.category,
            department: schedule.department,
            examDateTime: schedule.examDateTime,
            isPrimary: suneungPrimary,
          );
          break;
        }
      }
    }
    
    // 날짜순으로 정렬
    userSchedules.sort((a, b) {
      int dateComparison = a.examDateTime.compareTo(b.examDateTime);
      if (dateComparison != 0) return dateComparison;
      int universityComparison = a.university.compareTo(b.university);
      if (universityComparison != 0) return universityComparison;
      return a.category.compareTo(b.category);
    });
    
    return userSchedules;
  }

  // 새로운 일정 저장하기 (기존 목록에 추가)
  Future<void> saveSelectedSchedule(ExamSchedule schedule) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadSelectedSchedules();
    existing.add(schedule);

    // 날짜순으로 정렬
    existing.sort((a, b) {
      int dateComparison = a.examDateTime.compareTo(b.examDateTime);
      if (dateComparison != 0) return dateComparison;
      int universityComparison = a.university.compareTo(b.university);
      if (universityComparison != 0) return universityComparison;
      return a.category.compareTo(b.category);
    });

    // 수능 제외하고 저장 (수능은 기본 스케줄이므로)
    final userSchedules = existing.where((schedule) => schedule.id != -1).toList();
    final jsonList = userSchedules.map((e) => jsonEncode(e.toMap())).toList();
    await prefs.setStringList(_selectedSchedulesKey, jsonList);

    // 위젯 업데이트 (전체 스케줄 포함)
    await _updateAllWidgets(existing);
  }

  // 특정 ID의 일정 삭제하기 (수능은 삭제 불가)
  Future<void> removeSelectedSchedule(int id) async {
    if (id == -1) return; // 수능은 삭제 불가
    
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadSelectedSchedules();
    existing.removeWhere((schedule) => schedule.id == id);

    // 날짜순으로 정렬
    existing.sort((a, b) {
      int dateComparison = a.examDateTime.compareTo(b.examDateTime);
      if (dateComparison != 0) return dateComparison;
      int universityComparison = a.university.compareTo(b.university);
      if (universityComparison != 0) return universityComparison;
      return a.category.compareTo(b.category);
    });

    // 수능 제외하고 저장
    final userSchedules = existing.where((schedule) => schedule.id != -1).toList();
    final jsonList = userSchedules.map((e) => jsonEncode(e.toMap())).toList();
    await prefs.setStringList(_selectedSchedulesKey, jsonList);

    // 위젯 업데이트 (전체 스케줄 포함)
    await _updateAllWidgets(existing);
  }

  // 전체 선택된 일정 목록 저장하기 (덮어쓰기)
  Future<void> saveAllSelectedSchedules(List<ExamSchedule> schedules) async {
    final prefs = await SharedPreferences.getInstance();

    // 날짜순으로 정렬
    schedules.sort((a, b) {
      int dateComparison = a.examDateTime.compareTo(b.examDateTime);
      if (dateComparison != 0) return dateComparison;
      int universityComparison = a.university.compareTo(b.university);
      if (universityComparison != 0) return universityComparison;
      return a.category.compareTo(b.category);
    });

    // 수능 제외하고 저장 (수능은 기본 스케줄이므로)
    final userSchedules = schedules.where((schedule) => schedule.id != -1).toList();
    final jsonList = userSchedules.map((e) => jsonEncode(e.toMap())).toList();
    await prefs.setStringList(_selectedSchedulesKey, jsonList);

    // 위젯 업데이트 (전체 스케줄 포함)
    await _updateAllWidgets(schedules);
  }

  // 선택된 일정 개수 가져오기
  Future<int> getSelectedScheduleCount() async {
    final schedules = await loadSelectedSchedules();
    return schedules.length;
  }

  // 모든 선택된 일정 삭제하기
  Future<void> clearAllSelectedSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedSchedulesKey);

    // 위젯 업데이트 (빈 데이터)
    await _updateAllWidgets([]);
  }

  // 플랫폼별 위젯 업데이트
  Future<void> _updateAllWidgets(List<ExamSchedule> schedules) async {
    print('LocalScheduleService._updateAllWidgets 호출됨: ${schedules.length}개 스케줄');
    
    // WidgetService를 통해 통합 위젯 업데이트 (iOS, Android 모두)
    await WidgetService.updateWidget(schedules);
    
    // 알림 업데이트 (모든 플랫폼)
    await _updateNotifications();
  }


  // 대표 모집단위 설정하기 (기존 대표는 해제)
  Future<void> setPrimarySchedule(int targetId) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadSelectedSchedules();

    if (targetId == -1) {
      // 수능을 고정하는 경우
      await prefs.setBool(_suneungPrimaryKey, true);
      // 다른 일정들의 고정 해제
      for (int i = 0; i < existing.length; i++) {
        final schedule = existing[i];
        existing[i] = ExamSchedule(
          id: schedule.id,
          university: schedule.university,
          category: schedule.category,
          department: schedule.department,
          examDateTime: schedule.examDateTime,
          isPrimary: schedule.id == -1, // 수능만 true
        );
      }
    } else {
      // 일반 일정을 고정하는 경우
      await prefs.setBool(_suneungPrimaryKey, false); // 수능 고정 해제
      // 모든 isPrimary를 false로 설정
      for (int i = 0; i < existing.length; i++) {
        final schedule = existing[i];
        existing[i] = ExamSchedule(
          id: schedule.id,
          university: schedule.university,
          category: schedule.category,
          department: schedule.department,
          examDateTime: schedule.examDateTime,
          isPrimary: schedule.id == targetId, // 해당 ID만 true로 설정
        );
      }
    }

    // 업데이트된 목록 저장
    await saveAllSelectedSchedules(existing);
  }

  // 대표 모집단위 해제하기
  Future<void> unsetPrimarySchedule(int targetId) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadSelectedSchedules();

    if (targetId == -1) {
      // 수능 고정 해제
      await prefs.setBool(_suneungPrimaryKey, false);
    }

    // 해당 ID의 isPrimary를 false로 설정
    for (int i = 0; i < existing.length; i++) {
      final schedule = existing[i];
      if (schedule.id == targetId) {
        existing[i] = ExamSchedule(
          id: schedule.id,
          university: schedule.university,
          category: schedule.category,
          department: schedule.department,
          examDateTime: schedule.examDateTime,
          isPrimary: false,
        );
        break;
      }
    }

    // 업데이트된 목록 저장
    await saveAllSelectedSchedules(existing);
  }

  // 현재 대표 모집단위 가져오기
  Future<ExamSchedule?> getPrimarySchedule() async {
    final schedules = await loadSelectedSchedules();
    try {
      return schedules.firstWhere((schedule) => schedule.isPrimary);
    } catch (e) {
      return null; // 대표 모집단위가 없는 경우
    }
  }

  // 첫 실행 여부 확인
  Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_firstLaunchKey) ?? true;
  }

  // 첫 실행 상태 설정
  Future<void> setFirstLaunchComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstLaunchKey, false);
  }

  // 알림 업데이트
  Future<void> _updateNotifications() async {
    try {
      final notificationService = NotificationService();
      final isNotificationEnabled = await notificationService.areNotificationsEnabled();
      
      if (isNotificationEnabled) {
        // 즉시 업데이트
        await notificationService.showDDayNotification();
        // 백그라운드 업데이트 트리거
        BackgroundNotificationService.triggerUpdate();
      }
    } catch (e) {
      print('알림 업데이트 실패: $e');
    }
  }
}
