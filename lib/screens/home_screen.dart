import 'package:flutter/material.dart';
import 'package:aim_nonsul/models/exam_schedule.dart';
import 'package:aim_nonsul/screens/add_exam_screen.dart';
import 'package:aim_nonsul/services/local_schedule_service.dart';
import 'package:aim_nonsul/services/widget_service.dart';
import 'package:aim_nonsul/theme/app_theme.dart';
import 'package:aim_nonsul/utils/conflict_util.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ExamSchedule> selectedSchedules = [];
  List<ExamSchedule> conflictingSchedules = [];
  final LocalScheduleService _localService = LocalScheduleService();

  @override
  void initState() {
    super.initState();
    loadSelected();
  }

  Future<void> loadSelected() async {
    final list = await _localService.loadSelectedSchedules();

    // 고정 수능 일정 생성
    final suneungExam = ExamSchedule(
      id: -1, // 고정 아이템을 위한 특별한 ID
      university: '대학수학능력시험',
      department: '수능',
      category: '수능',
      examDateTime: DateTime(2025, 11, 13),
      isPrimary: false,
    );

    // 수능을 맨 앞에 추가
    final allSchedules = [suneungExam, ...list];

    allSchedules.sort((a, b) {
      // 수능은 항상 맨 앞에
      if (a.id == -1) return -1;
      if (b.id == -1) return 1;

      int dateComparison = a.examDateTime.compareTo(b.examDateTime);
      if (dateComparison != 0) return dateComparison;

      int universityComparison = a.university.compareTo(b.university);
      if (universityComparison != 0) return universityComparison;

      return a.category.compareTo(b.category);
    });

    final conflicts = getConflictingSchedulesInList(allSchedules);
    setState(() {
      selectedSchedules = allSchedules;
      conflictingSchedules = conflicts;
    });

    await WidgetService.updateWidget(list); // 위젯 업데이트는 원래 리스트만 사용
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
      body: Stack(
        children: [
          Column(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "수능・논술 D-Day",
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
              Expanded(child: _buildScheduleList()),
            ],
          ),
          // Powered by AIM 로고
          Positioned(
            bottom: 20,
            left: 20,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "powered by ",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Image.asset('assets/aim_logo.png', height: 22),
              ],
            ),
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
        final isFixedSuneung = item.id == -1; // 고정 수능인지 확인

        // 고정 수능의 경우 Dismissible 없이 일반 Container로 반환
        if (isFixedSuneung) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 학과 정보
                      Expanded(
                        child: Text(
                          item.department,
                          style: AppTheme.headingSmall.copyWith(
                            fontSize: 22,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      // D-Day
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Text(
                          dDay,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 28,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // const SizedBox(height: 6),

                  /// 시험일자
                  Row(
                    children: [
                      Text(
                        formatDate(item.examDateTime),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

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
              // 수능이 아닌 경우에만 삭제 (수능은 index 0이므로 index-1로 조정)
              await removeSelectedSchedule(index - 1);
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
                        ? AppTheme.warningColor.withValues(alpha: 0.2)
                        : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      // 학교/학과 정보 영역
                      Padding(
                        padding: const EdgeInsets.only(
                          right: 110,
                        ), // D-Day 영역만큼 여백 (더 넓게)
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (conflictingSchedules.contains(item))
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: 8,
                                  top: 2,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.warning_amber_rounded,
                                    size: 16,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
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
                                      Expanded(
                                        child: Text(
                                          item.department,
                                          style: AppTheme.headingSmall.copyWith(
                                            fontSize: 18,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.visible,
                                          softWrap: true,
                                        ),
                                      ),
                                      if (item.isPrimary)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 6,
                                          ),
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
                          ],
                        ),
                      ),

                      // D-Day 뱃지 (오른쪽 고정)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
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
