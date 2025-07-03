import 'package:aim_nonsul/models/exam_schedule.dart';

bool isDateConflict(List<ExamSchedule> existing, ExamSchedule newItem) {
  final newDate = DateTime(
    newItem.examTimestamp.year,
    newItem.examTimestamp.month,
    newItem.examTimestamp.day,
  );
  for (final s in existing) {
    final existingDate = DateTime(
      s.examTimestamp.year,
      s.examTimestamp.month,
      s.examTimestamp.day,
    );
    if (existingDate == newDate) return true;
  }
  return false;
}
