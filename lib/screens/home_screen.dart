import 'package:flutter/material.dart';
import 'package:aim_nonsul/models/exam_schedule.dart';
import 'package:aim_nonsul/screens/add_exam_screen.dart';
import 'package:aim_nonsul/services/local_schedule_service.dart';
import 'package:aim_nonsul/services/widget_service.dart';
import 'package:aim_nonsul/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

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
    list.sort((a, b) => a.examDateTime.compareTo(b.examDateTime));
    setState(() {
      selectedSchedules = list;
    });

    await WidgetService.updateWidget(list);
  }

  Future<void> removeSelectedSchedule(int index) async {
    await _localService.removeSelectedSchedule(index);
    loadSelected();
  }

  String calculateDDay(DateTime examDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final examDay = DateTime(examDate.year, examDate.month, examDate.day);
    final difference = examDay.difference(today).inDays;
    if (difference == 0) return "D-Day";
    if (difference > 0) return "D-$difference";
    return "종료";
  }

  Color getDDayColor(String dDay) {
    if (dDay == "D-Day") return AppTheme.errorColor;
    if (dDay == "종료") return AppTheme.textLight;
    final days = int.tryParse(dDay.substring(2)) ?? 0;
    if (days <= 7) return AppTheme.errorColor;
    if (days <= 30) return AppTheme.warningColor;
    return AppTheme.primaryColor;
  }

  String formatDate(DateTime dateTime) {
    return "${dateTime.year}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.day.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "AIM D-Day",
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child:
                selectedSchedules.isEmpty
                    ? _buildEmptyState()
                    : _buildScheduleList(),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16, right: 16),
        child: FloatingActionButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddExamScreen()),
            );
            loadSelected();
          },
          backgroundColor: AppTheme.primaryColor,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.add, size: 32, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 60, color: AppTheme.primaryColor),
          const SizedBox(height: 24),
          Text("아직 선택한 모집단위가 없습니다", style: AppTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildScheduleList() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 0, left: 20, right: 20, bottom: 20),
      itemCount: selectedSchedules.length,
      itemBuilder: (context, index) {
        final item = selectedSchedules[index];
        final dDay = calculateDDay(item.examDateTime);
        final dDayColor = getDDayColor(dDay);

        return Dismissible(
          key: Key(item.id.toString()),
          direction: DismissDirection.horizontal,
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.endToStart) {
              return await showDialog<bool>(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('삭제 확인'),
                      content: Text(
                        '${item.university} ${item.department} 일정을 삭제하시겠습니까?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('취소'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text(
                            '삭제',
                            style: TextStyle(color: AppTheme.errorColor),
                          ),
                        ),
                      ],
                    ),
              );
            } else if (direction == DismissDirection.startToEnd) {
              if (item.isPrimary) {
                await _localService.unsetPrimarySchedule(item.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('대표 모집단위 설정을 해제했습니다')),
                );
              } else {
                await _localService.setPrimarySchedule(item.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${item.department}를 대표 모집단위로 설정했습니다'),
                  ),
                );
              }
              loadSelected();
              return false;
            }
            return false;
          },
          onDismissed: (direction) async {
            if (direction == DismissDirection.endToStart) {
              await removeSelectedSchedule(index);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("${item.university} ${item.department} 삭제됨"),
                  action: SnackBarAction(
                    label: "취소",
                    onPressed: () async {
                      await _localService.saveSelectedSchedule(item);
                      loadSelected();
                    },
                  ),
                ),
              );
            }
          },
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            decoration: BoxDecoration(
              color:
                  item.isPrimary
                      ? AppTheme.warningColor
                      : AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item.isPrimary ? Icons.push_pin : Icons.push_pin_outlined,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(height: 4),
                Text(
                  item.isPrimary ? "해제" : "고정",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          secondaryBackground: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: AppTheme.errorColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_outline, color: Colors.white, size: 28),
                SizedBox(height: 4),
                Text(
                  "삭제",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppTheme.cardShadow,
              border: Border.all(
                color:
                    item.isPrimary
                        ? AppTheme.warningColor.withOpacity(0.2)
                        : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.university,
                              style: AppTheme.headingSmall.copyWith(
                                fontSize: 18,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),

                            Row(
                              children: [
                                Text(
                                  item.department,
                                  style: AppTheme.headingSmall.copyWith(
                                    fontSize: 18,
                                  ),
                                ),
                                if (item.isPrimary)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 6),
                                    child: Icon(
                                      Icons.star,
                                      size: 16,
                                      color: AppTheme.warningColor,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      /// D-Day 뱃지
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        // decoration: BoxDecoration(
                        //   color: dDayColor,
                        //   borderRadius: BorderRadius.circular(100),
                        // ),
                        child: Text(
                          dDay,
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 28,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  /// 시험일자
                  Row(
                    children: [
                      Text(
                        formatDate(item.examDateTime),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
