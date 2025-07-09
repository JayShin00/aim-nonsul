import 'package:flutter/material.dart';
import 'package:aim_nonsul/models/exam_schedule.dart';
import 'package:aim_nonsul/services/firestore_service.dart';
import 'package:aim_nonsul/services/local_schedule_service.dart';
import 'package:aim_nonsul/utils/conflict_util.dart';
import 'package:aim_nonsul/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

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
    if (existing.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
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
        content: Text("${selected.university} ${selected.department} 추가 완료!"),
      ),
    );
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
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 26,
                      color: AppTheme.textPrimary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),

                    style: IconButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                      minimumSize: Size(36, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "모집단위 추가",
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.cardShadow,
            ),
            child: TextField(
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: "학교명 또는 모집단위명 검색",
                hintStyle: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textLight,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(Icons.search, color: AppTheme.primaryColor),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              style: AppTheme.bodyLarge,
            ),
          ),
          Expanded(
            child:
                grouped.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              shape: BoxShape.circle,
                              boxShadow: AppTheme.lightShadow,
                            ),
                            child: const Icon(
                              Icons.search,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            "모집단위를 검색하고 있습니다...",
                            style: AppTheme.bodyLarge.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: grouped.entries.length,
                      itemBuilder: (context, index) {
                        final entry = grouped.entries.elementAt(index);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            gradient: AppTheme.cardGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: ExpansionTile(
                            title: Text(
                              entry.key,
                              style: AppTheme.headingSmall,
                            ),
                            iconColor: AppTheme.primaryColor,
                            collapsedIconColor: AppTheme.textSecondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            collapsedShape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            children:
                                entry.value.map((schedule) {
                                  return Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                      title: Text(
                                        schedule.department,
                                        style: AppTheme.bodyLarge,
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.calendar_today,
                                              size: 16,
                                              color: AppTheme.textSecondary,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              "시험일: ${_formatDateTime(schedule.examDateTime)}",
                                              style: AppTheme.bodyMedium,
                                            ),
                                          ],
                                        ),
                                      ),
                                      trailing: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          gradient: AppTheme.primaryGradient,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.add,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      onTap: () => onScheduleTap(schedule),
                                    ),
                                  );
                                }).toList(),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return "${dateTime.year}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.day.toString().padLeft(2, '0')}";
  }
}
