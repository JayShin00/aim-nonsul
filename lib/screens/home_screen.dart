import 'package:flutter/material.dart';
import 'package:aim_nonsul/models/exam_schedule.dart';
import 'package:aim_nonsul/screens/add_exam_screen.dart';
import 'package:aim_nonsul/services/local_schedule_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ExamSchedule> selectedSchedules = [];
  final LocalScheduleService _localService = LocalScheduleService();

  @override
  void initState() {
    super.initState();
    loadSelected();
  }

  Future<void> loadSelected() async {
    final list = await _localService.loadSelectedSchedules();

    // 시험일 순으로 정렬
    list.sort((a, b) => a.examDateTime.compareTo(b.examDateTime));

    setState(() {
      selectedSchedules = list;
    });
  }

  Future<void> removeSelectedSchedule(int index) async {
    await _localService.removeSelectedSchedule(index);
    loadSelected(); // 새로고침
  }

  String calculateDDay(DateTime examDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final examDay = DateTime(examDate.year, examDate.month, examDate.day);

    final difference = examDay.difference(today).inDays;

    if (difference == 0) {
      return "D-Day";
    } else if (difference > 0) {
      return "D-$difference";
    } else {
      return "종료";
    }
  }

  Color getDDayColor(String dDay) {
    if (dDay == "D-Day") {
      return Colors.red;
    } else if (dDay == "종료") {
      return Colors.grey;
    } else if (dDay.startsWith("D-")) {
      final days = int.tryParse(dDay.substring(2)) ?? 0;
      if (days <= 7) {
        return Colors.red;
      } else if (days <= 30) {
        return Colors.orange;
      } else {
        return Colors.blue;
      }
    }
    return Colors.blue;
  }

  String formatDate(DateTime dateTime) {
    return "${dateTime.year}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.day.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("내가 선택한 모집단위"),
        backgroundColor: Colors.blue[50],
      ),
      body:
          selectedSchedules.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.school_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 16),
                    Text(
                      "아직 선택한 모집단위가 없습니다",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "아래 + 버튼을 눌러 모집단위를 추가해보세요",
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
              : Column(
                children: [
                  if (selectedSchedules.length > 0)
                    Container(
                      padding: EdgeInsets.all(16),
                      margin: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700]),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "총 ${selectedSchedules.length}/6개 모집단위 • 왼쪽으로 밀어서 삭제",
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      itemCount: selectedSchedules.length,
                      itemBuilder: (context, index) {
                        final item = selectedSchedules[index];
                        final dDay = calculateDDay(item.examDateTime);
                        final dDayColor = getDDayColor(dDay);

                        return Dismissible(
                          key: Key(item.id.toString()),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (direction) async {
                            // 삭제 전에 미리 처리
                            await removeSelectedSchedule(index);

                            // 삭제 완료 메시지 표시
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "${item.university} ${item.department} 삭제됨",
                                ),
                                action: SnackBarAction(
                                  label: "취소",
                                  onPressed: () async {
                                    // 취소 기능: 다시 추가
                                    await _localService.saveSelectedSchedule(
                                      item,
                                    );
                                    loadSelected();
                                  },
                                ),
                              ),
                            );

                            return true; // 삭제 허용
                          },
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Icon(Icons.delete, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  "삭제",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          child: Container(
                            margin: EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.all(16),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.university,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          item.department,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: dDayColor,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      dDay,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      "시험일: ${formatDate(item.examDateTime)}",
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // AddExamScreen으로 이동하고 결과를 기다림
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddExamScreen()),
          );
          // 돌아왔을 때 자동으로 새로고침
          loadSelected();
        },
        icon: Icon(Icons.add),
        label: Text("모집단위 추가"),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
    );
  }
}
