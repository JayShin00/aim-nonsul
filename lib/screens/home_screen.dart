import 'package:flutter/material.dart';
import 'package:aim_nonsul/models/exam_schedule.dart';
import 'package:aim_nonsul/screens/add_exam_screen.dart';
import 'package:aim_nonsul/services/local_schedule_service.dart';
import 'package:aim_nonsul/theme/app_theme.dart';
import 'package:aim_nonsul/utils/conflict_util.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ExamSchedule> selectedSchedules = [];
  List<ExamSchedule> conflictingSchedules = [];
  final LocalScheduleService _localService = LocalScheduleService();
  bool _isNoticeExpanded = false;

  @override
  void initState() {
    super.initState();
    loadSelected();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final isFirst = await _localService.isFirstLaunch();
    if (isFirst) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showDisclaimerDialog();
      });
    }
  }

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'admin@aimscore.ai',
      query: '?subject=AIM 논술 D-Day 앱 문의',
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이메일 앱을 열 수 없습니다')));
    }
  }

  Future<void> _openExternalUrl(String url) async {
    final Uri primary = Uri.parse(url);
    bool opened = false;
    try {
      opened = await launchUrl(primary, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }

    if (!opened) {
      try {
        opened = await launchUrl(primary, mode: LaunchMode.inAppBrowserView);
      } catch (_) {
        opened = false;
      }
    }

    if (!opened) {
      final String withWww = url.contains('://www.')
          ? url
          : url.replaceFirst('://', '://www.');
      final Uri fallback = Uri.parse(withWww);
      try {
        opened = await launchUrl(fallback, mode: LaunchMode.externalApplication);
      } catch (_) {
        opened = false;
      }
    }

    if (!opened) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('링크를 열 수 없습니다')));
      }
    }
  }

  Widget _buildNoticeContent() {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          height: 1.5,
          color: Colors.black87,
          fontSize: 14,
        ),
        children: [
          const TextSpan(
            text:
            '본 앱의 일정 정보는 참고용으로 제공되며,\n급작스러운 변동이나 공식 발표에 따라 실제 일정과 다를 수 있습니다.\n정확한 정보는 해당 기관의 공식 발표를 확인해 주시기 바랍니다.\n\n정보 수정이나 문의: ',
          ),
          WidgetSpan(
            child: GestureDetector(
              onTap: _launchEmail,
              child: const Text(
                'admin@aimscore.ai',
                style: TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDisclaimerDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // 배경 터치로 닫기 비활성화
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Text('안내사항'),
            ],
          ),
          content: _buildNoticeContent(),
          actions: [
            TextButton(
              onPressed: () async {
                await _localService.setFirstLaunchComplete();
                Navigator.of(context).pop();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  Future<void> loadSelected() async {
    final allSchedules =
    await _localService.loadSelectedSchedules(); // 수능 포함된 전체 스케줄

    final conflicts = getConflictingSchedulesInList(allSchedules);
    setState(() {
      selectedSchedules = allSchedules;
      conflictingSchedules = conflicts;
    });

    // 위젯 업데이트 (수능 포함된 전체 스케줄로)
    await _localService.updateWidgets(allSchedules);
  }

  Future<void> removeSelectedSchedule(int id) async {
    await _localService.removeSelectedSchedule(id);
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
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: "수능・논술 ",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w900,
                              fontSize: 24,
                              color: AppTheme.textPrimary,
                              letterSpacing: 0,
                            ),
                          ),
                          // 영어 + D-Day 부분 (기본 굵기)
                          TextSpan(
                            text: "D-Day",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700, // 기본 굵기
                              fontSize: 24,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(child: _buildScheduleList()),
            ],
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: _buildBanner(),
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

  Widget _buildNoticeAccordion() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isNoticeExpanded = !_isNoticeExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '안내사항',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Icon(
                    _isNoticeExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          if (_isNoticeExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _buildNoticeContent(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return InkWell(
      onTap: () => _openExternalUrl('https://aimscore.ai'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 1080 / 314,
          child: Image.asset(
            'assets/aim_banner.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFF7F7F8),
                      Color(0xFFEDE7EA),
                    ],
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.centerRight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '논술 보러 갈까? 말까?',
                      style: AppTheme.headingSmall.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '나의 9월 모의고사 성적으로 바로 알아보기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleList() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 0, left: 20, right: 20, bottom: 20),
      itemCount:
      selectedSchedules.length +
          2, // +2 for notice accordion and powered by
      itemBuilder: (context, index) {
        // 마지막에서 두 번째 아이템은 안내사항 아코디언
        if (index == selectedSchedules.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _buildNoticeAccordion(),
          );
        }
        // 마지막 아이템은 powered by 로고
        if (index == selectedSchedules.length + 1) {
          return Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
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
          );
        }
        final item = selectedSchedules[index];
        final dDay = calculateDDay(item.examDateTime);
        final dDayColor = getDDayColor(dDay);
        final isSuneung = item.id == -1; // 수능인지 확인

        return Dismissible(
          key: Key(item.id.toString()),
          direction: DismissDirection.horizontal,
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.endToStart) {
              if (isSuneung) {
                // 수능은 삭제 불가
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('수능 일정은 삭제할 수 없습니다')),
                );
                return false;
              }
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
              // 고정/고정해제 (수능 포함)
              if (item.isPrimary) {
                await _localService.unsetPrimarySchedule(item.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${item.department} 고정을 해제했습니다')),
                );
              } else {
                await _localService.setPrimarySchedule(item.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${item.university} ${item.department}을 고정했습니다',
                    ),
                  ),
                );
              }
              loadSelected();
              return false;
            }
            return false;
          },
          onDismissed: (direction) async {
            if (direction == DismissDirection.endToStart && !isSuneung) {
              // 수능이 아닌 경우에만 삭제 가능
              await removeSelectedSchedule(item.id);
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
              color: isSuneung ? Colors.grey : AppTheme.errorColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSuneung ? Icons.block : Icons.delete_outline,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(height: 4),
                Text(
                  isSuneung ? "삭제불가" : "삭제",
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
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isSuneung ? AppTheme.primaryColor : Colors.white,
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
                                      color:
                                      isSuneung
                                          ? Colors.white
                                          : AppTheme.textSecondary,
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
                                            color:
                                            isSuneung
                                                ? Colors.white
                                                : AppTheme.textPrimary,
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
                            style: TextStyle(
                              color:
                              isSuneung
                                  ? Colors.white
                                  : AppTheme.primaryColor,
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color:
                          isSuneung ? Colors.white : AppTheme.textSecondary,
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