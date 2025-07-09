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
  String searchQuery = "";
  final LocalScheduleService _localService = LocalScheduleService();
  Map<String, bool> expandedDates = {};

  Map<String, List<ExamSchedule>> get groupedSchedules {
    final grouped = <String, List<ExamSchedule>>{};
    for (final schedule in filteredSchedules) {
      final dateKey = _formatDateTime(schedule.examDateTime);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(schedule);
    }
    return grouped;
  }

  @override
  void initState() {
    super.initState();
    loadSchedules();
  }

  void _expandAllDates() {
    setState(() {
      for (final dateKey in groupedSchedules.keys) {
        expandedDates[dateKey] = true;
      }
    });
  }

  Future<void> loadSchedules() async {
    final data = await FirestoreService().fetchAllSchedules();
    setState(() {
      allSchedules = data;
      filteredSchedules = data;
      sortByDate();
      _expandAllDates();
    });
  }

  void sortByDate() {
    filteredSchedules.sort((a, b) => a.examDateTime.compareTo(b.examDateTime));
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
      sortByDate();
      _expandAllDates();
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
                filteredSchedules.isEmpty
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
                      itemCount: groupedSchedules.length,
                      itemBuilder: (context, index) {
                        final dateKey = groupedSchedules.keys.elementAt(index);
                        final schedules = groupedSchedules[dateKey]!;
                        final isExpanded = expandedDates[dateKey] ?? false;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    expandedDates[dateKey] = !isExpanded;
                                  });
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDateKorean(dateKey),
                                        style: AppTheme.bodyLarge.copyWith(
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryColor
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '${schedules.length}',
                                              style: AppTheme.bodyMedium
                                                  .copyWith(
                                                    color:
                                                        AppTheme.primaryColor,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            isExpanded
                                                ? Icons.expand_less
                                                : Icons.expand_more,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (isExpanded)
                                ...schedules
                                    .map(
                                      (schedule) => Container(
                                        margin: const EdgeInsets.fromLTRB(
                                          16,
                                          0,
                                          16,
                                          12,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: AppTheme.cardGradient,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          boxShadow: AppTheme.lightShadow,
                                        ),
                                        child: ListTile(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 12,
                                              ),
                                          title: Text(
                                            "${schedule.university} ${schedule.department}",
                                            style: AppTheme.bodyLarge.copyWith(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                          subtitle: Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.access_time,
                                                  size: 15,
                                                  color: AppTheme.textSecondary,
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  _formatTimeKorean(
                                                    schedule.examDateTime,
                                                  ),
                                                  style: AppTheme.bodyLarge
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            AppTheme
                                                                .textSecondary,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          trailing: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              gradient:
                                                  AppTheme.primaryGradient,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.add,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                          onTap: () => onScheduleTap(schedule),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              if (isExpanded) const SizedBox(height: 4),
                            ],
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

  String _formatTime(DateTime dateTime) {
    return "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  String _formatDateKorean(String dateString) {
    final parts = dateString.split('.');
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);
    return '${month}월 ${day}일';
  }

  String _formatTimeKorean(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour < 12 ? '오전' : '오후';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final minuteStr = minute == 0 ? '' : ' ${minute}분';
    return '$period ${displayHour}시$minuteStr';
  }
}
