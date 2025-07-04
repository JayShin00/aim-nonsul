import 'package:cloud_firestore/cloud_firestore.dart';

class ExamSchedule {
  final int id;
  final String university;
  final String department;
  final String address;
  final DateTime examDateTime;

  ExamSchedule({
    required this.id,
    required this.university,
    required this.department,
    required this.address,
    required this.examDateTime,
  });

  factory ExamSchedule.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExamSchedule(
      id: data['id'],
      university: data['university'],
      department: data['department'],
      address: data['address'],
      examDateTime: (data['examDateTime'] as Timestamp).toDate(),
    );
  }

  // toMap() → SharedPreferences용
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'university': university,
      'department': department,
      'address': address,
      'examTimestamp': examDateTime.toIso8601String(),
    };
  }

  // fromMap() → SharedPreferences에서 복원
  factory ExamSchedule.fromMap(Map<String, dynamic> map) {
    return ExamSchedule(
      id: map['id'],
      university: map['university'],
      department: map['department'],
      address: map['address'],
      examDateTime: DateTime.parse(map['examDateTime']),
    );
  }
}
