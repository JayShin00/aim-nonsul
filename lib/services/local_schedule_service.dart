import 'package:shared_preferences/shared_preferences.dart';
import 'package:aim_nonsul/models/exam_schedule.dart';
import 'dart:convert';

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
    final jsonList = existing.map((e) => jsonEncode(e.toMap())).toList();
    await prefs.setStringList(_selectedSchedulesKey, jsonList);
  }

  // 특정 인덱스의 일정 삭제하기
  Future<void> removeSelectedSchedule(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadSelectedSchedules();
    if (index >= 0 && index < existing.length) {
      existing.removeAt(index);
      final jsonList = existing.map((e) => jsonEncode(e.toMap())).toList();
      await prefs.setStringList(_selectedSchedulesKey, jsonList);
    }
  }

  // 전체 선택된 일정 목록 저장하기 (덮어쓰기)
  Future<void> saveAllSelectedSchedules(List<ExamSchedule> schedules) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = schedules.map((e) => jsonEncode(e.toMap())).toList();
    await prefs.setStringList(_selectedSchedulesKey, jsonList);
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
  }
}
