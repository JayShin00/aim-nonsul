import 'package:cloud_firestore/cloud_firestore.dart';

class ExamSchedule {
  final int id;
  final String university;
  final String category;
  final String department;
  final DateTime examDateTime;
  final bool isPrimary;
  final String notification;

  ExamSchedule({
    required this.id,
    required this.university,
    required this.category,
    required this.department,
    required this.examDateTime,
    this.isPrimary = false,
    this.notification = '',
  });

  factory ExamSchedule.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExamSchedule(
      id: data['id'],
      university: data['university'],
      category: data['category'],
      department: data['department'],
      examDateTime: (data['examDateTime'] as Timestamp).toDate(),
      isPrimary: data['isPrimary'] ?? false,
      notification: data['notification'] ?? '',
    );
  }

  // toMap() → SharedPreferences용
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'university': university,
      'category': category,
      'department': department,
      'examDateTime': examDateTime.toIso8601String(),
      'isPrimary': isPrimary,
      'notification': notification,
    };
  }

  // fromMap() → SharedPreferences에서 복원
  factory ExamSchedule.fromMap(Map<String, dynamic> map) {
    return ExamSchedule(
      id: map['id'],
      university: map['university'],
      category: map['category'] ?? '기타',
      department: map['department'],
      examDateTime: DateTime.parse(map['examDateTime']),
      isPrimary: map['isPrimary'] ?? false,
      notification: map['notification'] ?? '',
    );
  }
}
