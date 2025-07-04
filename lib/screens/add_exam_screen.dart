import 'package:flutter/material.dart';
import 'package:aim_nonsul/models/exam_schedule.dart';
import 'package:aim_nonsul/services/firestore_service.dart';
import 'package:aim_nonsul/services/local_schedule_service.dart';
import 'package:aim_nonsul/utils/conflict_util.dart';

class AddExamScreen extends StatefulWidget {
  const AddExamScreen({Key? key}) : super(key: key);

  @override
  State<AddExamScreen> createState() => _AddExamScreenState();
}

class _AddExamScreenState extends State<AddExamScreen> {
  List<ExamSchedule> allSchedules = [];
  List<ExamSchedule> filteredSchedules = [];
  Map<String, List<ExamSchedule>> grouped = {};
  String searchQuery = "";
  final LocalScheduleService _localService = LocalScheduleService();

  @override
  void initState() {
    super.initState();
    loadSchedules();
  }

  Future<void> loadSchedules() async {
    final data = await FirestoreService().fetchAllSchedules();
    setState(() {
      allSchedules = data;
      filteredSchedules = data;
      groupByUniversity();
    });
  }

  void groupByUniversity() {
    grouped.clear();
    for (final item in filteredSchedules) {
      grouped.putIfAbsent(item.university, () => []).add(item);
    }
  }

  void onSearchChanged(String query) {
    searchQuery = query.toLowerCase();
    setState(() {
      filteredSchedules =
          allSchedules
              .where(
                (s) =>
                    s.university.toLowerCase().contains(searchQuery) ||
                    s.department.toLowerCase().contains(searchQuery),
              )
              .toList();
      groupByUniversity();
    });
  }

  Future<void> onScheduleTap(ExamSchedule selected) async {
    final existing = await _localService.loadSelectedSchedules();

    // 최대 6개 제한 확인
    if (existing.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❗ 최대 6개까지만 추가할 수 있습니다."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (isDateConflict(existing, selected)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "❗ ${selected.university} ${selected.department}와 일정이 겹칩니다.",
          ),
        ),
      );
      return;
    }

    await _localService.saveSelectedSchedule(selected);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("✅ 저장 완료: ${selected.university} ${selected.department}"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("모집단위 추가")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: "학교명 또는 모집단위명 검색",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child:
                grouped.isEmpty
                    ? Center(child: CircularProgressIndicator())
                    : ListView(
                      children:
                          grouped.entries.map((entry) {
                            return ExpansionTile(
                              title: Text(entry.key),
                              children:
                                  entry.value.map((schedule) {
                                    return ListTile(
                                      title: Text(schedule.department),
                                      subtitle: Text(
                                        "시험일: ${schedule.examDateTime.toLocal()}",
                                      ),
                                      onTap: () => onScheduleTap(schedule),
                                    );
                                  }).toList(),
                            );
                          }).toList(),
                    ),
          ),
        ],
      ),
    );
  }
}
