import 'package:aim_nonsul/models/exam_schedule.dart';

bool isDateConflict(List<ExamSchedule> existing, ExamSchedule newItem) {
  final newDate = DateTime(
    newItem.examDateTime.year,
    newItem.examDateTime.month,
    newItem.examDateTime.day,
  );
  for (final s in existing) {
    final existingDate = DateTime(
      s.examDateTime.year,
      s.examDateTime.month,
      s.examDateTime.day,
    );
    if (existingDate == newDate) return true;
  }
  return false;
}

List<ExamSchedule> getConflictingSchedules(List<ExamSchedule> existing, ExamSchedule newItem) {
  final newDate = DateTime(
    newItem.examDateTime.year,
    newItem.examDateTime.month,
    newItem.examDateTime.day,
  );
  return existing.where((s) {
    final existingDate = DateTime(
      s.examDateTime.year,
      s.examDateTime.month,
      s.examDateTime.day,
    );
    return existingDate == newDate;
  }).toList();
}

bool hasConflicts(List<ExamSchedule> schedules) {
  for (int i = 0; i < schedules.length; i++) {
    for (int j = i + 1; j < schedules.length; j++) {
      final date1 = DateTime(
        schedules[i].examDateTime.year,
        schedules[i].examDateTime.month,
        schedules[i].examDateTime.day,
      );
      final date2 = DateTime(
        schedules[j].examDateTime.year,
        schedules[j].examDateTime.month,
        schedules[j].examDateTime.day,
      );
      if (date1 == date2) return true;
    }
  }
  return false;
}

List<ExamSchedule> getConflictingSchedulesInList(List<ExamSchedule> schedules) {
  final conflicts = <ExamSchedule>[];
  for (int i = 0; i < schedules.length; i++) {
    for (int j = i + 1; j < schedules.length; j++) {
      final date1 = DateTime(
        schedules[i].examDateTime.year,
        schedules[i].examDateTime.month,
        schedules[i].examDateTime.day,
      );
      final date2 = DateTime(
        schedules[j].examDateTime.year,
        schedules[j].examDateTime.month,
        schedules[j].examDateTime.day,
      );
      if (date1 == date2) {
        if (!conflicts.contains(schedules[i])) conflicts.add(schedules[i]);
        if (!conflicts.contains(schedules[j])) conflicts.add(schedules[j]);
      }
    }
  }
  return conflicts;
}
