import 'package:shared_preferences/shared_preferences.dart';
import 'package:aim_nonsul/models/exam_schedule.dart';
import 'package:aim_nonsul/services/widget_service.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

class LocalScheduleService {
  static const String _selectedSchedulesKey = 'selectedSchedules';

  // 선택된 일정들 불러오기
  Future<List<ExamSchedule>> loadSelectedSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_selectedSchedulesKey) ?? [];
    return jsonList.map((e) => ExamSchedule.fromMap(jsonDecode(e))).toList();
  }

  // 새로운 일정 저장하기 (기존 목록에 추가)
  Future<void> saveSelectedSchedule(ExamSchedule schedule) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadSelectedSchedules();
    existing.add(schedule);

    // 날짜 > 학교 > 계열 순으로 정렬
    existing.sort((a, b) {
      int dateComparison = a.examDateTime.compareTo(b.examDateTime);
      if (dateComparison != 0) return dateComparison;
      
      int universityComparison = a.university.compareTo(b.university);
      if (universityComparison != 0) return universityComparison;
      
      return a.category.compareTo(b.category);
    });

    final jsonList = existing.map((e) => jsonEncode(e.toMap())).toList();
    await prefs.setStringList(_selectedSchedulesKey, jsonList);

    // 위젯 업데이트 (iOS와 Android 모두)
    await _updateAllWidgets(existing);
  }

  // 특정 인덱스의 일정 삭제하기
  Future<void> removeSelectedSchedule(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadSelectedSchedules();
    if (index >= 0 && index < existing.length) {
      existing.removeAt(index);

      // 날짜 > 학교 > 계열 순으로 정렬
      existing.sort((a, b) {
        int dateComparison = a.examDateTime.compareTo(b.examDateTime);
        if (dateComparison != 0) return dateComparison;
        
        int universityComparison = a.university.compareTo(b.university);
        if (universityComparison != 0) return universityComparison;
        
        return a.category.compareTo(b.category);
      });

      final jsonList = existing.map((e) => jsonEncode(e.toMap())).toList();
      await prefs.setStringList(_selectedSchedulesKey, jsonList);

      // 위젯 업데이트 (iOS와 Android 모두)
      await _updateAllWidgets(existing);
    }
  }

  // 전체 선택된 일정 목록 저장하기 (덮어쓰기)
  Future<void> saveAllSelectedSchedules(List<ExamSchedule> schedules) async {
    final prefs = await SharedPreferences.getInstance();

    // 날짜 > 학교 > 계열 순으로 정렬
    schedules.sort((a, b) {
      int dateComparison = a.examDateTime.compareTo(b.examDateTime);
      if (dateComparison != 0) return dateComparison;
      
      int universityComparison = a.university.compareTo(b.university);
      if (universityComparison != 0) return universityComparison;
      
      return a.category.compareTo(b.category);
    });

    final jsonList = schedules.map((e) => jsonEncode(e.toMap())).toList();
    await prefs.setStringList(_selectedSchedulesKey, jsonList);

    // 위젯 업데이트 (iOS와 Android 모두)
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
    if (Platform.isIOS) {
      // iOS 위젯 업데이트
      await WidgetService.updateWidget(schedules);
    } else if (Platform.isAndroid) {
      // Android 위젯 업데이트 (SharedPreferences를 통해)
      await _updateAndroidWidget(schedules);
    }
  }

  // Android 위젯 데이터 업데이트
  Future<void> _updateAndroidWidget(List<ExamSchedule> schedules) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (schedules.isNotEmpty) {
        // 첫 번째 일정 정보를 위젯용으로 저장
        final firstSchedule = schedules.first;
        final jsonList = schedules.map((e) => e.toMap()).toList();
        final jsonString = jsonEncode(jsonList);

        // Android 위젯이 읽을 수 있는 정확한 키로 저장
        await prefs.setString('flutter.selectedSchedules', jsonString);

        // 개별 데이터도 저장 (호환성을 위해)
        await prefs.setString(
          'flutter.exam_university',
          firstSchedule.university,
        );
        await prefs.setString(
          'flutter.exam_category',
          firstSchedule.category,
        );
        await prefs.setString(
          'flutter.exam_department',
          firstSchedule.department,
        );
        await prefs.setString(
          'flutter.exam_dateTime',
          firstSchedule.examDateTime.toIso8601String(),
        );

        print('Android 위젯 데이터 업데이트 완료');
        print('대학: ${firstSchedule.university}');
        print('학과: ${firstSchedule.department}');
        print('시험일: ${firstSchedule.examDateTime.toIso8601String()}');
        print('전체 JSON: $jsonString');
      } else {
        // 빈 데이터 저장
        await prefs.setString('flutter.selectedSchedules', '[]');
        await prefs.remove('flutter.exam_university');
        await prefs.remove('flutter.exam_category');
        await prefs.remove('flutter.exam_department');
        await prefs.remove('flutter.exam_dateTime');

        print('Android 위젯 데이터 초기화 완료');
      }

      // Android 위젯 강제 업데이트 트리거
      await _triggerAndroidWidgetUpdate();
    } catch (e) {
      print('Android 위젯 업데이트 실패: $e');
    }
  }

  // Android 위젯 업데이트 트리거
  Future<void> _triggerAndroidWidgetUpdate() async {
    if (Platform.isAndroid) {
      try {
        // Method Channel을 통해 Android 위젯 업데이트 요청
        const platform = MethodChannel('com.aim.aimNonsul/widget');
        await platform.invokeMethod('updateAndroidWidget');
      } catch (e) {
        print('Android 위젯 업데이트 트리거 실패: $e');
      }
    }
  }

  // 대표 모집단위 설정하기 (기존 대표는 해제)
  Future<void> setPrimarySchedule(int targetId) async {
    final existing = await loadSelectedSchedules();

    // 모든 isPrimary를 false로 설정
    for (int i = 0; i < existing.length; i++) {
      final schedule = existing[i];
      existing[i] = ExamSchedule(
        id: schedule.id,
        university: schedule.university,
        category: schedule.category,
        department: schedule.department,
        address: schedule.address,
        examDateTime: schedule.examDateTime,
        isPrimary: schedule.id == targetId, // 해당 ID만 true로 설정
      );
    }

    // 업데이트된 목록 저장
    await saveAllSelectedSchedules(existing);
  }

  // 대표 모집단위 해제하기
  Future<void> unsetPrimarySchedule(int targetId) async {
    final existing = await loadSelectedSchedules();

    // 해당 ID의 isPrimary를 false로 설정
    for (int i = 0; i < existing.length; i++) {
      final schedule = existing[i];
      if (schedule.id == targetId) {
        existing[i] = ExamSchedule(
          id: schedule.id,
          university: schedule.university,
          category: schedule.category,
          department: schedule.department,
          address: schedule.address,
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
}
