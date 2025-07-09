import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aim_nonsul/models/exam_schedule.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<ExamSchedule>> fetchAllSchedules() async {
    final snapshot = await _db.collection('examSchedules').get();
    return snapshot.docs.map((doc) => ExamSchedule.fromFirestore(doc)).toList();
  }
}
