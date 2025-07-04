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
