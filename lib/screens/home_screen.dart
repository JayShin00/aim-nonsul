import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aim_nonsul/models/exam_schedule.dart';
import 'package:aim_nonsul/screens/add_exam_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ExamSchedule> selectedSchedules = [];

  @override
  void initState() {
    super.initState();
    loadSelected();
  }

  Future<void> loadSelected() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList('selectedSchedules') ?? [];
    final list =
        jsonList.map((e) => ExamSchedule.fromMap(jsonDecode(e))).toList();
    setState(() {
      selectedSchedules = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("내가 선택한 모집단위")),
      body: ListView.builder(
        itemCount: selectedSchedules.length,
        itemBuilder: (context, index) {
          final item = selectedSchedules[index];
          return ListTile(
            title: Text("${item.university} ${item.department}"),
            subtitle: Text("시험일: ${item.examDateTime.toLocal()}"),
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // AddExamScreen으로 이동
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddExamScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
