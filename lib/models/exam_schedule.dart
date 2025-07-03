import 'package:cloud_firestore/cloud_firestore.dart';

class ExamSchedule {
  final int id;
  final String university;
  final String department;
  final String address;
  final DateTime examTimestamp;

  ExamSchedule({
    required this.id,
    required this.university,
    required this.department,
    required this.address,
    required this.examTimestamp,
  });

  factory ExamSchedule.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExamSchedule(
      id: data['id'],
      university: data['university'],
      department: data['department'],
      address: data['address'],
      examTimestamp: (data['examTimestamp'] as Timestamp).toDate(),
    );
  }
}
