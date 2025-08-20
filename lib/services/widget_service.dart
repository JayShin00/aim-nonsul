import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exam_schedule.dart';

class WidgetService {
  static const String _widgetName = 'ExamWidget';
  static const String _carouselIndexKey = 'carousel_index';

  /// 위젯 업데이트 (Carousel 지원)
  static Future<void> updateWidget(List<ExamSchedule> examList) async {
    if (examList.isEmpty) {
      // 시험이 없는 경우
      await _clearWidgetData();
    } else {
      // 미래 시험만 필터링
      final upcomingExams = examList
          .where((exam) => exam.examDateTime.isAfter(DateTime.now()))
          .toList();

      if (upcomingExams.isEmpty) {
        await _clearWidgetData();
        return;
      }

      // 현재 carousel index 가져오기
      final currentIndex = await _getCurrentCarouselIndex();
      final validIndex = currentIndex < upcomingExams.length ? currentIndex : 0;
      
      // carousel index 저장
      await _saveCurrentCarouselIndex(validIndex);
      
      // 전체 시험 목록과 현재 인덱스로 위젯 업데이트
      await _updateCarouselWidgetData(upcomingExams, validIndex);
    }
  }

  /// Carousel 위젯 데이터 업데이트
  static Future<void> _updateCarouselWidgetData(List<ExamSchedule> examList, int currentIndex) async {
    try {
      // 전체 시험 목록을 JSON으로 변환
      final examListData = examList.map((exam) => {
        'university': exam.university,
        'department': exam.department,
        'category': exam.category,
        'examDateTime': exam.examDateTime.toIso8601String(),
        'isPrimary': exam.isPrimary,
        'id': exam.id,
      }).toList();

      // Carousel 메타데이터 생성
      final carouselData = {
        'examList': examListData,
        'currentIndex': currentIndex,
        'totalCount': examList.length,
      };

      // iOS 위젯용 전체 데이터 저장
      await HomeWidget.saveWidgetData<String>('carousel_data', jsonEncode(carouselData));

      // 현재 표시할 시험
      final currentExam = examList[currentIndex];
      
      // 기존 방식도 유지 (Android 위젯 호환성)
      final dateFormat = DateFormat('yyyy-MM-dd');
      final timeFormat = DateFormat('HH:mm');
      final examDate = dateFormat.format(currentExam.examDateTime);
      final examTime = timeFormat.format(currentExam.examDateTime);
      final String daysLeft = _calculateDaysLeft(currentExam.examDateTime);

      await HomeWidget.saveWidgetData<String>(
        'exam_title',
        currentExam.isPrimary ? '⭐ ${currentExam.department}' : currentExam.department,
      );
      await HomeWidget.saveWidgetData<String>('exam_university', currentExam.university);
      await HomeWidget.saveWidgetData<String>('exam_date', examDate);
      await HomeWidget.saveWidgetData<String>('exam_time', examTime);
      await HomeWidget.saveWidgetData<String>('exam_room', '');
      await HomeWidget.saveWidgetData<String>('days_left', daysLeft);
      await HomeWidget.saveWidgetData<int>('current_index', currentIndex);
      await HomeWidget.saveWidgetData<int>('total_count', examList.length);

      // 위젯 업데이트 트리거
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: 'ExamWidget',
        iOSName: 'ExamWidget',
      );

      print('Carousel 위젯 업데이트 성공: ${currentExam.department} ($currentIndex/${examList.length})');
    } catch (e) {
      print('Carousel 위젯 업데이트 실패: $e');
    }
  }

  /// 위젯 데이터 초기화
  static Future<void> _clearWidgetData() async {
    try {
      await HomeWidget.saveWidgetData<String>('carousel_data', '');
      await HomeWidget.saveWidgetData<String>('exam_title', '등록된 시험이 없습니다');
      await HomeWidget.saveWidgetData<String>('exam_university', '');
      await HomeWidget.saveWidgetData<String>('exam_date', '');
      await HomeWidget.saveWidgetData<String>('exam_time', '');
      await HomeWidget.saveWidgetData<String>('exam_room', '');
      await HomeWidget.saveWidgetData<String>('days_left', '');
      await HomeWidget.saveWidgetData<int>('current_index', 0);
      await HomeWidget.saveWidgetData<int>('total_count', 0);

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

  /// Carousel 다음 아이템으로 이동
  static Future<void> navigateNext() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList('selectedSchedules') ?? [];
      if (jsonList.isEmpty) return;

      final schedules = jsonList.map((e) => ExamSchedule.fromMap(jsonDecode(e))).toList();
      final upcomingExams = schedules
          .where((exam) => exam.examDateTime.isAfter(DateTime.now()))
          .toList();

      if (upcomingExams.isEmpty) return;

      final currentIndex = await _getCurrentCarouselIndex();
      final nextIndex = (currentIndex + 1) % upcomingExams.length;
      
      await _saveCurrentCarouselIndex(nextIndex);
      await _updateCarouselWidgetData(upcomingExams, nextIndex);
    } catch (e) {
      print('Carousel 다음 이동 실패: $e');
    }
  }

  /// Carousel 이전 아이템으로 이동
  static Future<void> navigatePrevious() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList('selectedSchedules') ?? [];
      if (jsonList.isEmpty) return;

      final schedules = jsonList.map((e) => ExamSchedule.fromMap(jsonDecode(e))).toList();
      final upcomingExams = schedules
          .where((exam) => exam.examDateTime.isAfter(DateTime.now()))
          .toList();

      if (upcomingExams.isEmpty) return;

      final currentIndex = await _getCurrentCarouselIndex();
      final previousIndex = currentIndex == 0 ? upcomingExams.length - 1 : currentIndex - 1;
      
      await _saveCurrentCarouselIndex(previousIndex);
      await _updateCarouselWidgetData(upcomingExams, previousIndex);
    } catch (e) {
      print('Carousel 이전 이동 실패: $e');
    }
  }

  /// 현재 Carousel 인덱스 가져오기
  static Future<int> _getCurrentCarouselIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_carouselIndexKey) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// 현재 Carousel 인덱스 저장하기
  static Future<void> _saveCurrentCarouselIndex(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_carouselIndexKey, index);
    } catch (e) {
      print('Carousel 인덱스 저장 실패: $e');
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
