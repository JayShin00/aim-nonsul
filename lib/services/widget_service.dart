import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exam_schedule.dart';

class WidgetService {
  static const String _widgetName = 'ExamWidget';

  /// 위젯 업데이트
  static Future<void> updateWidget(List<ExamSchedule> examList) async {
    if (examList.isEmpty) {
      // 시험이 없는 경우
      await _clearWidgetData();
    } else {
      // 대표 모집단위가 있는지 확인
      ExamSchedule? primaryExam;
      try {
        primaryExam = examList.firstWhere(
          (exam) => exam.isPrimary && exam.examDateTime.isAfter(DateTime.now()),
        );
      } catch (e) {
        primaryExam = null;
      }

      ExamSchedule? targetExam;
      if (primaryExam != null) {
        // 대표 모집단위가 있고 아직 시험이 끝나지 않은 경우
        targetExam = primaryExam;
      } else {
        // 대표 모집단위가 없거나 이미 끝난 경우, 다음 시험 찾기
        targetExam = _findNextExam(examList);
      }

      if (targetExam != null) {
        await _updateWidgetData(targetExam);
      } else {
        // 남은 시험이 없는 경우
        await _clearWidgetData();
      }
    }
  }

  /// 위젯 데이터 업데이트 (iOS와 Android 모두 지원)
  static Future<void> _updateWidgetData(ExamSchedule exam) async {
    try {
      // iOS 위젯용 JSON 데이터 생성
      final examData = {
        'university': exam.university,
        'department': exam.department,
        'examDateTime': exam.examDateTime.toIso8601String(),
        'isPrimary': exam.isPrimary,
      };

      // JSON 문자열로 변환
      final jsonString = jsonEncode(examData);

      // iOS 위젯용 데이터 저장
      await HomeWidget.saveWidgetData<String>('primary_exam', jsonString);

      // 기존 방식도 유지 (Android 위젯 호환성)
      final dateFormat = DateFormat('yyyy-MM-dd');
      final timeFormat = DateFormat('HH:mm');
      final examDate = dateFormat.format(exam.examDateTime);
      final examTime = timeFormat.format(exam.examDateTime);
      final String daysLeft = _calculateDaysLeft(exam.examDateTime);

      await HomeWidget.saveWidgetData<String>(
        'exam_title',
        exam.isPrimary ? '⭐ ${exam.department}' : exam.department,
      );
      await HomeWidget.saveWidgetData<String>(
        'exam_university',
        exam.university,
      );
      await HomeWidget.saveWidgetData<String>('exam_date', examDate);
      await HomeWidget.saveWidgetData<String>('exam_time', examTime);
      await HomeWidget.saveWidgetData<String>('exam_room', '');
      await HomeWidget.saveWidgetData<String>('days_left', daysLeft);

      // Android 위젯을 위한 추가 데이터 저장
      if (Platform.isAndroid) {
        await _saveAndroidWidgetData([exam]);
      }

      // 위젯 업데이트 트리거
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: 'ExamWidget',
        iOSName: 'ExamWidget',
      );

      print('위젯 업데이트 성공: ${exam.department}');
      print('저장된 데이터: exam_title=${exam.isPrimary ? '⭐ ${exam.department}' : exam.department}');
      print('저장된 데이터: exam_university=${exam.university}');
      print('저장된 데이터: exam_date=$examDate');
      print('저장된 데이터: exam_time=$examTime');
      print('App Group ID: group.com.aim.aimNonsul.ExamWidget');
    } catch (e) {
      print('위젯 업데이트 실패: $e');
    }
  }

  /// 위젯 데이터 초기화
  static Future<void> _clearWidgetData() async {
    try {
      await HomeWidget.saveWidgetData<String>('primary_exam', '');
      await HomeWidget.saveWidgetData<String>('exam_title', '등록된 시험이 없습니다');
      await HomeWidget.saveWidgetData<String>('exam_university', '');
      await HomeWidget.saveWidgetData<String>('exam_date', '');
      await HomeWidget.saveWidgetData<String>('exam_time', '');
      await HomeWidget.saveWidgetData<String>('exam_room', '');
      await HomeWidget.saveWidgetData<String>('days_left', '');

      // Android 위젯 데이터도 초기화
      if (Platform.isAndroid) {
        await _saveAndroidWidgetData([]);
      }

      // 위젯 업데이트 트리거
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: 'ExamWidget',
        iOSName: 'ExamWidget',
      );
    } catch (e) {
      print('위젯 데이터 초기화 실패: $e');
    }
  }

  /// 다음 시험 찾기
  static ExamSchedule? _findNextExam(List<ExamSchedule> examList) {
    final now = DateTime.now();

    // 현재 시간 이후의 시험들만 필터링
    final upcomingExams =
        examList.where((exam) => exam.examDateTime.isAfter(now)).toList();

    if (upcomingExams.isEmpty) {
      return null;
    }

    // 가장 가까운 시험 찾기
    upcomingExams.sort((a, b) => a.examDateTime.compareTo(b.examDateTime));
    return upcomingExams.first;
  }

  /// Android 위젯을 위한 데이터 저장
  static Future<void> _saveAndroidWidgetData(List<ExamSchedule> schedules) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (schedules.isNotEmpty) {
        // JSON 배열로 변환
        final jsonList = schedules.map((schedule) => {
          'id': schedule.id,
          'university': schedule.university,
          'department': schedule.department,
          'category': schedule.category,
          'examDateTime': schedule.examDateTime.toIso8601String(),
          'isPrimary': schedule.isPrimary,
        }).toList();
        
        final jsonString = jsonEncode(jsonList);
        
        // Android 위젯이 읽을 수 있는 키로 저장
        await prefs.setString('flutter.selectedSchedules', jsonString);
        
        print('Android 위젯 데이터 저장 완료: $jsonString');
      } else {
        // 빈 데이터 저장
        await prefs.setString('flutter.selectedSchedules', '[]');
        print('Android 위젯 데이터 초기화 완료');
      }
    } catch (e) {
      print('Android 위젯 데이터 저장 실패: $e');
    }
  }

  /// D-Day 계산
  static String _calculateDaysLeft(DateTime examDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final examDay = DateTime(examDate.year, examDate.month, examDate.day);
    final difference = examDay.difference(today).inDays;

    if (difference == 0) {
      return 'D-Day';
    } else if (difference > 0) {
      return 'D-$difference';
    } else {
      return '종료';
    }
  }
}
