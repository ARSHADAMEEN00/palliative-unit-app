import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/homevisit.dart';
import 'package:oruma_app/home_visit_search_page.dart';
import 'package:oruma_app/models/home_visit.dart';
import 'package:oruma_app/models/patient.dart';
import 'package:oruma_app/services/home_visit_service.dart';
import 'package:oruma_app/services/patient_service.dart';
import 'package:oruma_app/services/config_service.dart';
import 'package:oruma_app/services/feature_permissions.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/widgets/module_theme.dart';
import 'package:oruma_app/features/visit_assessment/presentation/screens/visit_assessment_list_screen.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';
import 'package:oruma_app/widgets/compact_app_bottom_bar.dart';
import 'package:oruma_app/widgets/app_bottom_nav_router.dart';
import 'package:oruma_app/widgets/feature_permission_gate.dart';
import 'package:oruma_app/widgets/reveal_action_fab.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';

const _homeVisitPrimary = AppColors.success;
const _homeVisitIconBackground = Color(0xFFDCFCE7);

class HomeVisitListPage extends StatefulWidget {
  const HomeVisitListPage({super.key});

  @override
  State<HomeVisitListPage> createState() => _HomeVisitListPageState();
}

class _HomeVisitListPageState extends State<HomeVisitListPage> {
  late Future<List<HomeVisit>> _visitsFuture;
  List<HomeVisit> _allVisits = [];

  // Date navigation
  late DateTime _selectedDate;
  late DateTime _startOfWeek;
  late List<DateTime> _weekDates;
  late PageController _pageController;

  // Key to force PageView rebuild
  Key _pageViewKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _initializeWeek();
    _pageController = PageController(initialPage: _getSelectedDateIndex());
    _refreshVisits();
  }

  void _initializeWeek() {
    // Start from 3 days ago to show past visits too
    final now = DateTime.now();
    _startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 3));
    // Generate 14 days (2 weeks view)
    _weekDates = List.generate(14, (i) => _startOfWeek.add(Duration(days: i)));
  }

  int _getSelectedDateIndex() {
    for (int i = 0; i < _weekDates.length; i++) {
      if (_isSameDay(_weekDates[i], _selectedDate)) {
        return i;
      }
    }
    return 3; // Default to "today" position
  }

  bool _isSameDay(DateTime a, DateTime b) {
    // Compare using local timezone (don't convert to UTC as it shifts dates)
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _refreshVisits() {
    setState(() {
      _visitsFuture = HomeVisitService.getAllHomeVisits().then((visits) {
        _allVisits = visits;
        return visits;
      });
    });
  }

  List<HomeVisit> _getVisitsForDate(DateTime date) {
    return _allVisits.where((visit) {
      final visitDate = DateTime.tryParse(visit.visitDate);
      if (visitDate == null) return false;
      return _isSameDay(visitDate, date);
    }).toList();
  }

  int _getVisitCountForDate(DateTime date) {
    return _getVisitsForDate(date).length;
  }

  void _onDateSelected(int index) {
    setState(() {
      _selectedDate = _weekDates[index];
    });
    _pageController.animateToPage(
      index,
      duration: AppMotion.page,
      curve: AppMotion.easeOutCubic,
    );
  }

  void _rebuildPageView(int initialPage) {
    if (!mounted) return;
    try {
      if (!_pageController.hasClients) {
        _pageController.dispose();
      }
    } catch (e) {
      // PageController already disposed, ignore
    }
    _pageController = PageController(initialPage: initialPage);
    _pageViewKey = UniqueKey();
  }

  void _goToPreviousWeek() {
    final currentIndex = _getSelectedDateIndex();
    setState(() {
      _startOfWeek = _startOfWeek.subtract(const Duration(days: 7));
      _weekDates = List.generate(
        14,
        (i) => _startOfWeek.add(Duration(days: i)),
      );
      // Try to maintain same position in week, fallback to day 3
      _selectedDate = _weekDates[currentIndex.clamp(0, _weekDates.length - 1)];
      _rebuildPageView(currentIndex.clamp(0, _weekDates.length - 1));
    });
  }

  void _goToNextWeek() {
    final currentIndex = _getSelectedDateIndex();
    setState(() {
      _startOfWeek = _startOfWeek.add(const Duration(days: 7));
      _weekDates = List.generate(
        14,
        (i) => _startOfWeek.add(Duration(days: i)),
      );
      // Try to maintain same position in week, fallback to day 3
      _selectedDate = _weekDates[currentIndex.clamp(0, _weekDates.length - 1)];
      _rebuildPageView(currentIndex.clamp(0, _weekDates.length - 1));
    });
  }

  void _goToToday() {
    setState(() {
      final now = DateTime.now();
      _startOfWeek = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 3));
      _weekDates = List.generate(
        14,
        (i) => _startOfWeek.add(Duration(days: i)),
      );
      _selectedDate = DateTime.now();
      _rebuildPageView(3);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleBottomNavigation(BuildContext context, AppBottomSection section) {
    AppBottomNavRouter.handle(
      context,
      current: AppBottomSection.homeVisit,
      target: section,
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = _homeVisitPrimary;
    final now = DateTime.now();
    final isToday = _isSameDay(_selectedDate, now);

    return AdaptiveAppScaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: AppSpacing.md,
        title: Text(
          "Home Visits",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        actions: [
          if (!isToday)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: _HomeVisitTodayButton(onPressed: _goToToday),
            ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: _HomeVisitIconButton(
              icon: Icons.search,
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HomeVisitSearchPage(),
                  ),
                );
                _refreshVisits();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: _HomeVisitIconButton(
              icon: Icons.refresh,
              onPressed: _refreshVisits,
            ),
          ),
        ],
      ),
      currentSection: AppBottomSection.homeVisit,
      onNavigationSelected: (section) =>
          _handleBottomNavigation(context, section),
      contentMaxWidth: 860,
      body: FutureBuilder<List<HomeVisit>>(
        future: _visitsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppListSkeleton(itemCount: 5);
          } else if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          return Column(
            children: [
              // Week Navigation Header
              _buildWeekNavigationHeader(primaryColor),

              // Date Tabs
              _buildDateTabs(primaryColor),

              // Visits for Selected Date (PageView for swipe)
              Expanded(
                child: PageView.builder(
                  key: _pageViewKey,
                  controller: _pageController,
                  itemCount: _weekDates.length,
                  onPageChanged: (index) {
                    setState(() {
                      _selectedDate = _weekDates[index];
                    });
                  },
                  itemBuilder: (context, index) {
                    final date = _weekDates[index];
                    final visits = _getVisitsForDate(date);
                    return _buildVisitsList(visits);
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Provider.of<AuthService>(context).canCreate
          ? RevealActionFab(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ModuleTheme(
                      palette: ModulePalettes.homeVisits,
                      child: Homevisit(initialDate: _selectedDate),
                    ),
                  ),
                );
                if (result == true) _refreshVisits();
              },
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              icon: Icons.add,
              label: 'Schedule Visit',
            )
          : null,
    );
  }

  Widget _buildWeekNavigationHeader(Color primaryColor) {
    final monthYear = DateFormat('MMMM yyyy').format(_selectedDate);
    final visitCount = _getVisitCountForDate(_selectedDate);
    final selectedDateLabel = _getSelectedDateLabel();
    final selectedDate = DateFormat('d MMM yyyy').format(_selectedDate);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppInsets.screenHorizontal(context),
        AppSpacing.sm,
        AppInsets.screenHorizontal(context),
        AppSpacing.xxs,
      ),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        surfaceLevel: AppSurfaceLevel.elevated,
        child: Row(
          children: [
            _HomeVisitIconButton(
              icon: Icons.chevron_left,
              onPressed: _goToPreviousWeek,
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    monthYear,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xxs,
                    children: [
                      Text(
                        '$selectedDateLabel, $selectedDate',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      _buildVisitCountChip(visitCount),
                    ],
                  ),
                ],
              ),
            ),
            _HomeVisitIconButton(
              icon: Icons.chevron_right,
              onPressed: _goToNextWeek,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTabs(Color primaryColor) {
    return SizedBox(
      height: 84,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
        itemCount: _weekDates.length,
        itemBuilder: (context, index) {
          final date = _weekDates[index];
          final isSelected = _isSameDay(date, _selectedDate);
          final isToday = _isSameDay(date, DateTime.now());
          final visitCount = _getVisitCountForDate(date);
          final hasVisits = visitCount > 0;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
            child: Material(
              color: Colors.transparent,
              borderRadius: AppRadius.card,
              child: InkWell(
                borderRadius: AppRadius.card,
                onTap: () => _onDateSelected(index),
                child: AnimatedContainer(
                  duration: AppMotion.normal,
                  curve: AppMotion.easeOutCubic,
                  width: 58,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryColor
                        : isToday
                        ? primaryColor.withValues(alpha: 0.1)
                        : AppColors.surface,
                    borderRadius: AppRadius.card,
                    border: isToday && !isSelected
                        ? Border.all(color: primaryColor, width: 2)
                        : Border.all(color: AppColors.border),
                    boxShadow: isSelected ? AppShadow.medium : AppShadow.small,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('EEE').format(date).toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppColors.textInverse.withValues(alpha: 0.82)
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('d').format(date),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? AppColors.textInverse
                              : AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (hasVisits)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.textInverse.withValues(alpha: 0.22)
                                : primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$visitCount',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? AppColors.textInverse
                                  : primaryColor,
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _getSelectedDateLabel() {
    final isToday = _isSameDay(_selectedDate, DateTime.now());
    final isTomorrow = _isSameDay(
      _selectedDate,
      DateTime.now().add(const Duration(days: 1)),
    );
    final isYesterday = _isSameDay(
      _selectedDate,
      DateTime.now().subtract(const Duration(days: 1)),
    );

    if (isToday) {
      return "Today";
    }
    if (isTomorrow) {
      return "Tomorrow";
    }
    if (isYesterday) {
      return "Yesterday";
    }
    return DateFormat('EEEE').format(_selectedDate);
  }

  Widget _buildVisitCountChip(int visitCount) {
    final hasVisits = visitCount > 0;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: hasVisits
            ? _homeVisitPrimary.withValues(alpha: 0.1)
            : AppColors.surface1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.home_work_outlined,
            size: AppIcons.small,
            color: hasVisits ? _homeVisitPrimary : AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            '$visitCount ${visitCount == 1 ? 'visit' : 'visits'}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: hasVisits ? _homeVisitPrimary : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitsList(List<HomeVisit> visits) {
    if (visits.isEmpty) {
      return _buildEmptyDayState();
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        AppInsets.screenHorizontal(context),
        AppSpacing.xs,
        AppInsets.screenHorizontal(context),
        112,
      ),
      itemCount: visits.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final visit = visits[index];
        return _buildVisitCard(context, visit, index + 1);
      },
    );
  }

  Widget _buildVisitCard(
    BuildContext context,
    HomeVisit visit,
    int visitNumber,
  ) {
    final patient = visit.patientDetails;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      surfaceLevel: AppSurfaceLevel.elevated,
      onTap: () => _showVisitDetails(context, visit),
      child: Row(
        children: [
          // Visit Number Badge
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: _homeVisitIconBackground,
              borderRadius: AppRadius.md,
            ),
            child: Center(
              child: Text(
                '#$visitNumber',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: _homeVisitPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Visit Details
          Expanded(
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visit.patientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: AppIcons.small,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Expanded(
                          child: Text(
                            visit.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                    if (patient != null && patient.registerId != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Row(
                        children: [
                          Icon(
                            Icons.badge_outlined,
                            size: AppIcons.small,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          Expanded(
                            child: Text(
                              "ID ${patient.registerId}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (patient != null && patient.plan.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Row(
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: AppIcons.small,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          Expanded(
                            child: Text(
                              "Plan ${patient.plan}",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (visit.notes != null && visit.notes!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Row(
                        children: [
                          Icon(
                            Icons.notes_outlined,
                            size: AppIcons.small,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          Expanded(
                            child: Text(
                              visit.notes!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Small extra spacing to make room for badge if needed
                    const SizedBox(height: AppSpacing.xxs),
                  ],
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: _buildVisitModeBadge(visit.visitMode),
                ),
              ],
            ),
          ),

          const SizedBox(width: AppSpacing.xs),
          const Icon(
            Icons.chevron_right,
            size: AppIcons.large,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildVisitModeBadge(String mode) {
    IconData icon;
    Color color;
    String label;

    switch (mode) {
      case 'new':
        icon = Icons.add_circle_outline;
        color = AppColors.success;
        label = 'New';
        break;
      case 'monthly':
        icon = Icons.calendar_month_outlined;
        color = AppColors.primary;
        label = 'Planned NHC';
        break;
      case 'emergency':
        icon = Icons.emergency_outlined;
        color = AppColors.danger;
        label = 'Emergency';
        break;
      case 'dhc_visit':
        icon = Icons.home_work_outlined;
        color = AppColors.warning;
        label = 'DHC';
        break;
      case 'vhc_visit':
        icon = Icons.local_hospital_outlined;
        color = AppColors.scheduled;
        label = 'VHC';
        break;
      default:
        icon = Icons.help_outline;
        color = AppColors.textSecondary;
        label = mode.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  void _showVisitDetails(BuildContext context, HomeVisit visit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _VisitDetailsSheet(
        visit: visit,
        onDelete: () => _deleteVisit(visit),
        onRefresh: _refreshVisits,
      ),
    );
  }

  Future<void> _deleteVisit(HomeVisit visit) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        title: _HomeVisitDialogHeader(
          icon: Icons.delete_outline,
          title: 'Delete visit?',
          color: AppColors.danger,
        ),
        content: Text(
          "Are you sure you want to delete the visit for ${visit.patientName}?",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        actions: [
          AppSecondaryButton(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context, false),
          ),
          AppDangerButton(
            label: 'Delete',
            icon: Icons.delete_outline,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await HomeVisitService.deleteHomeVisit(visit.id!);
        // Verify deletion by refreshing
        await _refreshVisitsSync();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Visit deleted successfully"),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error: $e"),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  /// Synchronously refresh visits and wait for completion
  Future<void> _refreshVisitsSync() async {
    _allVisits = await HomeVisitService.getAllHomeVisits();
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildEmptyDayState() {
    return const AppEmptyState(
      icon: Icons.event_available_outlined,
      title: 'No visits scheduled',
      message: 'This day is free. Scheduled visits will appear here.',
    );
  }

  Widget _buildErrorState(String error) {
    return AppEmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Could not load visits',
      message: error,
      action: AppPrimaryButton(
        label: 'Try Again',
        icon: Icons.refresh,
        onPressed: _refreshVisits,
      ),
    );
  }
}

class _HomeVisitIconButton extends StatelessWidget {
  const _HomeVisitIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface1,
      borderRadius: AppRadius.md,
      child: InkWell(
        borderRadius: AppRadius.md,
        onTap: onPressed,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: AppColors.text, size: AppIcons.large),
        ),
      ),
    );
  }
}

class _HomeVisitTodayButton extends StatelessWidget {
  const _HomeVisitTodayButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface1,
      borderRadius: AppRadius.md,
      child: InkWell(
        borderRadius: AppRadius.md,
        onTap: onPressed,
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.today_outlined,
                  color: AppColors.primary,
                  size: AppIcons.normal,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Today',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 5,
      decoration: BoxDecoration(
        color: AppColors.borderStrong,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _HomeVisitDialogHeader extends StatelessWidget {
  const _HomeVisitDialogHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: AppRadius.md,
          ),
          child: Icon(icon, color: color, size: AppIcons.large),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
      ],
    );
  }
}

// Stateful widget for visit details that can fetch patient data
class _VisitDetailsSheet extends StatefulWidget {
  final HomeVisit visit;
  final VoidCallback onDelete;
  final VoidCallback onRefresh;

  const _VisitDetailsSheet({
    required this.visit,
    required this.onDelete,
    required this.onRefresh,
  });

  @override
  State<_VisitDetailsSheet> createState() => _VisitDetailsSheetState();
}

class _VisitDetailsSheetState extends State<_VisitDetailsSheet> {
  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(widget.visit.visitDate);
    const primaryColor = _homeVisitPrimary;
    final patient = widget.visit.patientDetails;
    final mediaQuery = MediaQuery.of(context);
    final bottomSafePadding = mediaQuery.viewPadding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.sheet,
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg + bottomSafePadding,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.85),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: _SheetHandle()),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Home Visit Details",
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.visit.patientName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (patient != null &&
                            patient.registerId != null &&
                            patient.registerId!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            "ID: ${patient.registerId}",
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: AppRadius.md,
                    ),
                    padding: AppInsets.sm,
                    child: Icon(
                      Icons.home_work_rounded,
                      color: primaryColor,
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Patient Information Section
              if (patient != null) ...[
                Text(
                  "Patient Information",
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 12,
                  children: [
                    if (patient.phone.isNotEmpty)
                      SizedBox(
                        width: (MediaQuery.of(context).size.width - 48) / 2 - 4,
                        child: _buildDetailRow(
                          Icons.phone,
                          "Phone",
                          patient.phone,
                        ),
                      ),
                    if (patient.phone2 != null && patient.phone2!.isNotEmpty)
                      SizedBox(
                        width: (MediaQuery.of(context).size.width - 48) / 2 - 4,
                        child: _buildDetailRow(
                          Icons.phone_android,
                          "Phone 2",
                          patient.phone2!,
                        ),
                      ),
                    SizedBox(
                      width: (MediaQuery.of(context).size.width - 48) / 2 - 4,
                      child: _buildDetailRow(
                        Icons.cake,
                        "Age",
                        "${patient.age} years",
                      ),
                    ),
                    SizedBox(
                      width: (MediaQuery.of(context).size.width - 48) / 2 - 4,
                      child: _buildDetailRow(
                        Icons.wc,
                        "Gender",
                        patient.gender,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (patient.disease.isNotEmpty)
                  _buildDetailRow(
                    Icons.medical_services,
                    "Diseases",
                    (patient.disease.toList()..sort()).join(', '),
                  )
                else
                  _buildDetailRow(
                    Icons.medical_services,
                    "Diseases",
                    "No diseases recorded",
                  ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  "Visit Information",
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],

              _buildDetailRow(
                Icons.calendar_today,
                "Visit Date",
                date != null
                    ? DateFormat('EEEE, d MMMM yyyy').format(date)
                    : "Invalid date",
              ),
              const SizedBox(height: AppSpacing.sm),

              if (patient != null)
                _buildEditableDetailRow(
                  Icons.assignment,
                  "Care Plan",
                  patient.plan.isEmpty ? "No plan assigned" : patient.plan,
                  onEdit: context.read<AuthService>().canEdit
                      ? () => _showEditPatientDialog(context, patient)
                      : null,
                )
              else
                _buildDetailRow(
                  Icons.assignment,
                  "Care Plan",
                  "No plan assigned",
                ),
              const SizedBox(height: AppSpacing.sm),
              _buildDetailRow(
                Icons.medical_services_outlined,
                "Visit Mode",
                _getVisitModeLabel(widget.visit.visitMode),
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildDetailRow(
                Icons.location_on,
                "Address",
                widget.visit.address.isNotEmpty
                    ? widget.visit.address
                    : "No address provided",
              ),
              const SizedBox(height: AppSpacing.sm),

              _buildDetailRow(
                Icons.group,
                "Team",
                widget.visit.team != null && widget.visit.team!.isNotEmpty
                    ? widget.visit.team!
                    : "No team assigned",
              ),
              const SizedBox(height: AppSpacing.sm),
              if (widget.visit.notes != null && widget.visit.notes!.isNotEmpty)
                _buildDetailRow(Icons.notes, "Notes", widget.visit.notes!)
              else
                _buildDetailRow(Icons.notes, "Notes", "No notes provided"),
              if (widget.visit.createdBy != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    "Created by: ${widget.visit.createdBy}",
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              if (context.read<AuthService>().canAccessNHC)
                AppPrimaryButton(
                  label: 'NHC / Visit Assessment',
                  icon: Icons.assignment_outlined,
                  fullWidth: true,
                  onPressed: widget.visit.id == null
                      ? null
                      : () {
                          if (!FeaturePermissionMiddleware.ensure(
                            context,
                            AppFeature.nhcAssessment,
                            moduleName: 'Visit Assessment',
                          )) {
                            return;
                          }
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VisitAssessmentModuleScreen(
                                visit: widget.visit,
                                patient: patient,
                              ),
                            ),
                          );
                        },
                ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  if (context.read<AuthService>().canDelete) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onDelete();
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text("Delete"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          minimumSize: const Size.fromHeight(52),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.danger),
                          tapTargetSize: MaterialTapTargetSize.padded,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.button,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  if (context.read<AuthService>().canEdit)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ModuleTheme(
                                palette: ModulePalettes.homeVisits,
                                child: Homevisit(visit: widget.visit),
                              ),
                            ),
                          );
                          if (result == true) widget.onRefresh();
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text("Edit Details"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: AppColors.textInverse,
                          minimumSize: const Size.fromHeight(52),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          tapTargetSize: MaterialTapTargetSize.padded,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.button,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: _homeVisitIconBackground,
            borderRadius: AppRadius.sm,
          ),
          child: Icon(icon, size: AppIcons.small, color: _homeVisitPrimary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getVisitModeLabel(String visitMode) {
    switch (visitMode) {
      case 'new':
        return 'New';
      case 'monthly':
        return 'Planned NHC';
      case 'emergency':
        return 'Emergency';
      case 'dhc_visit':
        return 'DHC';
      case 'vhc_visit':
        return 'VHC';
      default:
        return visitMode.toUpperCase();
    }
  }

  Widget _buildEditableDetailRow(
    IconData icon,
    String label,
    String value, {
    required VoidCallback? onEdit,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: _homeVisitIconBackground,
            borderRadius: AppRadius.sm,
          ),
          child: Icon(icon, size: AppIcons.small, color: _homeVisitPrimary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
        ),
        if (onEdit != null)
          Material(
            color: _homeVisitPrimary.withValues(alpha: 0.1),
            borderRadius: AppRadius.sm,
            child: InkWell(
              borderRadius: AppRadius.sm,
              onTap: onEdit,
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.edit_outlined,
                  size: AppIcons.small,
                  color: _homeVisitPrimary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showEditPatientDialog(BuildContext context, Patient patient) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _EditPatientDialog(
        patient: patient,
        onSave: (updatedPatient) async {
          Navigator.pop(context);
          await _updatePatient(updatedPatient);
        },
      ),
    );
  }

  Future<void> _updatePatient(Patient updatedPatient) async {
    try {
      if (updatedPatient.id == null) return;

      await PatientService.updatePatient(updatedPatient.id!, updatedPatient);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Patient information updated successfully"),
          backgroundColor: AppColors.success,
        ),
      );
      // Refresh visits data to get updated patient information
      widget.onRefresh();

      // Close the bottom sheet immediately after refresh
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error updating patient: $e"),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}

// Modern edit patient dialog
class _EditPatientDialog extends StatefulWidget {
  final Patient patient;
  final Function(Patient) onSave;

  const _EditPatientDialog({required this.patient, required this.onSave});

  @override
  State<_EditPatientDialog> createState() => _EditPatientDialogState();
}

class _EditPatientDialogState extends State<_EditPatientDialog> {
  late TextEditingController _planController;
  late List<String> _selectedDiseases;
  bool _isSaving = false;
  bool _isLoadingConfig = true;
  String? _configError;

  List<String> _availableDiseases = [];
  List<String> _availablePlans = [];
  String? _selectedPlan;

  @override
  void initState() {
    super.initState();
    _planController = TextEditingController(text: widget.patient.plan);
    _selectedDiseases = List.from(widget.patient.disease);
    _selectedPlan = widget.patient.plan;
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final config = await ConfigService.getConfig();
      if (!mounted) return;
      setState(() {
        _availableDiseases = config.diseases;
        _availablePlans = config.plans;
        _isLoadingConfig = false;
        _configError = null; // Clear any previous errors
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _configError = e.toString();
        _isLoadingConfig = false;
      });
    }
  }

  @override
  void dispose() {
    _planController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = _homeVisitPrimary;

    if (_isLoadingConfig) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.dialog,
          ),
          padding: AppInsets.xl,
          child: const Center(
            child: CircularProgressIndicator(color: _homeVisitPrimary),
          ),
        ),
      );
    }

    if (_configError != null) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.dialog,
          ),
          padding: AppInsets.lg,
          child: AppEmptyState(
            icon: Icons.error_outline,
            title: 'Failed to load configuration',
            message: _configError!,
            action: AppPrimaryButton(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: () {
                setState(() => _isLoadingConfig = true);
                _loadConfig();
              },
            ),
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.dialog,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: AppInsets.lg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Edit Patient Info",
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            widget.patient.name,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: AppColors.surface1,
                      borderRadius: AppRadius.md,
                      child: InkWell(
                        borderRadius: AppRadius.md,
                        onTap: () => Navigator.pop(context),
                        child: const SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(
                            Icons.close,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Care Plan Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          color: primaryColor,
                          size: 18,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          "Care Plan",
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<String>(
                      decoration: _dialogInputDecoration(
                        'Care Plan',
                        Icons.assignment_outlined,
                      ).copyWith(hintText: "Select care plan..."),
                      initialValue: _selectedPlan,
                      style: AppTypography.dropdownTextStyle(context),
                      items: _availablePlans
                          .map(
                            (plan) => DropdownMenuItem(
                              value: plan,
                              child: Text(plan),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedPlan = value;
                          if (value != null) {
                            _planController.text = value;
                          }
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Diseases Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.medical_services_outlined,
                          color: primaryColor,
                          size: 18,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          "Diseases",
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: _availableDiseases.map((disease) {
                        final isSelected = _selectedDiseases.contains(disease);
                        return FilterChip(
                          label: Text(disease),
                          selected: isSelected,
                          selectedColor: primaryColor,
                          backgroundColor: AppColors.surface1,
                          checkmarkColor: AppColors.textInverse,
                          side: BorderSide(
                            color: isSelected ? primaryColor : AppColors.border,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.button,
                          ),
                          labelStyle: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: isSelected
                                    ? AppColors.textInverse
                                    : AppColors.text,
                                fontWeight: FontWeight.w600,
                              ),
                          onSelected: (_) {
                            setState(() {
                              if (isSelected) {
                                _selectedDiseases.remove(disease);
                              } else {
                                _selectedDiseases.add(disease);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: AppSecondaryButton(
                        label: 'Cancel',
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppPrimaryButton(
                        label: 'Save Changes',
                        icon: Icons.save_outlined,
                        loading: _isSaving,
                        onPressed: _isSaving ? null : _saveChanges,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dialogInputDecoration(String label, IconData icon) {
    return InputDecoration(
      isDense: true,
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      prefixIcon: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.all(6),
        decoration: const BoxDecoration(
          color: _homeVisitIconBackground,
          borderRadius: AppRadius.sm,
        ),
        child: Icon(icon, size: AppIcons.normal, color: _homeVisitPrimary),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 50, minHeight: 50),
      filled: true,
      fillColor: AppColors.surface1,
      border: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(color: _homeVisitPrimary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
    );
  }

  Future<void> _saveChanges() async {
    // Validate selections
    if (_selectedDiseases.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select at least one disease"),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_selectedPlan == null || _selectedPlan!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a care plan"),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updatedPatient = Patient(
        id: widget.patient.id,
        name: widget.patient.name,
        relation: widget.patient.relation,
        gender: widget.patient.gender,
        address: widget.patient.address,
        phone: widget.patient.phone,
        phone2: widget.patient.phone2,
        age: widget.patient.age,
        place: widget.patient.place,
        village: widget.patient.village,
        disease: _selectedDiseases,
        plan: _selectedPlan ?? widget.patient.plan,
        registerId: widget.patient.registerId,
        registrationDate: widget.patient.registrationDate,
        isDead: widget.patient.isDead,
        dateOfDeath: widget.patient.dateOfDeath,
        createdBy: widget.patient.createdBy,
        createdAt: widget.patient.createdAt,
        updatedAt: widget.patient.updatedAt,
      );

      widget.onSave(updatedPatient);
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }
}
