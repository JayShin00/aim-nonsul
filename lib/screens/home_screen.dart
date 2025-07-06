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

    // 위젯 업데이트
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
      return AppTheme.errorColor;
    } else if (dDay == "종료") {
      return AppTheme.textLight;
    } else if (dDay.startsWith("D-")) {
      final days = int.tryParse(dDay.substring(2)) ?? 0;
      if (days <= 7) {
        return AppTheme.errorColor;
      } else if (days <= 30) {
        return AppTheme.warningColor;
      } else {
        return AppTheme.primaryColor;
      }
    }
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
          Container(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: SafeArea(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "AIM 논술 D-Day",
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
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
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddExamScreen()),
            );
            loadSelected();
          },
          icon: const Icon(Icons.add, size: 20),
          label: const Text(
            "모집단위 추가",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: AppTheme.lightShadow,
            ),
            child: const Icon(
              Icons.school_outlined,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            "아직 선택한 모집단위가 없습니다",
            style: AppTheme.headingSmall.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Text("아래 + 버튼을 눌러 모집단위를 추가해보세요", style: AppTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildScheduleList() {
    return Column(
      children: [
        // 상태 표시 바
        Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
              Text(
                "${selectedSchedules.length}/6개 모집단위",
                style: AppTheme.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                "← 고정  삭제 →",
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textLight,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: selectedSchedules.length,
            itemBuilder: (context, index) {
              final item = selectedSchedules[index];
              final dDay = calculateDDay(item.examDateTime);
              final dDayColor = getDDayColor(dDay);

              return Dismissible(
                key: Key(item.id.toString()),
                onDismissed: (direction) async {
                  if (direction == DismissDirection.endToStart) {
                    await removeSelectedSchedule(index);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "${item.university} ${item.department} 삭제됨",
                        ),
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
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.endToStart) {
                    return await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('삭제 확인'),
                            content: Text(
                              '${item.university} ${item.department}를 삭제하시겠습니까?',
                            ),
                            actions: [
                              TextButton(
                                onPressed:
                                    () => Navigator.of(context).pop(false),
                                child: const Text('취소'),
                              ),
                              TextButton(
                                onPressed:
                                    () => Navigator.of(context).pop(true),
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
                secondaryBackground: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor,
                    borderRadius: BorderRadius.circular(16),
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
                background: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 20),
                  decoration: BoxDecoration(
                    color:
                        item.isPrimary
                            ? AppTheme.warningColor
                            : AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.isPrimary
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
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
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
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
                      children: [
                        Row(
                          children: [
                            if (item.isPrimary)
                              Container(
                                margin: const EdgeInsets.only(right: 12),
                                child: const Icon(
                                  Icons.push_pin,
                                  color: AppTheme.warningColor,
                                  size: 20,
                                ),
                              ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.university,
                                    style: AppTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.department,
                                          style: AppTheme.headingSmall,
                                        ),
                                      ),
                                      if (item.isPrimary)
                                        Container(
                                          margin: const EdgeInsets.only(
                                            left: 8,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.warningColor
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            "대표",
                                            style: AppTheme.labelSmall.copyWith(
                                              color: AppTheme.warningColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: dDayColor,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: dDayColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                dDay,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "시험일: ${formatDate(item.examDateTime)}",
                              style: AppTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
