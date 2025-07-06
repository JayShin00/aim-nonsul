import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../models/exam_schedule.dart';

class WidgetService {
  static const String _widgetName = 'ExamWidget';

  /// 위젯 업데이트
  static Future<void> updateWidget(List<ExamSchedule> examList) async {
    if (examList.isEmpty) {
      // 시험이 없는 경우
      await _updateWidgetData(
        examTitle: '등록된 시험이 없습니다',
        examDate: '',
        examTime: '',
        examRoom: '',
        daysLeft: '',
      );
    } else {
      // 다음 시험 찾기
      final nextExam = _findNextExam(examList);

      if (nextExam != null) {
        final dateFormat = DateFormat('yyyy-MM-dd');
        final timeFormat = DateFormat('HH:mm');

        final examDate = dateFormat.format(nextExam.examDateTime);
        final examTime = timeFormat.format(nextExam.examDateTime);
        final daysLeft = _calculateDaysLeft(nextExam.examDateTime);

        await _updateWidgetData(
          examTitle: nextExam.department,
          examDate: examDate,
          examTime: examTime,
          examRoom: nextExam.address,
          daysLeft: daysLeft,
        );
      } else {
        // 남은 시험이 없는 경우
        await _updateWidgetData(
          examTitle: '모든 시험이 완료되었습니다',
          examDate: '',
          examTime: '',
          examRoom: '',
          daysLeft: '',
        );
      }
    }
  }

  /// 위젯 데이터 업데이트
  static Future<void> _updateWidgetData({
    required String examTitle,
    required String examDate,
    required String examTime,
    required String examRoom,
    required String daysLeft,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('exam_title', examTitle);
      await HomeWidget.saveWidgetData<String>('exam_date', examDate);
      await HomeWidget.saveWidgetData<String>('exam_time', examTime);
      await HomeWidget.saveWidgetData<String>('exam_room', examRoom);
      await HomeWidget.saveWidgetData<String>('days_left', daysLeft);

      // 위젯 업데이트 트리거
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: 'ExamWidgetProvider',
        iOSName: 'ExamWidget',
      );
    } catch (e) {
      print('위젯 업데이트 실패: $e');
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

  /// D-Day 계산
  static String _calculateDaysLeft(DateTime examDate) {
    final now = DateTime.now();
    final difference = examDate.difference(now).inDays;

    if (difference == 0) {
      return 'D-Day';
    } else if (difference > 0) {
      return 'D-${difference}';
    } else {
      return '종료';
    }
  }
}
