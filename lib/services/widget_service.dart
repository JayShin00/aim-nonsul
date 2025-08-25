import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exam_schedule.dart';

class WidgetService {
  static const String _widgetName = 'ExamWidget';
  static const String _carouselIndexKey = 'carousel_index';

  /// 위젯 업데이트 (Carousel 지원)
  static Future<void> updateWidget(List<ExamSchedule> examList) async {
    try {
      print('WidgetService.updateWidget 호출됨: ${examList.length}개 시험');
      
      if (examList.isEmpty) {
        print('시험 목록이 비어있어 위젯 데이터를 초기화합니다');
        await _clearWidgetData();
        return;
      }
      
      // 미래 시험만 필터링
      final upcomingExams = examList
          .where((exam) => exam.examDateTime.isAfter(DateTime.now()))
          .toList();

      print('미래 시험 ${upcomingExams.length}개 필터링됨');

      if (upcomingExams.isEmpty) {
        print('미래 시험이 없어 위젯 데이터를 초기화합니다');
        await _clearWidgetData();
        return;
      }

      // 현재 carousel index 가져오기 및 유효성 검증
      final currentIndex = await _getCurrentCarouselIndex();
      final validIndex = (currentIndex >= 0 && currentIndex < upcomingExams.length) 
          ? currentIndex 
          : 0;
      
      print('현재 인덱스: $currentIndex -> 유효한 인덱스: $validIndex');
      
      // carousel index 저장
      await _saveCurrentCarouselIndex(validIndex);
      
      // 전체 시험 목록과 현재 인덱스로 위젯 업데이트
      await _updateCarouselWidgetData(upcomingExams, validIndex);
      
      // Android 위젯을 위한 추가 데이터 저장 (Android 네이티브 위젯이 읽을 수 있도록)
      await _saveAndroidWidgetData(upcomingExams, validIndex);
      
      print('WidgetService.updateWidget 완료');
    } catch (e) {
      print('위젯 업데이트 중 오류 발생: $e');
      // 오류 발생 시 기본 데이터로 초기화
      await _clearWidgetData();
    }
  }

  /// Carousel 위젯 데이터 업데이트
  static Future<void> _updateCarouselWidgetData(List<ExamSchedule> examList, int currentIndex) async {
    try {
      // 데이터 유효성 검증
      if (examList.isEmpty || currentIndex < 0 || currentIndex >= examList.length) {
        throw ArgumentError('Invalid exam list or current index');
      }
      
      // 전체 시험 목록을 JSON으로 변환 (데이터 검증 포함)
      final examListData = examList.map((exam) => {
        'university': exam.university.isNotEmpty ? exam.university : '대학명 없음',
        'department': exam.department.isNotEmpty ? exam.department : '학과명 없음',
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

      // 위젯 업데이트 트리거 (기존 XML 위젯과 새로운 Glance 위젯 모두 업데이트)
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: 'ExamWidget',
        iOSName: 'ExamWidget',
        qualifiedAndroidName: 'com.aim.aim_nonsul.ExamWidget',
      );
      

      print('Carousel 위젯 업데이트 성공: ${currentExam.department} ($currentIndex/${examList.length})');
    } catch (e) {
      print('Carousel 위젯 업데이트 실패: $e');
    }
  }

  /// Android 위젯 데이터 저장 (네이티브 위젯이 읽을 수 있도록)
  static Future<void> _saveAndroidWidgetData(List<ExamSchedule> examList, int currentIndex) async {
    try {
      print('Android 위젯 데이터 저장 시작');
      
      // JSON으로 시험 목록 변환
      final examListData = examList.map((exam) => {
        'university': exam.university.isNotEmpty ? exam.university : '대학명 없음',
        'department': exam.department.isNotEmpty ? exam.department : '학과명 없음',
        'category': exam.category,
        'examDateTime': exam.examDateTime.toIso8601String(),
        'isPrimary': exam.isPrimary,
        'id': exam.id,
      }).toList();
      
      final jsonString = jsonEncode(examListData);
      
      // Flutter SharedPreferences를 통해 Android 위젯이 접근할 수 있는 키에 저장
      // Android 위젯은 flutter.flutter.flutter.selectedSchedules 키로 읽음
      await HomeWidget.saveWidgetData<String>('flutter.selectedSchedules', jsonString);
      await HomeWidget.saveWidgetData<int>('current_index', currentIndex);
      await HomeWidget.saveWidgetData<int>('total_count', examList.length);
      
      print('Android 위젯 데이터 저장 완료: ${examList.length}개 시험, 현재 인덱스: $currentIndex');
    } catch (e) {
      print('Android 위젯 데이터 저장 실패: $e');
    }
  }

  /// 위젯 데이터 초기화
  static Future<void> _clearWidgetData() async {
    try {
      print('위젯 데이터 초기화 시작');
      
      // iOS 위젯 데이터 초기화
      await HomeWidget.saveWidgetData<String>('carousel_data', '');
      await HomeWidget.saveWidgetData<String>('exam_title', '등록된 시험이 없습니다');
      await HomeWidget.saveWidgetData<String>('exam_university', '');
      await HomeWidget.saveWidgetData<String>('exam_date', '');
      await HomeWidget.saveWidgetData<String>('exam_time', '');
      await HomeWidget.saveWidgetData<String>('exam_room', '');
      await HomeWidget.saveWidgetData<String>('days_left', '');
      await HomeWidget.saveWidgetData<int>('current_index', 0);
      await HomeWidget.saveWidgetData<int>('total_count', 0);
      
      // Android 위젯 데이터 초기화
      await HomeWidget.saveWidgetData<String>('flutter.selectedSchedules', '[]');

      // 위젯 업데이트 트리거 (기존 XML 위젯과 새로운 Glance 위젯 모두 업데이트)
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: 'ExamWidget',
        iOSName: 'ExamWidget',
        qualifiedAndroidName: 'com.aim.aim_nonsul.ExamWidget',
      );
      
      
      print('위젯 데이터 초기화 완료');
    } catch (e) {
      print('위젯 데이터 초기화 실패: $e');
    }
  }

  /// Carousel 다음 아이템으로 이동
  static Future<void> navigateNext() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList('selectedSchedules') ?? [];
      if (jsonList.isEmpty) {
        print('선택된 일정이 없어 네비게이션할 수 없습니다');
        return;
      }

      final schedules = jsonList.map((e) => ExamSchedule.fromMap(jsonDecode(e))).toList();
      final upcomingExams = schedules
          .where((exam) => exam.examDateTime.isAfter(DateTime.now()))
          .toList();

      if (upcomingExams.isEmpty) {
        print('다가오는 시험이 없어 네비게이션할 수 없습니다');
        return;
      }
      
      if (upcomingExams.length == 1) {
        print('시험이 하나뿐이어서 네비게이션할 수 없습니다');
        return;
      }

      final currentIndex = await _getCurrentCarouselIndex();
      // 인덱스 유효성 검증
      final validCurrentIndex = (currentIndex >= 0 && currentIndex < upcomingExams.length) 
          ? currentIndex 
          : 0;
      final nextIndex = (validCurrentIndex + 1) % upcomingExams.length;
      
      await _saveCurrentCarouselIndex(nextIndex);
      await _updateCarouselWidgetData(upcomingExams, nextIndex);
      print('Carousel 다음 이동 성공: $validCurrentIndex -> $nextIndex');
    } catch (e) {
      print('Carousel 다음 이동 실패: $e');
      // 오류 시 전체 위젯 다시 로드 시도
      await _reloadWidgetFromPreferences();
    }
  }

  /// Carousel 이전 아이템으로 이동
  static Future<void> navigatePrevious() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList('selectedSchedules') ?? [];
      if (jsonList.isEmpty) {
        print('선택된 일정이 없어 네비게이션할 수 없습니다');
        return;
      }

      final schedules = jsonList.map((e) => ExamSchedule.fromMap(jsonDecode(e))).toList();
      final upcomingExams = schedules
          .where((exam) => exam.examDateTime.isAfter(DateTime.now()))
          .toList();

      if (upcomingExams.isEmpty) {
        print('다가오는 시험이 없어 네비게이션할 수 없습니다');
        return;
      }
      
      if (upcomingExams.length == 1) {
        print('시험이 하나뿐이어서 네비게이션할 수 없습니다');
        return;
      }

      final currentIndex = await _getCurrentCarouselIndex();
      // 인덱스 유효성 검증
      final validCurrentIndex = (currentIndex >= 0 && currentIndex < upcomingExams.length) 
          ? currentIndex 
          : 0;
      final previousIndex = validCurrentIndex == 0 ? upcomingExams.length - 1 : validCurrentIndex - 1;
      
      await _saveCurrentCarouselIndex(previousIndex);
      await _updateCarouselWidgetData(upcomingExams, previousIndex);
      print('Carousel 이전 이동 성공: $validCurrentIndex -> $previousIndex');
    } catch (e) {
      print('Carousel 이전 이동 실패: $e');
      // 오류 시 전체 위젯 다시 로드 시도
      await _reloadWidgetFromPreferences();
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

  /// SharedPreferences에서 데이터를 다시 로드하여 위젯 업데이트
  static Future<void> _reloadWidgetFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList('selectedSchedules') ?? [];
      
      if (jsonList.isEmpty) {
        await _clearWidgetData();
        return;
      }
      
      final schedules = jsonList.map((e) => ExamSchedule.fromMap(jsonDecode(e))).toList();
      await updateWidget(schedules);
      print('SharedPreferences에서 위젯 데이터 재로드 완료');
    } catch (e) {
      print('위젯 데이터 재로드 실패: $e');
      await _clearWidgetData();
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
