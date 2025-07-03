import 'package:shared_preferences/shared_preferences.dart';
import 'package:aim_nonsul/models/exam_schedule.dart';
import 'dart:convert';

Future<void> saveSelectedSchedule(ExamSchedule schedule) async {
  final prefs = await SharedPreferences.getInstance();
  final jsonList = prefs.getStringList('selectedSchedules') ?? [];
  jsonList.add(jsonEncode(schedule.toMap()));
  await prefs.setStringList('selectedSchedules', jsonList);
}
