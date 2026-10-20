import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oruma_app/billing_plan_screen.dart';
import 'package:oruma_app/eq_supply.dart';
import 'package:oruma_app/equipment_list_page.dart';
import 'package:oruma_app/equipment_supply_list_page.dart';
import 'package:oruma_app/home_visit_list_page.dart';
import 'package:oruma_app/medicine_list_page.dart';
import 'package:oruma_app/medicine_supply_list_page.dart';
import 'package:oruma_app/social_support_list_page.dart';
import 'package:oruma_app/volunteer_list_page.dart';
import 'package:oruma_app/pt_registration.dart' show patientrigister;
import 'package:oruma_app/patient_list_page.dart';
import 'package:oruma_app/privacy_policy_screen.dart';
import 'package:oruma_app/about_us_page.dart';
import 'package:oruma_app/about_us_admin_page.dart';
import 'package:oruma_app/volunteer_availability_page.dart';
import 'package:oruma_app/volunteer_availability_requests_admin_page.dart';
import 'package:oruma_app/deceased_patient_list_page.dart';
import 'package:provider/provider.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/loginscreen.dart';
import 'package:oruma_app/services/equipment_supply_service.dart';
import 'package:oruma_app/services/feature_permissions.dart';
import 'package:oruma_app/services/home_visit_service.dart';
import 'package:oruma_app/services/notification_service.dart';
import 'package:oruma_app/services/patient_service.dart';
import 'package:oruma_app/models/app_notification.dart';
import 'package:oruma_app/models/about_us.dart';
import 'package:oruma_app/models/equipment_supply.dart';
import 'package:oruma_app/models/volunteer_activity.dart';
import 'package:oruma_app/models/volunteer_assignment.dart';
import 'package:oruma_app/models/volunteer_availability_request.dart';
import 'package:oruma_app/services/volunteer_application_service.dart';
import 'package:oruma_app/services/volunteer_assignment_service.dart';
import 'package:oruma_app/services/volunteer_availability_request_service.dart';
import 'package:oruma_app/services/volunteer_service.dart';
import 'package:oruma_app/services/about_us_service.dart';
import 'package:oruma_app/core/localization/volunteer_request_messages.dart';
import 'package:oruma_app/volunteer_assignment_detail_page.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oruma_app/config_page.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';
import 'package:oruma_app/widgets/app_bottom_nav_router.dart';
import 'package:oruma_app/widgets/compact_app_bottom_bar.dart';
import 'package:oruma_app/widgets/feature_permission_gate.dart';
import 'package:oruma_app/widgets/module_theme.dart';
import 'package:oruma_app/widgets/unit_brand_avatar.dart';
import 'package:intl/intl.dart';
import 'package:oruma_app/features/visit_assessment/presentation/screens/visit_assessment_visit_picker_screen.dart';
import 'package:oruma_app/features/visit_assessment/data/visit_assessment_service.dart';
import 'package:oruma_app/features/reports/presentation/reports_page.dart';
import 'package:oruma_app/widgets/volunteer_removed_unit_request_card.dart';

const _appVersionLabel = 'Version 1.0.0 (Build 1)';
const _homeBackground = Color(0xFFF3F3EF);
const _homeInk = Color(0xFF171714);
const _homeMuted = Color(0xFF66665F);
const _homeHoverOverlay = Color(0x08000000);
const _homePressedOverlay = Color(0x10000000);

class Homescreen extends StatefulWidget {
  const Homescreen({super.key, this.aboutUsLoader});

  final Future<AboutUsData> Function({bool refresh})? aboutUsLoader;

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _activeSuppliesScrollController = ScrollController();
  Timer? _activeSuppliesAutoSlideTimer;
  int _activeSuppliesPageIndex = 0;
  List<EquipmentSupply> _activeSupplies = [];
  bool _activeSuppliesLoading = true;
  int _notificationCount = 0;
  List<AppNotification> _notifications = [];
  bool _notificationsLoading = true;
  final Set<String> _dismissedMaintenanceBannerKeys = {};
  VolunteerActivity? _volunteerActivity;
  List<VolunteerAssignment> _todayAssignments = [];
  List<VolunteerAssignment> _upcomingAssignments = [];
  List<VolunteerAssignment> _overdueAssignments = [];
  List<VolunteerAssignment> _completedAssignments = [];
  List<VolunteerAvailabilityRequest> _availabilityRequests = [];
  bool _assignmentsLoading = false;
  bool _availabilityRequestsLoading = false;
  bool _checkingApproval = false;
  AboutUsData? _pendingVolunteerStory;
  bool _pendingVolunteerStoryLoading = false;
  String? _pendingVolunteerStoryError;
  int _pendingVolunteerRegistrationCount = 0;
  int _pendingAvailabilityRequestCount = 0;
  bool _importantRequestsLoading = false;
  int? _patientCount;
  int _newPatientCountThisWeek = 0;
  int? _assessmentReviewCount;
  int? _upcomingHomeVisitCount;
  int _todayHomeVisitCount = 0;
  DateTime? _nextHomeVisitDate;
  int _selectedVolunteerTaskTab = 0;
  final Set<String> _updatingAssignmentIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrapAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _activeSuppliesAutoSlideTimer?.cancel();
    _activeSuppliesScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _bootstrapAccess();
    }
  }

  DateTime? _lastBootstrapAt;

  Future<void> _bootstrapAccess({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastBootstrapAt != null &&
        now.difference(_lastBootstrapAt!) < const Duration(minutes: 3)) {
      return;
    }
    _lastBootstrapAt = now;

    final auth = context.read<AuthService>();
    await auth.fetchUserProfile();
    if (!mounted || auth.isAccessBlocked) return;
    if (auth.isVolunteerPending) {
      await _loadPendingVolunteerStory(refresh: force);
      return;
    }
    if (!auth.isVolunteerApproved) return;
    _loadHomeSummary(auth);
    if (auth.isVolunteer) {
      _loadVolunteerActivity();
      _loadVolunteerAssignments();
      _loadVolunteerAvailabilityRequests();
    }
    if (auth.isAdmin) {
      _loadImportantRequests();
    }
    if (auth.canAccessEquipmentDistribution) {
      _loadActiveSupplies();
    } else {
      setState(() {
        _activeSupplies = [];
        _activeSuppliesLoading = false;
      });
    }
    _loadNotifications(refresh: force);
  }

  Future<void> _loadPendingVolunteerStory({bool refresh = false}) async {
    if (!mounted || (_pendingVolunteerStoryLoading && !refresh)) return;
    setState(() {
      _pendingVolunteerStoryLoading = true;
      _pendingVolunteerStoryError = null;
    });
    try {
      final loader = widget.aboutUsLoader;
      final story = loader == null
          ? await AboutUsService.getAboutUs(refresh: refresh)
          : await loader(refresh: refresh);
      if (!mounted) return;
      setState(() {
        _pendingVolunteerStory = story;
        _pendingVolunteerStoryLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pendingVolunteerStoryError = error
            .toString()
            .replaceFirst('Exception: ', '');
        _pendingVolunteerStoryLoading = false;
      });
    }
  }

  Future<void> _loadImportantRequests() async {
    if (!mounted || _importantRequestsLoading) return;
    setState(() => _importantRequestsLoading = true);
    try {
      final counts = await Future.wait<int>([
        VolunteerService.getVolunteers(forceRefresh: true).then(
          (volunteers) => volunteers
              .where(
                (volunteer) =>
                    volunteer.applicationStatus.toLowerCase() == 'pending',
              )
              .length,
        ),
        VolunteerAvailabilityRequestService.getRequests(
          status: 'pending',
        ).then((requests) => requests.length),
      ]);
      if (!mounted) return;
      setState(() {
        _pendingVolunteerRegistrationCount = counts[0];
        _pendingAvailabilityRequestCount = counts[1];
      });
    } catch (_) {
      // The dashboard remains usable if request summaries cannot be refreshed.
    } finally {
      if (mounted) setState(() => _importantRequestsLoading = false);
    }
  }

  Future<void> _checkApprovalStatus() async {
    if (_checkingApproval) return;
    setState(() => _checkingApproval = true);
    try {
      await _bootstrapAccess(force: true);
      if (!mounted) return;
      final auth = context.read<AuthService>();
      if (auth.isVolunteer &&
          !auth.isVolunteerApproved &&
          !auth.isVolunteerDeclined) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Approval is still pending with the unit.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to check approval status. Please try again.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _checkingApproval = false);
      }
    }
  }

  Future<void> _loadVolunteerActivity() async {
    if (!mounted) return;
    try {
      final activity = await VolunteerApplicationService.getMyActivity();
      if (!mounted) return;
      setState(() => _volunteerActivity = activity);
    } catch (_) {
      // The dashboard remains usable if activity history is temporarily offline.
    }
  }

  Future<void> _loadVolunteerAssignments() async {
    if (!mounted) return;
    setState(() => _assignmentsLoading = true);
    try {
      final all = await VolunteerAssignmentService.getAssignments(
        filter: 'all',
      );
      if (!mounted) return;
      const activeStatuses = {'assigned', 'accepted', 'in_progress'};
      setState(() {
        _todayAssignments = all
            .where((a) => a.isToday && activeStatuses.contains(a.status))
            .toList();
        _overdueAssignments = all
            .where((a) => a.isOverdue && activeStatuses.contains(a.status))
            .toList();
        _upcomingAssignments = all
            .where(
              (a) =>
                  !a.isToday &&
                  !a.isOverdue &&
                  activeStatuses.contains(a.status),
            )
            .toList();
        _completedAssignments =
            all.where((a) => a.status == 'completed').toList()..sort((a, b) {
              final aDate = a.completedAt ?? DateTime(1970);
              final bDate = b.completedAt ?? DateTime(1970);
              return bDate.compareTo(aDate);
            });
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _assignmentsLoading = false);
    }
  }

  Future<void> _loadVolunteerAvailabilityRequests() async {
    if (!mounted || _availabilityRequestsLoading) return;
    setState(() => _availabilityRequestsLoading = true);
    try {
      final requests = await VolunteerAvailabilityRequestService.getRequests();
      if (!mounted) return;
      setState(() => _availabilityRequests = requests);
    } catch (_) {
      // Availability is supplementary; assignments remain usable offline.
    } finally {
      if (mounted) setState(() => _availabilityRequestsLoading = false);
    }
  }

  Future<void> _loadHomeSummary(AuthService auth) async {
    final futures = <Future<void>>[];

    if (auth.canAccessPatients) {
      futures.add(
        PatientService.getPatientsList(filter: 'alive')
            .then((response) {
              if (!mounted) return;
              final weekAgo = DateTime.now().subtract(const Duration(days: 7));
              setState(() {
                _patientCount = response.counts.aliveCount;
                _newPatientCountThisWeek = response.patients
                    .where(
                      (patient) =>
                          patient.createdAt != null &&
                          patient.createdAt!.isAfter(weekAgo),
                    )
                    .length;
              });
            })
            .catchError((_) {}),
      );
    }

    if (auth.canAccessNHC) {
      futures.add(
        VisitAssessmentService.getAssessments()
            .then((assessments) {
              if (!mounted) return;
              setState(() {
                _assessmentReviewCount = assessments
                    .where(
                      (assessment) =>
                          assessment.status != 'submitted' &&
                          !assessment.isComplete,
                    )
                    .length;
              });
            })
            .catchError((_) {}),
      );
    }

    if (auth.canAccessHomeVisits) {
      futures.add(
        HomeVisitService.getAllHomeVisits()
            .then((visits) {
              if (!mounted) return;
              final today = DateTime.now();
              final startOfToday = DateTime(today.year, today.month, today.day);
              final upcoming =
                  visits
                      .map((visit) => DateTime.tryParse(visit.visitDate))
                      .whereType<DateTime>()
                      .where((date) => !date.isBefore(startOfToday))
                      .toList()
                    ..sort();
              final todayCount = upcoming
                  .where(
                    (date) =>
                        date.year == startOfToday.year &&
                        date.month == startOfToday.month &&
                        date.day == startOfToday.day,
                  )
                  .length;
              setState(() {
                _upcomingHomeVisitCount = upcoming.length;
                _todayHomeVisitCount = todayCount;
                _nextHomeVisitDate = upcoming.isEmpty ? null : upcoming.first;
              });
            })
            .catchError((_) {}),
      );
    }

    await Future.wait(futures);
  }

  Future<void> _loadActiveSupplies() async {
    try {
      final supplies = await EquipmentSupplyService.getActiveSupplies();
      if (!mounted) return;
      setState(() {
        _activeSupplies = supplies;
        _activeSuppliesLoading = false;
        _activeSuppliesPageIndex = 0;
      });
      if (_activeSuppliesScrollController.hasClients) {
        _activeSuppliesScrollController.jumpTo(0);
      }
      _restartActiveSuppliesAutoSlide();
    } catch (e) {
      if (!mounted) return;
      setState(() => _activeSuppliesLoading = false);
    }
  }

  Future<void> _loadNotifications({bool refresh = false}) async {
    try {
      final notifications = await NotificationService.getActiveNotifications(
        refresh: refresh,
      );
      if (!mounted) return;
      final auth = context.read<AuthService>();
      final visibleNotifications = notifications
          .where((notification) => _canShowNotification(notification, auth))
          .toList();
      setState(() {
        _notifications = visibleNotifications;
        _notificationCount = visibleNotifications.length;
        _notificationsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _notificationsLoading = false);
    }
  }

  bool _canShowNotification(AppNotification notification, AuthService auth) {
    if (_isBillingNotification(notification)) return auth.isAdmin;
    if (notification.type == 'equipment_overdue') {
      return auth.canAccessEquipmentDistribution;
    }
    if (notification.type.startsWith('medicine_expiry')) {
      return auth.canAccessMedicineMaster || auth.canAccessMedicineStock;
    }
    return true;
  }

  Future<void> _openNotifications() async {
    await _loadNotifications(refresh: true);
    if (!mounted) return;
    _showNotifications();
  }

  void _restartActiveSuppliesAutoSlide() {
    _activeSuppliesAutoSlideTimer?.cancel();
    if (_activeSupplies.length <= 1) return;

    _activeSuppliesAutoSlideTimer = Timer.periodic(const Duration(seconds: 4), (
      _,
    ) {
      if (!mounted || !_activeSuppliesScrollController.hasClients) return;
      final availableWidth = MediaQuery.sizeOf(context).width - 40;
      final visibleCount = _activeSuppliesVisibleCount(availableWidth);
      final maxStart = (_activeSupplies.length - visibleCount)
          .clamp(0, _activeSupplies.length - 1)
          .toInt();
      if (maxStart <= 0) return;

      final next = (_activeSuppliesPageIndex + 1) % (maxStart + 1);
      final cardExtent = _activeSupplyCardWidth(availableWidth) + 12;
      final targetOffset = (next * cardExtent).clamp(
        0.0,
        _activeSuppliesScrollController.position.maxScrollExtent,
      );
      setState(() => _activeSuppliesPageIndex = next);
      _activeSuppliesScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _showNotifications() {
    final notifications = List<AppNotification>.from(_notifications);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.scrim,
      isScrollControlled: true,
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;

        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.72,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.sheet,
              boxShadow: AppShadow.large,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: AppSpacing.sm),
                  width: 52,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.borderStrong,
                    borderRadius: AppRadius.xs,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Notifications',
                          style: textTheme.titleLarge?.copyWith(
                            color: AppColors.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _ShellStatusPill(
                        label: '$_notificationCount Active',
                        icon: Icons.bolt_rounded,
                        color: AppColors.warning,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: _notificationsLoading && notifications.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.xl),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : notifications.isEmpty
                      ? const AppEmptyState(
                          icon: Icons.notifications_none_rounded,
                          title: 'No notifications',
                          message:
                              'Everything is clear. New care alerts will appear here.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.md,
                          ),
                          shrinkWrap: true,
                          itemCount: notifications.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final notification = notifications[index];
                            final color = _notificationColor(notification);

                            return Material(
                              color: AppColors.surface,
                              borderRadius: AppRadius.card,
                              child: InkWell(
                                borderRadius: AppRadius.card,
                                onTap: () {
                                  Navigator.pop(context);
                                  _handleNotificationTap(notification);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    borderRadius: AppRadius.card,
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.1),
                                          borderRadius: AppRadius.md,
                                        ),
                                        child: Icon(
                                          _notificationIcon(notification),
                                          color: color,
                                          size: AppIcons.large,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              notification.title,
                                              style: textTheme.titleSmall
                                                  ?.copyWith(
                                                    color: AppColors.text,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(
                                              height: AppSpacing.xxs,
                                            ),
                                            Text(
                                              notification.message,
                                              style: textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color:
                                                        AppColors.textSecondary,
                                                    height: 1.45,
                                                  ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(
                                              height: AppSpacing.xs,
                                            ),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.schedule_rounded,
                                                  size: AppIcons.small,
                                                  color: AppColors.textMuted,
                                                ),
                                                const SizedBox(
                                                  width: AppSpacing.xxs,
                                                ),
                                                Text(
                                                  _formatNotificationTime(
                                                    notification.triggeredAt,
                                                  ),
                                                  style: textTheme.labelMedium
                                                      ?.copyWith(
                                                        color:
                                                            AppColors.textMuted,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: AppColors.textMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (notifications.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceFloating,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: AppPrimaryButton(
                      label: 'Refresh Notifications',
                      icon: Icons.refresh_rounded,
                      fullWidth: true,
                      onPressed: () {
                        Navigator.pop(context);
                        _openNotifications();
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleNotificationTap(AppNotification notification) async {
    if (_isBillingNotification(notification)) {
      if (!context.read<AuthService>().isAdmin) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const BillingPlanScreen()),
      );
      return;
    }

    if (notification.id != null) {
      NotificationService.markRead(
        notification.id!,
      ).then((_) => _loadNotifications(refresh: true)).catchError((_) {});
    }

    if (notification.type == 'volunteer_availability_request') {
      if (!context.read<AuthService>().isAdmin) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const VolunteerAvailabilityRequestsAdminPage(),
        ),
      );
      return;
    }

    if (notification.type == 'volunteer_availability_update') {
      if (!context.read<AuthService>().isVolunteer) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const VolunteerAvailabilityPage(),
        ),
      );
      return;
    }

    if (notification.type == 'volunteer_assignment') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ModuleTheme(
            palette: ModulePalettes.homeVisits,
            child: HomeVisitListPage(),
          ),
        ),
      );
      return;
    }

    if (notification.type == 'volunteer_registration') {
      if (!context.read<AuthService>().isAdmin) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ModuleTheme(
            palette: ModulePalettes.volunteers,
            child: VolunteerListPage(),
          ),
        ),
      );
      return;
    }

    if (notification.type == 'equipment_overdue') {
      if (!FeaturePermissionMiddleware.ensure(
        context,
        AppFeature.equipmentDistribution,
        moduleName: 'Equipment Supply',
      )) {
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ModuleTheme(
            palette: ModulePalettes.equipmentSupply,
            child: EquipmentSupplyListPage(),
          ),
        ),
      );
      return;
    }

    if (notification.type.startsWith('medicine_expiry')) {
      if (!FeaturePermissionMiddleware.ensure(
        context,
        AppFeature.medicineMaster,
        moduleName: 'Medicine',
      )) {
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ModuleTheme(
            palette: ModulePalettes.medicineSupply,
            child: MedicineListPage(),
          ),
        ),
      );
    }
  }

  // Helper widget to build the Quick Add Bottom Sheet
  void _showQuickAddOptions() {
    final auth = context.read<AuthService>();
    final actions = <Widget>[
      if (auth.canAccessPatients)
        _buildQuickActionItem(
          icon: Icons.person_add_rounded,
          label: "Patient",
          color: ModulePalettes.patients.primary,
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ModuleTheme(
                  palette: ModulePalettes.patients,
                  child: patientrigister(),
                ),
              ),
            );
          },
        ),
      if (auth.canAccessHomeVisits)
        _buildQuickActionItem(
          icon: Icons.add_home_work_rounded,
          label: "Visit",
          color: ModulePalettes.homeVisits.primary,
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ModuleTheme(
                  palette: ModulePalettes.homeVisits,
                  child: HomeVisitListPage(),
                ),
              ),
            );
          },
        ),
      if (auth.canAccessEquipmentDistribution)
        _buildQuickActionItem(
          icon: Icons.medical_services_rounded,
          label: "Supply",
          color: ModulePalettes.equipmentSupply.primary,
          onTap: () async {
            Navigator.pop(context);
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ModuleTheme(
                  palette: ModulePalettes.equipmentSupply,
                  child: EqSupply(),
                ),
              ),
            );
            if (mounted &&
                context.read<AuthService>().canAccessEquipmentDistribution) {
              _loadActiveSupplies();
            }
          },
        ),
      if (auth.canAccessVolunteers)
        _buildQuickActionItem(
          icon: Icons.volunteer_activism_rounded,
          label: "Volunteer",
          color: ModulePalettes.volunteers.primary,
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ModuleTheme(
                  palette: ModulePalettes.volunteers,
                  child: auth.canCreate
                      ? const VolunteerFormPage()
                      : const VolunteerListPage(),
                ),
              ),
            );
          },
        ),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.scrim,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.sheet,
            boxShadow: AppShadow.large,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: _SheetHandle()),
              const SizedBox(height: AppSpacing.lg),
              Text(
                "Quick Add",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Create common care records faster.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (actions.isEmpty)
                const AppEmptyState(
                  icon: Icons.add_circle_outline_rounded,
                  title: 'No quick actions',
                  message: 'No quick actions are enabled for this unit.',
                )
              else
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: actions,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 104,
      child: Material(
        color: AppColors.surface1,
        borderRadius: AppRadius.card,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.card,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: AppRadius.md,
                  ),
                  child: Icon(icon, color: color, size: AppIcons.large),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUserProfile(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.scrim,
      isScrollControlled: true,
      builder: (context) {
        final auth = context.watch<AuthService>();
        final user = auth.user;
        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.92,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.sheet,
              boxShadow: AppShadow.large,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _SheetHandle(),
                  const SizedBox(height: AppSpacing.lg),
                  const UnitBrandAvatar(
                    size: 80,
                    preferAppIcon: true,
                    backgroundColor: AppColors.primaryLight,
                    iconColor: AppColors.primary,
                    fallbackIcon: Icons.person,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    auth.unitName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      textStyle: Theme.of(context).textTheme.headlineMedium,
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ).copyWith(fontFamilyFallback: const ['NotoSansMalayalam']),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if ((user?['name']?.toString().trim().isNotEmpty ?? false))
                    Text(
                      user!['name'].toString(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if ((user?['email']?.toString().trim().isNotEmpty ?? false))
                    Text(
                      user!['email'].toString(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  if (auth.isVolunteer && _volunteerActivity != null) ...[
                    _buildVolunteerAchievementCard(
                      context,
                      _volunteerActivity!,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  _buildUnitDetailsCard(context, auth),
                  const SizedBox(height: AppSpacing.lg),
                  if (auth.isAdmin) ...[
                    _buildProfileMenuItem(
                      icon: Icons.settings_outlined,
                      title: "Settings",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                const ConfigPage(mode: ConfigPageMode.settings),
                          ),
                        );
                      },
                    ),
                    _buildProfileMenuItem(
                      icon: Icons.receipt_long_outlined,
                      title: "Billing & Plan",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const BillingPlanScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                  _buildProfileMenuItem(
                    icon: Icons.help_outline,
                    title: "Help & Support",
                    onTap: () {
                      Navigator.pop(context);
                      _showHelpAndSupport(context);
                    },
                  ),
                  _buildProfileMenuItem(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy & Data Use',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PrivacyPolicyScreen(
                            supportEmail: auth.unitSupportEmail,
                            supportPhone: auth.unitSupportPhone,
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 32),
                  if (auth.isVolunteer) ...[
                    _buildProfileMenuItem(
                      icon: Icons.delete_forever_outlined,
                      title: "Delete Account",
                      color: AppColors.danger,
                      onTap: () {
                        Navigator.pop(context); // Close sheet
                        _confirmDeleteAccount(context);
                      },
                    ),
                  ],
                  _buildProfileMenuItem(
                    icon: Icons.logout,
                    title: "Logout",
                    color: AppColors.danger,
                    onTap: () {
                      Navigator.pop(context); // Close sheet
                      context.read<AuthService>().logout();
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const Loginscreen(),
                        ),
                        (route) => false,
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showHelpAndSupport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final auth = context.watch<AuthService>();
        final supportPhone = auth.unitSupportPhone;
        final supportPhoneDial = auth.unitSupportPhoneDial;

        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.86,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.sheet,
              boxShadow: AppShadow.large,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _SheetHandle(),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: AppRadius.card,
                    ),
                    child: const Icon(
                      Icons.contact_support_rounded,
                      size: AppIcons.feature,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    "Help & Support",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Contact your unit support team.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surface1,
                      borderRadius: AppRadius.card,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: AppRadius.sm,
                              ),
                              child: const Icon(
                                Icons.business_rounded,
                                color: AppColors.primary,
                                size: AppIcons.normal,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    auth.unitName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: AppColors.text,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: AppSpacing.xxs),
                                  Text(
                                    auth.unitLocation,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (auth.canViewContactNumbers) ...[
                          const SizedBox(height: AppSpacing.md),
                          const Divider(height: 1),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: AppRadius.sm,
                                ),
                                child: const Icon(
                                  Icons.phone_rounded,
                                  color: AppColors.success,
                                  size: AppIcons.normal,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Contact Number",
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                    const SizedBox(height: AppSpacing.xxs),
                                    Text(
                                      supportPhone ?? 'Not added',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: AppColors.text,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (auth.canCall) ...[
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: supportPhoneDial == null
                            ? null
                            : () async {
                                final Uri phoneUri = Uri(
                                  scheme: 'tel',
                                  path: supportPhoneDial,
                                );
                                if (await canLaunchUrl(phoneUri)) {
                                  await launchUrl(phoneUri);
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Could not launch phone dialer',
                                        ),
                                        backgroundColor: AppColors.danger,
                                      ),
                                    );
                                  }
                                }
                              },
                        icon: const Icon(Icons.call, size: 18),
                        label: const Text(
                          "Make a Call",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: AppColors.textInverse,
                          minimumSize: const Size.fromHeight(56),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.button,
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showQRModal(BuildContext context) {
    final auth = context.read<AuthService>();
    final supportQr = auth.unitSupportQr;
    if (supportQr == null) return;
    final supportQrLabel = auth.unitName.toUpperCase();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        child: AppCard(
          surfaceLevel: AppSurfaceLevel.modal,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Support QR',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: AppRadius.card,
                child: _SupportQrImage(source: supportQr),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                supportQrLabel,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnitDetailsCard(BuildContext context, AuthService auth) {
    final status = auth.unitStatus ?? 'active';
    final isActive = status.toLowerCase() == 'active';
    final phones = auth.unitContactPhones;
    final code = auth.unitCode;
    final village = auth.unitVillage;
    final district = auth.unitDistrict;
    final locationParts = [
      if (village != null && village.isNotEmpty) village,
      if (district != null && district.isNotEmpty) district,
    ];
    final resolvedLocation = locationParts.isNotEmpty
        ? locationParts.join(', ')
        : auth.unitLocation;
    final email = auth.unitContactEmail;
    final address = auth.unitAddress;
    final notes = auth.unitNotes;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.domain_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Unit Details',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.success : AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isActive ? AppColors.success : AppColors.warning,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),
          if (code != null && code.isNotEmpty) ...[
            _buildUnitDetailRow(
              icon: Icons.tag_rounded,
              label: 'Unit Code',
              value: code,
              isBadge: true,
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (resolvedLocation.isNotEmpty) ...[
            _buildUnitDetailRow(
              icon: Icons.location_on_outlined,
              label: 'Area / District',
              value: resolvedLocation,
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (auth.canViewContactNumbers && phones.isNotEmpty) ...[
            _buildUnitDetailRow(
              icon: Icons.phone_outlined,
              label: 'Contact Phone(s)',
              value: phones.join(', '),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (email != null && email.isNotEmpty) ...[
            _buildUnitDetailRow(
              icon: Icons.email_outlined,
              label: 'Contact Email',
              value: email,
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (address != null && address.isNotEmpty) ...[
            _buildUnitDetailRow(
              icon: Icons.home_work_outlined,
              label: 'Address',
              value: address,
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (notes != null && notes.isNotEmpty) ...[
            _buildUnitDetailRow(
              icon: Icons.notes_rounded,
              label: 'Notes',
              value: notes,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUnitDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isBadge = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: isBadge
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                )
              : Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildVolunteerAchievementCard(
    BuildContext context,
    VolunteerActivity activity,
  ) {
    final color = _achievementColor(activity.achievementTier);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.card,
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.workspace_premium_rounded, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${activity.achievementTier} achievement',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  '${activity.totalSocialWorks} social works completed',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.28)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, size: 14, color: color),
                const SizedBox(width: 2),
                Text(
                  '${activity.totalPoints} pts',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _achievementColor(String tier) {
    return switch (tier.toLowerCase()) {
      'platinum' => const Color(0xFF536878),
      'gold' => const Color(0xFFB7791F),
      'silver' => const Color(0xFF64748B),
      'bronze' => const Color(0xFF9A5B35),
      _ => AppColors.primary,
    };
  }

  Color _achievementSurfaceColor(String tier) {
    return switch (tier.toLowerCase()) {
      'platinum' => const Color(0xFFEEF4F6),
      'gold' => const Color(0xFFFFF7DC),
      'silver' => const Color(0xFFF1F5F9),
      'bronze' => const Color(0xFFFFF3EA),
      _ => const Color(0xFFEEF4FF),
    };
  }

  Widget _buildProfileMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    final itemColor = color ?? AppColors.primary;
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: itemColor.withValues(alpha: 0.1),
          borderRadius: AppRadius.md,
        ),
        child: Icon(icon, color: itemColor, size: AppIcons.normal),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: color ?? AppColors.text,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        size: AppIcons.normal,
        color: AppColors.textMuted,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    );
  }

  void _handleBottomNavigation(AppBottomSection section) {
    AppBottomNavRouter.handle(
      context,
      current: AppBottomSection.home,
      target: section,
    );
  }

  Widget _buildVolunteerApprovalCard(AuthService auth) {
    if (auth.isVolunteerRemoved) {
      return VolunteerRemovedUnitRequestCard(
        onSubmitted: () => _bootstrapAccess(force: true),
      );
    }

    final declined = auth.isVolunteerDeclined;
    final color = declined ? AppColors.danger : AppColors.warning;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: AppCard(
          surfaceLevel: AppSurfaceLevel.elevated,
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  declined
                      ? Icons.cancel_outlined
                      : Icons.hourglass_top_rounded,
                  color: color,
                  size: 38,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                declined ? 'Application declined' : 'Approval is pending',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                declined
                    ? 'Your volunteer application was not approved. Please contact the palliative care unit if you need help.'
                    : 'Your volunteer registration was received. The palliative care unit must approve it before the app modules become available.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              if (!declined) ...[
                const SizedBox(height: AppSpacing.lg),
                if (_checkingApproval) ...[
                  const SizedBox(
                    width: 220,
                    child: ClipRRect(
                      borderRadius: AppRadius.sm,
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        backgroundColor: AppColors.primaryLight,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                TextButton.icon(
                  onPressed: _checkingApproval ? null : _checkApprovalStatus,
                  icon: _checkingApproval
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(
                    _checkingApproval
                        ? 'Checking approval status...'
                        : 'Check approval status',
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.sm,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    onPressed: () {
                      auth.logout();
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const Loginscreen(),
                        ),
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Logout'),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    onPressed: () => _confirmDeleteAccount(context),
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('Delete Account'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingVolunteerStoryCard() {
    final story = _pendingVolunteerStory;
    final content = story?.content.trim() ?? '';
    final title = story?.title.trim().isNotEmpty == true
        ? story!.title.trim()
        : AboutUsData.defaultTitle;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: AppCard(
          surfaceLevel: AppSurfaceLevel.elevated,
          backgroundColor: const Color(0xFFFFFEFA),
          borderColor: const Color(0xFFE7E0D2),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5E8072).withValues(alpha: 0.10),
                      borderRadius: AppRadius.sm,
                    ),
                    child: const Icon(
                      Icons.menu_book_outlined,
                      color: Color(0xFF5E8072),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Our Story',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (_pendingVolunteerStoryLoading) ...[
                const LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: AppColors.surface2,
                  color: Color(0xFF5E8072),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Loading the unit story…',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ] else if (_pendingVolunteerStoryError != null) ...[
                Text(
                  'Unable to load the unit story. ${_pendingVolunteerStoryError!}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _loadPendingVolunteerStory(refresh: true),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ),
              ] else if (content.isEmpty) ...[
                Text(
                  'This unit has not published its story yet.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ] else ...[
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.chilanka(
                    color: const Color(0xFF24446A),
                    fontSize: 22,
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                  ).copyWith(
                    fontFamilyFallback: const ['NotoSansMalayalam'],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Divider(color: Color(0xFFDDE7E2)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  content,
                  style: const TextStyle(
                    fontFamily: 'NotoSansMalayalam',
                    fontSize: 16,
                    height: 1.75,
                    fontWeight: FontWeight.w400,
                    color: AppColors.text,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _taskColor(String type) {
    switch (type) {
      case 'home_visit':
        return const Color(0xFF0D9488); // Teal
      case 'visit_assessment':
        return const Color(0xFFD97706); // Amber
      case 'social_support':
        return const Color(0xFFBE185D); // Pink
      default:
        return AppColors.primary;
    }
  }

  IconData _taskIcon(String type) {
    switch (type) {
      case 'home_visit':
        return Icons.home_work_rounded;
      case 'visit_assessment':
        return Icons.assignment_rounded;
      case 'social_support':
        return Icons.volunteer_activism_rounded;
      default:
        return Icons.task_alt_rounded;
    }
  }

  Color _statusColor(String status) {
    return VolunteerRequestMessages.getStatusColor(status);
  }

  void _openAssignmentDetail(VolunteerAssignment assignment) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VolunteerAssignmentDetailPage(
          assignmentId: assignment.id,
          initialAssignment: assignment,
        ),
      ),
    );
    _loadVolunteerAssignments();
    _loadVolunteerActivity();
  }

  String _formatAssignmentDate(String dateStr) {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    return DateFormat('EEE, dd MMM yyyy').format(d);
  }

  Widget _buildVolunteerTasksSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Overdue section if any
        if (_overdueAssignments.isNotEmpty) ...[
          _buildOverdueSection(context),
          const SizedBox(height: AppSpacing.md),
        ],

        // 2. Today's Tasks section
        _buildTodayTasksSection(context),
        const SizedBox(height: AppSpacing.md),

        // 3. Upcoming section
        _buildUpcomingSection(context),
      ],
    );
  }

  Widget _buildOverdueSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.05),
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.danger,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Overdue Tasks',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_overdueAssignments.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ..._overdueAssignments.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _buildAssignmentItemCard(a, isOverdue: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayTasksSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDashboardSectionHeader(
                context,
                title: "Today's Tasks",
                subtitle: 'Tasks scheduled for today.',
                compact: true,
              ),
            ),
            if (_todayAssignments.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  '${_todayAssignments.length} ${_todayAssignments.length == 1 ? 'task' : 'tasks'} today',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Content
        if (_assignmentsLoading && _todayAssignments.isEmpty)
          _buildTaskSkeleton()
        else if (_todayAssignments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceFloating,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.event_available_rounded,
                    size: 28,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'No tasks assigned today',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'You have no visits or assignments scheduled for today.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: _todayAssignments.map((a) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _buildTodayTaskCard(a),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildTodayTaskCard(VolunteerAssignment assignment) {
    final color = _taskColor(assignment.taskType);
    final icon = _taskIcon(assignment.taskType);
    final statusColor = _statusColor(assignment.status);

    return InkWell(
      onTap: () => _openAssignmentDetail(assignment),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfaceFloating,
          borderRadius: AppRadius.card,
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          children: [
            // Top Accent Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.12),
                    color.withValues(alpha: 0.03),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    assignment.typeLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: color,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'TODAY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (assignment.pointsAwarded > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        assignment.pointsLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Card Body
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              assignment.patient.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    assignment.patient.place?.isNotEmpty == true
                                        ? assignment.patient.place!
                                        : assignment.patient.address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
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
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          assignment.statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (assignment.coVolunteers.isNotEmpty ||
                      (assignment.taskDetails.team?.isNotEmpty == true)) ...[
                    const Divider(height: 16, color: AppColors.border),
                    Row(
                      children: [
                        const Icon(
                          Icons.people_outline,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            assignment.coVolunteers.isNotEmpty
                                ? 'Team: ${assignment.coVolunteers.map((c) => c.name).join(', ')}'
                                : 'Team: ${assignment.taskDetails.team}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your volunteer account? This action cannot be undone and your personal account details will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final auth = context.read<AuthService>();
              await auth.logout();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Your account has been deleted.'),
                  duration: Duration(seconds: 3),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const Loginscreen()),
                (route) => false,
              );
            },
            child: const Text(
              'Delete Account',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingSection(BuildContext context) {
    if (_upcomingAssignments.isEmpty) {
      return const SizedBox.shrink();
    }

    // Group upcoming tasks
    final Map<String, List<VolunteerAssignment>> groups = {
      'Tomorrow': [],
      'This Week': [],
      'Later': [],
    };

    final today = DateTime.now();
    for (final a in _upcomingAssignments) {
      final d = DateTime.tryParse(a.scheduledDate);
      if (d == null) {
        groups['Later']!.add(a);
        continue;
      }
      final diff = DateTime(
        d.year,
        d.month,
        d.day,
      ).difference(DateTime(today.year, today.month, today.day)).inDays;
      if (diff == 1) {
        groups['Tomorrow']!.add(a);
      } else if (diff <= 7) {
        groups['This Week']!.add(a);
      } else {
        groups['Later']!.add(a);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDashboardSectionHeader(
          context,
          title: 'Upcoming Tasks',
          subtitle: 'Visits and activities planned ahead.',
          compact: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final entry in groups.entries)
          if (entry.value.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Row(
                children: [
                  Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${entry.value.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...entry.value.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: _buildAssignmentItemCard(a),
              ),
            ),
          ],
      ],
    );
  }

  Widget _buildAssignmentItemCard(
    VolunteerAssignment assignment, {
    bool isOverdue = false,
  }) {
    final color = isOverdue
        ? AppColors.danger
        : _taskColor(assignment.taskType);
    final icon = _taskIcon(assignment.taskType);
    final statusColor = _statusColor(assignment.status);

    return InkWell(
      onTap: () => _openAssignmentDetail(assignment),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceFloating,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOverdue
                ? AppColors.danger.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment.patient.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${assignment.typeLabel} • ${_formatAssignmentDate(assignment.scheduledDate)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOverdue
                              ? AppColors.danger
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        assignment.statusLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                    if (assignment.pointsAwarded > 0 &&
                        !assignment.isCancelled) ...[
                      const SizedBox(height: 4),
                      Text(
                        assignment.pointsLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (assignment.isCancelled) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  VolunteerRequestMessages.getPositiveMessage(
                    taskType: assignment.taskType,
                    status: assignment.status,
                  ),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.text,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTaskSkeleton() {
    return Container(
      width: double.infinity,
      height: 110,
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _buildVolunteerAvailabilityCallout(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      borderColor: AppColors.primary.withValues(alpha: 0.16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const VolunteerAvailabilityPage(),
          ),
        );
      },
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: AppRadius.sm,
            ),
            child: const Icon(
              Icons.volunteer_activism_outlined,
              size: 21,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share your availability',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Choose a working day and send a request to the admin.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 20,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildImportantRequestsSection(BuildContext context) {
    final total = _pendingVolunteerRegistrationCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$total ${total == 1 ? 'request needs' : 'requests need'} your review.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth;
            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                if (_pendingVolunteerRegistrationCount > 0)
                  SizedBox(
                    width: cardWidth,
                    child: _buildImportantRequestCard(
                      context,
                      title: 'Volunteer registrations',
                      subtitle:
                          '$_pendingVolunteerRegistrationCount awaiting approval',
                      count: _pendingVolunteerRegistrationCount,
                      icon: Icons.how_to_reg_outlined,
                      color: AppColors.warning,
                      onTap: _openVolunteerRegistrationRequests,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildImportantRequestCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required int count,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      backgroundColor: color.withValues(alpha: 0.07),
      borderColor: color.withValues(alpha: 0.26),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: AppRadius.md,
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.chevron_right_rounded, color: color),
        ],
      ),
    );
  }

  Future<void> _openVolunteerRegistrationRequests() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ModuleTheme(
          palette: ModulePalettes.volunteers,
          child: VolunteerListPage(showPendingRegistrations: true),
        ),
      ),
    );
    if (mounted) await _loadImportantRequests();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (auth.isVolunteer && !auth.isVolunteerApproved) {
      return _buildLegacyHome(context);
    }
    return _buildRoleHome(context, auth);
  }

  Widget _buildRoleHome(BuildContext context, AuthService auth) {
    final showActivity =
        auth.isAdmin ||
        auth.isStaff ||
        auth.isVolunteer ||
        (auth.isMember && _notifications.isNotEmpty);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth < AppBreakpoints.tablet
        ? AppSpacing.md
        : AppSpacing.lg;

    return ColoredBox(
      color: _homeBackground,
      child: AdaptiveAppScaffold(
        scaffoldKey: _scaffoldKey,
        drawer: _buildProfessionalDrawer(context),
        backgroundColor: _homeBackground,
        contentMaxWidth: 1040,
        currentSection: AppBottomSection.home,
        onNavigationSelected: _handleBottomNavigation,
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () => _bootstrapAccess(force: true),
            color: _homeInk,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                AppSpacing.sm,
                horizontalPadding,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHomeHeader(context, auth),
                  const SizedBox(height: AppSpacing.md),
                  _buildPriorityCards(context, auth),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Quick actions',
                    style: _homeCompactSectionTitleStyle(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildQuickActions(context, auth),
                  if (showActivity) ...[
                    const SizedBox(height: AppSpacing.md),
                    _buildRoleActivitySection(context, auth),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeHeader(BuildContext context, AuthService auth) {
    return _buildDashboardHeader(
      context,
      auth,
      isCompact: MediaQuery.sizeOf(context).width < AppBreakpoints.tablet,
    );
  }

  Widget _buildPriorityCards(BuildContext context, AuthService auth) {
    final actions = _priorityActions(auth);
    return Row(
      children: [
        for (var index = 0; index < actions.length; index++) ...[
          if (index > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(child: _HomeMetricCard(action: actions[index])),
        ],
      ],
    );
  }

  List<_HomeMetricAction> _priorityActions(AuthService auth) {
    final patientSubtitle = auth.isMember
        ? 'Your family'
        : auth.isVolunteer
        ? 'Assigned to you'
        : auth.isStaff && _todayHomeVisitCount > 0
        ? '$_todayHomeVisitCount visits today'
        : _newPatientCountThisWeek > 0
        ? '$_newPatientCountThisWeek new this week'
        : 'Active patients';
    final patients = _HomeMetricAction(
      title: 'Patients',
      value: _formatMetric(_patientCount),
      subtitle: patientSubtitle,
      icon: Icons.people_outline_rounded,
      iconBackground: ModulePalettes.patients.iconBackground,
      iconColor: ModulePalettes.patients.primary,
      onTap: () => _openPatients(auth),
    );

    if (auth.isVolunteer) {
      final latestAvailability = _latestFutureAvailabilityRequest();
      return [
        patients,
        _HomeMetricAction(
          title: 'Share\navailability',
          value: latestAvailability == null ? 'Add' : 'Set',
          subtitle: latestAvailability == null
              ? 'Choose a day to help'
              : '${_titleCase(latestAvailability.status)} request',
          icon: Icons.calendar_month_outlined,
          iconBackground: ModulePalettes.volunteers.iconBackground,
          iconColor: ModulePalettes.volunteers.primary,
          onTap: _openVolunteerAvailability,
        ),
      ];
    }

    if (auth.isMember) {
      return [
        patients,
        _HomeMetricAction(
          title: 'Home visits',
          value: _formatMetric(_upcomingHomeVisitCount),
          subtitle: _nextHomeVisitLabel(),
          icon: Icons.home_outlined,
          iconBackground: ModulePalettes.homeVisits.iconBackground,
          iconColor: ModulePalettes.homeVisits.primary,
          onTap: () => _openHomeVisits(auth),
        ),
      ];
    }

    final needsReview = _assessmentReviewCount;
    return [
      patients,
      _HomeMetricAction(
        title: 'Visit\nAssessment',
        value: _formatMetric(needsReview),
        subtitle: needsReview == 0 ? 'All reviewed' : 'need review',
        icon: Icons.assignment_outlined,
        iconBackground: ModulePalettes.patients.iconBackground,
        iconColor: ModulePalettes.patients.primary,
        onTap: () => _openVisitAssessment(auth),
      ),
    ];
  }

  Widget _buildQuickActions(BuildContext context, AuthService auth) {
    final actions = _quickActionsFor(auth);
    if (actions.isEmpty) {
      return const _HomeQuickChip(
        label: 'No links available',
        icon: Icons.lock_outline_rounded,
      );
    }

    final chips = actions
        .map(
          (action) => _HomeQuickChip(
            label: action.label,
            icon: action.icon,
            iconBackground: action.iconBackground,
            iconColor: action.iconColor,
            onTap: action.onTap,
          ),
        )
        .toList();
    final usesTwoRows = auth.isAdmin || auth.isStaff || auth.isMember;

    if (usesTwoRows) {
      return SizedBox(
        height: 104,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Wrap(
            direction: Axis.vertical,
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: chips,
          ),
        ),
      );
    }

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) => chips[index],
      ),
    );
  }

  List<_HomeQuickAction> _quickActionsFor(AuthService auth) {
    final actions = <_HomeQuickAction>[];
    void add(
      bool visible,
      String label,
      IconData icon,
      ModulePalette palette,
      VoidCallback onTap,
    ) {
      if (visible) {
        actions.add(
          _HomeQuickAction(
            label: label,
            icon: icon,
            iconBackground: palette.iconBackground,
            iconColor: palette.primary,
            onTap: onTap,
          ),
        );
      }
    }

    add(
      !auth.isMember && auth.canAccessHomeVisits,
      'Home visit',
      Icons.home_outlined,
      ModulePalettes.homeVisits,
      () => _openHomeVisits(auth),
    );
    add(
      auth.canAccessSocialSupport,
      'Social support',
      Icons.favorite_border_rounded,
      ModulePalettes.socialSupport,
      _openSocialSupport,
    );
    if (!auth.isMember && !auth.isVolunteer) {
      add(
        auth.canAccessEquipmentDistribution,
        'Equipment supply',
        Icons.medical_services_outlined,
        ModulePalettes.equipmentSupply,
        _openEquipmentSupply,
      );
      add(
        auth.canAccessMedicineSupply,
        'Medicine supply',
        Icons.medication_outlined,
        ModulePalettes.medicineSupply,
        _openMedicineSupply,
      );
    }
    add(
      auth.canAccessVolunteers,
      'Volunteers',
      Icons.volunteer_activism_outlined,
      ModulePalettes.volunteers,
      _openVolunteers,
    );
    if (!auth.isVolunteer) {
      add(
        auth.canAccessReports,
        'Reports',
        Icons.bar_chart_rounded,
        ModulePalettes.reports,
        _openReports,
      );
    }
    add(
      auth.isAdmin,
      'Staff management',
      Icons.manage_accounts_outlined,
      ModulePalettes.patients,
      _openStaffManagement,
    );
    return actions;
  }

  Widget _buildRoleActivitySection(BuildContext context, AuthService auth) {
    if (auth.isVolunteer) return _buildVolunteerHomeTasks(context);
    if (auth.isAdmin) return _buildAdminAttentionSection(context);
    return _buildLatestNotificationsSection(context);
  }

  Widget _buildAdminAttentionSection(BuildContext context) {
    final registrationCount = _importantRequestsLoading
        ? null
        : _pendingVolunteerRegistrationCount;
    final availabilityCount = _importantRequestsLoading
        ? null
        : _pendingAvailabilityRequestCount;
    final equipmentCount = _activeSuppliesLoading
        ? null
        : _activeSupplies.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHomeSectionHeader(context, title: 'Needs your attention'),
        const SizedBox(height: AppSpacing.sm),
        _HomeActivityCard(
          icon: Icons.person_outline_rounded,
          iconBackground: ModulePalettes.volunteers.iconBackground,
          iconColor: ModulePalettes.volunteers.primary,
          title: 'Volunteer registrations',
          subtitle: registrationCount == null
              ? 'Checking requests…'
              : '$registrationCount new ${registrationCount == 1 ? 'request' : 'requests'}',
          actionLabel: 'Review',
          actionBackgroundColor: ModulePalettes.volunteers.iconBackground,
          actionForegroundColor: ModulePalettes.volunteers.primary,
          onTap: _openVolunteerRegistrationRequests,
        ),
        const SizedBox(height: AppSpacing.xs),
        _HomeActivityCard(
          icon: Icons.calendar_month_outlined,
          iconBackground: ModulePalettes.volunteers.iconBackground,
          iconColor: ModulePalettes.volunteers.primary,
          title: 'Availability requests',
          subtitle: availabilityCount == null
              ? 'Checking requests…'
              : '$availabilityCount pending ${availabilityCount == 1 ? 'request' : 'requests'}',
          actionLabel: 'Review',
          actionBackgroundColor: ModulePalettes.volunteers.iconBackground,
          actionForegroundColor: ModulePalettes.volunteers.primary,
          onTap: _openAvailabilityRequestsAdmin,
        ),
        const SizedBox(height: AppSpacing.xs),
        _HomeActivityCard(
          icon: Icons.medical_services_outlined,
          iconBackground: ModulePalettes.equipmentSupply.iconBackground,
          iconColor: ModulePalettes.equipmentSupply.primary,
          title: 'Equipment distributed',
          subtitle: equipmentCount == null
              ? 'Checking equipment…'
              : '$equipmentCount ${equipmentCount == 1 ? 'item' : 'items'} currently out',
          actionLabel: 'View',
          actionBackgroundColor: ModulePalettes.equipmentSupply.iconBackground,
          actionForegroundColor: ModulePalettes.equipmentSupply.primary,
          onTap: _openEquipmentSupply,
        ),
      ],
    );
  }

  Widget _buildLatestNotificationsSection(BuildContext context) {
    final visible = _notifications.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHomeSectionHeader(
          context,
          title: 'Latest notifications',
          actionLabel: visible.isEmpty ? null : 'View all',
          onAction: visible.isEmpty ? null : _openNotifications,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_notificationsLoading && visible.isEmpty)
          const _HomeActivityCard(
            icon: Icons.notifications_none_rounded,
            title: 'Checking notifications',
            subtitle: 'Loading the latest care updates…',
          )
        else if (visible.isEmpty)
          const _HomeActivityCard(
            icon: Icons.notifications_none_rounded,
            title: 'You are all caught up',
            subtitle: 'New care updates will appear here.',
          )
        else
          for (var index = 0; index < visible.length; index++) ...[
            if (index > 0) const SizedBox(height: AppSpacing.xs),
            _HomeActivityCard(
              icon: _notificationIcon(visible[index]),
              iconBackground: _notificationColor(
                visible[index],
              ).withValues(alpha: 0.1),
              iconColor: _notificationColor(visible[index]),
              title: visible[index].title,
              subtitle: visible[index].message,
              actionLabel: _notificationActionLabel(visible[index]),
              actionTone: _notificationActionTone(visible[index]),
              onTap: () => _handleNotificationTap(visible[index]),
            ),
          ],
      ],
    );
  }

  Widget _buildVolunteerHomeTasks(BuildContext context) {
    final items = _volunteerTaskWidgets();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHomeSectionHeader(
          context,
          title: 'My tasks',
          actionLabel: 'View all',
          onAction: () => _openHomeVisits(context.read<AuthService>()),
        ),
        const SizedBox(height: AppSpacing.sm),
        _HomeTaskTabs(
          selectedIndex: _selectedVolunteerTaskTab,
          onSelected: (index) {
            setState(() => _selectedVolunteerTaskTab = index);
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        if ((_assignmentsLoading || _availabilityRequestsLoading) &&
            items.isEmpty)
          const _HomeActivityCard(
            icon: Icons.schedule_rounded,
            title: 'Loading your tasks',
            subtitle: 'Checking assignments and availability…',
          )
        else if (items.isEmpty)
          _HomeActivityCard(
            icon: Icons.task_alt_rounded,
            title: _selectedVolunteerTaskTab == 2
                ? 'No completed tasks yet'
                : 'Nothing scheduled here',
            subtitle: _selectedVolunteerTaskTab == 0
                ? 'Your day is clear.'
                : 'New tasks will appear when they are assigned.',
          )
        else
          for (var index = 0; index < items.length && index < 3; index++) ...[
            if (index > 0) const SizedBox(height: AppSpacing.xs),
            items[index],
          ],
      ],
    );
  }

  List<Widget> _volunteerTaskWidgets() {
    final today = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(today);
    final assignments = switch (_selectedVolunteerTaskTab) {
      0 => [..._overdueAssignments, ..._todayAssignments],
      1 => _upcomingAssignments,
      _ => _completedAssignments,
    };
    final availability = _availabilityRequests.where((request) {
      final requestDate = DateTime.tryParse(request.requestedDate);
      if (_selectedVolunteerTaskTab == 0) {
        return request.requestedDate == todayKey;
      }
      if (_selectedVolunteerTaskTab == 1) {
        return requestDate != null &&
            requestDate.isAfter(DateTime(today.year, today.month, today.day));
      }
      return (requestDate != null && requestDate.isBefore(today)) ||
          request.status == 'rejected';
    });

    return [
      for (final assignment in assignments)
        _buildVolunteerAssignmentHomeCard(assignment),
      for (final request in availability) _buildAvailabilityHomeCard(request),
    ];
  }

  Widget _buildVolunteerAssignmentHomeCard(VolunteerAssignment assignment) {
    final palette = switch (assignment.taskType) {
      'social_support' => ModulePalettes.socialSupport,
      'visit_assessment' => ModulePalettes.patients,
      _ => ModulePalettes.homeVisits,
    };
    return _HomeActivityCard(
      icon: assignment.taskType == 'social_support'
          ? Icons.favorite_border_rounded
          : assignment.taskType == 'visit_assessment'
          ? Icons.assignment_outlined
          : Icons.home_outlined,
      iconBackground: palette.iconBackground,
      iconColor: palette.primary,
      title: '${assignment.typeLabel} · ${assignment.patient.name}',
      subtitle: _assignmentSubtitle(assignment),
      actionLabel: assignment.canAccept ? 'Accept' : assignment.statusLabel,
      actionTone: assignment.status == 'completed'
          ? _HomeActionTone.success
          : _HomeActionTone.neutral,
      actionBackgroundColor: assignment.canAccept
          ? palette.iconBackground
          : null,
      actionForegroundColor: assignment.canAccept ? palette.primary : null,
      loading: _updatingAssignmentIds.contains(assignment.id),
      onTap: assignment.canAccept
          ? () => _acceptVolunteerAssignment(assignment)
          : () => _openAssignmentDetail(assignment),
    );
  }

  Widget _buildAvailabilityHomeCard(VolunteerAvailabilityRequest request) {
    final isNeutral = VolunteerRequestMessages.isNeutralStatus(request.status);
    return _HomeActivityCard(
      icon: Icons.calendar_month_outlined,
      iconBackground: ModulePalettes.volunteers.iconBackground,
      iconColor: ModulePalettes.volunteers.primary,
      title: 'Availability · ${_formatAvailabilityDate(request)}',
      subtitle: request.status == 'approved'
          ? 'Confirmed by coordinator'
          : isNeutral
          ? VolunteerRequestMessages.getPositiveMessage(
              taskType: request.taskType,
              status: request.status,
            )
          : 'Sent to coordinator',
      actionLabel: VolunteerRequestMessages.getStatusLabel(request.status),
      actionTone: request.status == 'approved'
          ? _HomeActionTone.success
          : isNeutral
          ? _HomeActionTone.neutral
          : _HomeActionTone.warning,
      onTap: _openVolunteerAvailability,
    );
  }

  Widget _buildHomeSectionHeader(
    BuildContext context, {
    required String title,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: _homeCompactSectionTitleStyle(context)),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: _homeMuted,
              minimumSize: const Size(48, 36),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            ),
            child: Text(actionLabel),
          ),
      ],
    );
  }

  TextStyle _homeSectionTitleStyle(BuildContext context) {
    return const TextStyle(
      color: _homeInk,
      fontSize: 20,
      height: 1.1,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.35,
    ).copyWith(fontFamilyFallback: const ['NotoSansMalayalam']);
  }

  TextStyle _homeCompactSectionTitleStyle(BuildContext context) {
    return _homeSectionTitleStyle(
      context,
    ).copyWith(color: _homeMuted, fontSize: 16);
  }

  String _formatMetric(int? value) {
    if (value == null) return '—';
    return value < 10 ? value.toString().padLeft(2, '0') : value.toString();
  }

  String _nextHomeVisitLabel() {
    final next = _nextHomeVisitDate;
    if (next == null) return 'No upcoming visits';
    final now = DateTime.now();
    final isToday =
        next.year == now.year && next.month == now.month && next.day == now.day;
    return isToday
        ? 'Next: today${DateFormat('h:mm a').format(next) == '12:00 AM' ? '' : ', ${DateFormat('h:mm a').format(next)}'}'
        : 'Next: ${DateFormat('EEE, d MMM').format(next)}';
  }

  VolunteerAvailabilityRequest? _latestFutureAvailabilityRequest() {
    final today = DateTime.now();
    for (final request in _availabilityRequests) {
      final date = DateTime.tryParse(request.requestedDate);
      if (date != null &&
          !date.isBefore(DateTime(today.year, today.month, today.day)) &&
          request.status != 'rejected') {
        return request;
      }
    }
    return null;
  }

  String _assignmentSubtitle(VolunteerAssignment assignment) {
    final date = DateTime.tryParse(assignment.scheduledDate);
    final dateLabel = date == null
        ? assignment.scheduledDate
        : DateFormat('h:mm a · d MMM').format(date);
    final address = assignment.patient.address.trim();
    return address.isEmpty ? dateLabel : '$dateLabel · $address';
  }

  String _formatAvailabilityDate(VolunteerAvailabilityRequest request) {
    final date = DateTime.tryParse(request.requestedDate);
    return date == null
        ? request.requestedDate
        : DateFormat('EEE, d MMM').format(date);
  }

  String _titleCase(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return value;
    return '${trimmed[0].toUpperCase()}${trimmed.substring(1).toLowerCase()}';
  }

  String _notificationActionLabel(AppNotification notification) {
    return switch (notification.severity) {
      'danger' => 'Alert',
      'warning' => 'Due',
      'success' => 'New',
      _ => 'Open',
    };
  }

  _HomeActionTone _notificationActionTone(AppNotification notification) {
    return switch (notification.severity) {
      'danger' => _HomeActionTone.danger,
      'warning' => _HomeActionTone.warning,
      'success' => _HomeActionTone.success,
      _ => _HomeActionTone.neutral,
    };
  }

  Future<void> _openPage(Widget page, {VoidCallback? after}) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
    if (mounted) after?.call();
  }

  void _openPatients(AuthService auth) {
    if (!FeaturePermissionMiddleware.ensure(
      context,
      AppFeature.patients,
      moduleName: 'Patients',
    )) {
      return;
    }
    _openPage(
      const ModuleTheme(
        palette: ModulePalettes.patients,
        child: PatientListPage(),
      ),
      after: () => _loadHomeSummary(auth),
    );
  }

  void _openVisitAssessment(AuthService auth) {
    if (!FeaturePermissionMiddleware.ensure(
      context,
      AppFeature.nhcAssessment,
      moduleName: 'Visit Assessment',
    )) {
      return;
    }
    _openPage(
      const VisitAssessmentVisitPickerScreen(),
      after: () => _loadHomeSummary(auth),
    );
  }

  void _openHomeVisits(AuthService auth) {
    if (!FeaturePermissionMiddleware.ensure(
      context,
      AppFeature.homeVisits,
      moduleName: 'Home Visits',
    )) {
      return;
    }
    _openPage(
      const ModuleTheme(
        palette: ModulePalettes.homeVisits,
        child: HomeVisitListPage(),
      ),
      after: () {
        _loadHomeSummary(auth);
        if (auth.isVolunteer) _loadVolunteerAssignments();
      },
    );
  }

  void _openSocialSupport() {
    _openPage(
      const ModuleTheme(
        palette: ModulePalettes.socialSupport,
        child: SocialSupportListPage(),
      ),
    );
  }

  void _openEquipmentSupply() {
    _openPage(
      const ModuleTheme(
        palette: ModulePalettes.equipmentSupply,
        child: EquipmentSupplyListPage(),
      ),
      after: _loadActiveSupplies,
    );
  }

  void _openMedicineSupply() {
    _openPage(
      const ModuleTheme(
        palette: ModulePalettes.medicineSupply,
        child: MedicineSupplyListPage(),
      ),
    );
  }

  void _openVolunteers() {
    _openPage(
      const ModuleTheme(
        palette: ModulePalettes.volunteers,
        child: VolunteerListPage(),
      ),
    );
  }

  void _openReports() {
    _openPage(
      const ModuleTheme(palette: ModulePalettes.reports, child: ReportsPage()),
    );
  }

  void _openStaffManagement() {
    _openPage(const ConfigPage(mode: ConfigPageMode.staff));
  }

  void _openVolunteerAvailability() {
    _openPage(
      const VolunteerAvailabilityPage(),
      after: _loadVolunteerAvailabilityRequests,
    );
  }

  void _openAvailabilityRequestsAdmin() {
    _openPage(
      const VolunteerAvailabilityRequestsAdminPage(),
      after: _loadImportantRequests,
    );
  }

  Future<void> _acceptVolunteerAssignment(
    VolunteerAssignment assignment,
  ) async {
    if (_updatingAssignmentIds.contains(assignment.id)) return;
    setState(() => _updatingAssignmentIds.add(assignment.id));
    try {
      await VolunteerAssignmentService.updateStatus(assignment.id, 'accepted');
      if (!mounted) return;
      await _loadVolunteerAssignments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assignment accepted'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingAssignmentIds.remove(assignment.id));
      }
    }
  }

  Widget _buildLegacyHome(BuildContext context) {
    final auth = context.watch<AuthService>();
    final isPendingApproval = auth.isVolunteer && !auth.isVolunteerApproved;
    final maintenanceNotification = !auth.isAdmin || auth.isTrialUnit
        ? null
        : _visibleMaintenanceDueNotification();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < AppBreakpoints.tablet;
    final horizontalPadding = isCompact ? AppSpacing.md : AppSpacing.lg;

    return Container(
      decoration: auth.isVolunteer
          ? const BoxDecoration(color: AppColors.background)
          : const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFD8ECFD),
                  Color(0xFFDEF5EB),
                  Color(0xFFF5EDFA),
                  Color(0xFFEDF4FA),
                ],
                stops: [0.0, 0.35, 0.70, 1.0],
              ),
            ),
      child: AdaptiveAppScaffold(
        scaffoldKey: _scaffoldKey,
        drawer: isPendingApproval ? null : _buildProfessionalDrawer(context),
        backgroundColor: Colors.transparent,
        currentSection: isPendingApproval ? null : AppBottomSection.home,
        onNavigationSelected: isPendingApproval
            ? null
            : _handleBottomNavigation,
        contentMaxWidth: 1040,
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () => _bootstrapAccess(force: true),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                isCompact ? AppSpacing.sm : AppSpacing.md,
                horizontalPadding,
                AppSpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDashboardHeader(context, auth, isCompact: isCompact),
                  if (isPendingApproval) ...[
                    const SizedBox(height: AppSpacing.md),
                    _buildVolunteerApprovalCard(auth),
                    if (auth.isVolunteerPending) ...[
                      const SizedBox(height: AppSpacing.md),
                      _buildPendingVolunteerStoryCard(),
                    ],
                  ] else ...[
                    if (maintenanceNotification != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _buildMaintenanceDueBanner(
                        context,
                        maintenanceNotification,
                      ),
                    ],
                    if (auth.isVolunteer) ...[
                      const SizedBox(height: AppSpacing.md),
                      _buildVolunteerAvailabilityCallout(context),
                      const SizedBox(height: AppSpacing.md),
                      _buildVolunteerTasksSection(context),
                    ],
                    if (auth.isAdmin &&
                        _pendingVolunteerRegistrationCount > 0) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _buildImportantRequestsSection(context),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final columns = width >= 900
                            ? 4
                            : width >= 620
                            ? 3
                            : 2;
                        final cards = <Widget>[
                          if (auth.canAccessPatients)
                            _buildModernActionCard(
                              context,
                              title: 'Patients',
                              icon: Icons.people_alt_rounded,
                              palette: ModulePalettes.patients,
                              page: const ModuleTheme(
                                palette: ModulePalettes.patients,
                                child: PatientListPage(),
                              ),
                            ),
                          if (auth.canAccessNHC)
                            _buildModernActionCard(
                              context,
                              title: 'Visit Assessment',
                              icon: Icons.assignment_rounded,
                              palette: ModulePalettes.patients,
                              page: const VisitAssessmentVisitPickerScreen(),
                            ),
                          if (auth.canAccessEquipmentDistribution)
                            _buildModernActionCard(
                              context,
                              title: 'Equipment Supply',
                              icon: Icons.wheelchair_pickup_rounded,
                              palette: ModulePalettes.equipmentSupply,
                              page: const ModuleTheme(
                                palette: ModulePalettes.equipmentSupply,
                                child: EquipmentSupplyListPage(),
                              ),
                            ),
                          if (auth.canAccessMedicineSupply)
                            _buildModernActionCard(
                              context,
                              title: 'Medicine Supply',
                              icon: Icons.medication_liquid_rounded,
                              palette: ModulePalettes.medicineSupply,
                              page: const ModuleTheme(
                                palette: ModulePalettes.medicineSupply,
                                child: MedicineSupplyListPage(),
                              ),
                            ),
                          if (auth.canAccessHomeVisits)
                            _buildModernActionCard(
                              context,
                              title: 'Home Visits',
                              icon: Icons.home_rounded,
                              palette: ModulePalettes.homeVisits,
                              page: const ModuleTheme(
                                palette: ModulePalettes.homeVisits,
                                child: HomeVisitListPage(),
                              ),
                            ),
                          if (auth.canAccessSocialSupport)
                            _buildModernActionCard(
                              context,
                              title: 'Social Support',
                              icon: Icons.food_bank_rounded,
                              palette: ModulePalettes.socialSupport,
                              page: const ModuleTheme(
                                palette: ModulePalettes.socialSupport,
                                child: SocialSupportListPage(),
                              ),
                            ),
                          if (auth.canAccessVolunteers)
                            _buildModernActionCard(
                              context,
                              title: 'Volunteers',
                              icon: Icons.volunteer_activism_rounded,
                              palette: ModulePalettes.volunteers,
                              page: const ModuleTheme(
                                palette: ModulePalettes.volunteers,
                                child: VolunteerListPage(),
                              ),
                            ),
                          if (auth.canAccessReports)
                            _buildModernActionCard(
                              context,
                              title: 'Reports',
                              icon: Icons.assessment_outlined,
                              palette: ModulePalettes.reports,
                              page: const ModuleTheme(
                                palette: ModulePalettes.reports,
                                child: ReportsPage(),
                              ),
                            ),
                        ];

                        if (cards.isEmpty) {
                          return const AppCard(
                            surfaceLevel: AppSurfaceLevel.elevated,
                            child: AppEmptyState(
                              icon: Icons.lock_outline_rounded,
                              title: 'No modules enabled',
                              message:
                                  'Your unit administrator can enable care modules for this account.',
                            ),
                          );
                        }

                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: columns,
                          crossAxisSpacing: isCompact
                              ? AppSpacing.sm
                              : AppSpacing.md,
                          mainAxisSpacing: isCompact
                              ? AppSpacing.sm
                              : AppSpacing.md,
                          childAspectRatio: columns >= 4
                              ? 1.42
                              : columns == 3
                              ? 1.28
                              : 1.15,
                          children: cards,
                        );
                      },
                    ),
                    if (auth.canAccessEquipmentDistribution) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Expanded(
                            child: Text(
                              'Equipment currently assigned to patients.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ModuleTheme(
                                    palette: ModulePalettes.equipmentSupply,
                                    child: EquipmentSupplyListPage(),
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Text(
                                'View all',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _buildActiveSuppliesList(context),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  AppNotification? _visibleMaintenanceDueNotification() {
    for (final notification in _notifications) {
      if (notification.type != 'maintenance_due') continue;
      if (_dismissedMaintenanceBannerKeys.contains(
        _maintenanceNotificationKey(notification),
      )) {
        continue;
      }
      return notification;
    }
    return null;
  }

  String _maintenanceNotificationKey(AppNotification notification) {
    return notification.id ??
        notification.entityId ??
        notification.metadata['periodKey']?.toString() ??
        notification.message;
  }

  Widget _buildMaintenanceDueBanner(
    BuildContext context,
    AppNotification notification,
  ) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.16),
              borderRadius: AppRadius.md,
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: textTheme.titleSmall?.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  notification.message,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BillingPlanScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.receipt_long_outlined, size: 14),
                  label: const Text('View Billing & Plan'),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () {
              setState(() {
                _dismissedMaintenanceBannerKeys.add(
                  _maintenanceNotificationKey(notification),
                );
              });
            },
            icon: const Icon(Icons.close_rounded),
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  String _getGreeting(AuthService auth) {
    if (auth.isFirstLogin) {
      return 'Welcome to';
    }
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  Widget _buildDashboardHeader(
    BuildContext context,
    AuthService auth, {
    bool isCompact = false,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final isPendingApproval = auth.isVolunteer && !auth.isVolunteerApproved;
    final compactVolunteer = auth.isVolunteer;
    final compactHeader = compactVolunteer || isCompact;
    final canOpenOurStory = auth.hasAboutUs || auth.isVolunteer;
    final achievementTier = _volunteerActivity?.achievementTier;
    final achievementColor = achievementTier == null
        ? null
        : _achievementColor(achievementTier);

    return AppCard(
      surfaceLevel: AppSurfaceLevel.elevated,
      backgroundColor: compactVolunteer && achievementTier != null
          ? _achievementSurfaceColor(achievementTier)
          : null,
      borderColor: compactVolunteer && achievementColor != null
          ? achievementColor.withValues(alpha: 0.24)
          : null,
      padding: EdgeInsets.all(compactHeader ? AppSpacing.md : AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildShellIconButton(
                tooltip: isPendingApproval ? 'Menu disabled' : 'Open menu',
                icon: Icons.menu_rounded,
                onTap: isPendingApproval
                    ? null
                    : () => _scaffoldKey.currentState?.openDrawer(),
                compact: compactHeader,
              ),
              const Spacer(),
              if (auth.unitSupportQr != null && !isPendingApproval) ...[
                _buildShellIconButton(
                  tooltip: 'Show QR',
                  icon: Icons.qr_code_2_rounded,
                  onTap: () => _showQRModal(context),
                  compact: compactHeader,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              _buildShellIconButton(
                tooltip: isPendingApproval
                    ? 'Notifications unavailable'
                    : 'Notifications',
                icon: Icons.notifications_none_rounded,
                onTap: isPendingApproval ? null : _openNotifications,
                badgeLabel: isPendingApproval || _notificationCount <= 0
                    ? null
                    : (_notificationCount > 99
                          ? '99+'
                          : _notificationCount.toString()),
                compact: compactHeader,
              ),
              if (auth.canCreate) ...[
                const SizedBox(width: AppSpacing.xs),
                _buildShellIconButton(
                  tooltip: 'Quick add',
                  icon: Icons.add_rounded,
                  onTap: _showQuickAddOptions,
                  compact: compactHeader,
                ),
              ],
              const SizedBox(width: AppSpacing.xs),
              GestureDetector(
                onTap: () => _showUserProfile(context),
                child: UnitBrandAvatar(
                  size: compactHeader ? 40 : 44,
                  preferAppIcon: true,
                  backgroundColor: AppColors.primaryLight,
                  iconColor: AppColors.primary,
                  border: Border.all(color: AppColors.border),
                  fallbackIcon: Icons.person_rounded,
                ),
              ),
            ],
          ),
          SizedBox(height: compactHeader ? AppSpacing.sm : AppSpacing.lg),
          Text(
            _getGreeting(auth),
            style: textTheme.labelLarge?.copyWith(
              fontSize: compactHeader ? 12 : null,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          InkWell(
            onTap: canOpenOurStory ? _navigateToAboutUs : null,
            borderRadius: AppRadius.sm,
            child: SizedBox(
              width: double.infinity,
              child: Text(
                auth.unitName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  textStyle: compactHeader
                      ? textTheme.titleLarge
                      : textTheme.headlineMedium,
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  height: 1.15,
                ).copyWith(fontFamilyFallback: const ['NotoSansMalayalam']),
              ),
            ),
          ),
          SizedBox(height: compactHeader ? AppSpacing.xs : AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _ShellStatusPill(
                      label: auth.unitLocation,
                      icon: Icons.location_on_outlined,
                      color: AppColors.primary,
                    ),
                    if (auth.isVolunteer && _volunteerActivity != null)
                      _ShellStatusPill(
                        label: _volunteerActivity!.achievementTier,
                        icon: Icons.workspace_premium_outlined,
                        color: _achievementColor(
                          _volunteerActivity!.achievementTier,
                        ),
                      ),
                  ],
                ),
              ),
              if (canOpenOurStory) ...[
                const SizedBox(width: AppSpacing.sm),
                _buildOurStoryBadge(context),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _navigateToAboutUs() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AboutUsPage()),
    );
  }

  Widget _buildOurStoryBadge(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _navigateToAboutUs,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D9488).withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_stories_rounded,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 5),
              Text(
                'Our Story',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 10,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShellIconButton({
    required String tooltip,
    required IconData icon,
    VoidCallback? onTap,
    String? badgeLabel,
    bool compact = false,
  }) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled
            ? AppColors.surface1
            : AppColors.surface1.withValues(alpha: 0.5),
        borderRadius: AppRadius.md,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.md,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox.square(dimension: compact ? 40 : 44),
              Positioned.fill(
                child: Icon(
                  icon,
                  color: enabled ? AppColors.text : AppColors.textMuted,
                  size: AppIcons.large,
                ),
              ),
              if (badgeLabel != null)
                Positioned(
                  right: -3,
                  top: -5,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: AppRadius.md,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      badgeLabel,
                      style: const TextStyle(
                        color: AppColors.textInverse,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardSectionHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
    bool compact = false,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _homeCompactSectionTitleStyle(context)),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                subtitle,
                style: (compact ? textTheme.bodySmall : textTheme.bodyMedium)
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: AppSpacing.md),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ],
    );
  }

  Widget _buildModernActionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required ModulePalette palette,
    required Widget page,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
        if (title == "Equipment Supply") {
          _loadActiveSupplies();
        }
      },
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: palette.primary.withValues(alpha: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: palette.iconBackground,
              borderRadius: AppRadius.md,
            ),
            child: Icon(icon, color: palette.primary, size: AppIcons.large),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.arrow_forward_rounded,
                color: palette.primary,
                size: AppIcons.normal,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSuppliesList(BuildContext context) {
    if (_activeSuppliesLoading) {
      return const AppCard(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            AppSkeletonBox(width: 56, height: 56, borderRadius: AppRadius.md),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeletonBox(width: double.infinity, height: 16),
                  SizedBox(height: AppSpacing.xs),
                  AppSkeletonBox(width: 180, height: 13),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_activeSupplies.isEmpty) {
      return const AppCard(
        padding: EdgeInsets.zero,
        child: AppEmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'No active supplies',
          message: 'Equipment assigned to patients will appear here.',
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = _activeSupplyCardWidth(constraints.maxWidth);
        final visibleCount = _activeSuppliesVisibleCount(constraints.maxWidth);
        final indicatorCount = (_activeSupplies.length - visibleCount + 1)
            .clamp(1, _activeSupplies.length)
            .toInt();

        return Column(
          children: [
            SizedBox(
              height: 142,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.axis != Axis.horizontal) {
                    return false;
                  }
                  final next =
                      (notification.metrics.pixels /
                              (cardWidth + AppSpacing.md))
                          .round()
                          .clamp(0, indicatorCount - 1)
                          .toInt();
                  if (next != _activeSuppliesPageIndex) {
                    setState(() => _activeSuppliesPageIndex = next);
                  }
                  return false;
                },
                child: ListView.builder(
                  controller: _activeSuppliesScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _activeSupplies.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.only(
                        right: index == _activeSupplies.length - 1
                            ? 0
                            : AppSpacing.md,
                      ),
                      child: SizedBox(
                        width: cardWidth,
                        child: _activeSupplyCard(_activeSupplies[index]),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (indicatorCount > 1) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  indicatorCount,
                  (index) => AnimatedContainer(
                    duration: AppMotion.normal,
                    curve: AppMotion.easeOutCubic,
                    width: _activeSuppliesPageIndex == index ? 16 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: _activeSuppliesPageIndex == index
                          ? AppColors.primary
                          : AppColors.borderStrong,
                      borderRadius: AppRadius.xs,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  double _activeSupplyCardWidth(double availableWidth) {
    if (availableWidth >= 680) {
      return (availableWidth - 12) / 2;
    }
    return availableWidth * 0.78;
  }

  int _activeSuppliesVisibleCount(double availableWidth) {
    return availableWidth >= 680 ? 2 : 1;
  }

  Widget _activeSupplyCard(EquipmentSupply supply) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: AppColors.warning.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppSemanticColors.background(
                    AppSemanticStatus.warning,
                  ),
                  borderRadius: AppRadius.md,
                ),
                child: const Icon(
                  Icons.medical_services_outlined,
                  color: AppColors.warning,
                  size: AppIcons.normal,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  supply.equipmentName,
                  style: textTheme.titleSmall?.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Column(
            children: [
              _buildInfoRow(
                Icons.person_outline_rounded,
                _supplyRecipientName(supply),
              ),
              const SizedBox(height: AppSpacing.xs),
              _buildInfoRow(
                Icons.calendar_today_outlined,
                _formatSupplyDate(supply.supplyDate),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatSupplyDate(DateTime date) {
    return DateFormat('d MMM yyyy').format(date);
  }

  Color _notificationColor(AppNotification notification) {
    switch (notification.severity) {
      case 'danger':
        return AppColors.danger;
      case 'warning':
        return AppColors.warning;
      case 'success':
        return AppColors.success;
      default:
        return AppColors.primary;
    }
  }

  IconData _notificationIcon(AppNotification notification) {
    switch (notification.type) {
      case 'equipment_overdue':
        return Icons.inventory_2_outlined;
      case 'medicine_expiry_60':
      case 'medicine_expiry_30':
        return Icons.medication_outlined;
      case 'subscription_renewal':
        return Icons.event_repeat_outlined;
      case 'subscription_paid':
        return Icons.payments_outlined;
      case 'maintenance_due':
        return Icons.home_repair_service_outlined;
      case 'billing_due':
        return Icons.receipt_long_outlined;
      case 'volunteer_availability_request':
        return Icons.how_to_reg_outlined;
      case 'volunteer_assignment':
        return Icons.assignment_turned_in_outlined;
      case 'volunteer_availability_update':
        return Icons.volunteer_activism_outlined;
      case 'volunteer_registration':
        return Icons.person_add_alt_1_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  bool _isBillingNotification(AppNotification notification) {
    return notification.type == 'maintenance_due' ||
        notification.type == 'billing_due' ||
        notification.type == 'subscription_renewal' ||
        notification.type == 'subscription_paid';
  }

  String _formatNotificationTime(DateTime? date) {
    if (date == null) return 'Just now';

    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes} min ago';
    if (difference.inDays < 1) return '${difference.inHours} hours ago';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return DateFormat('d MMM yyyy').format(date);
  }

  String _supplyRecipientName(EquipmentSupply supply) {
    return _firstNonEmpty([
          supply.patientName,
          supply.receiverName,
          supply.careOf,
        ]) ??
        'Unknown';
  }

  String? _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        const SizedBox(width: 1),
        Icon(icon, size: AppIcons.small, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildProfessionalDrawer(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.user;
    final userName = (user?['name']?.toString().trim().isNotEmpty ?? false)
        ? user!['name'].toString()
        : auth.unitName;
    final userDetail = (user?['email']?.toString().trim().isNotEmpty ?? false)
        ? user!['email'].toString()
        : 'Healthcare Management';
    final drawerWidth = MediaQuery.sizeOf(context).width > 520
        ? 360.0
        : MediaQuery.sizeOf(context).width * 0.88;

    return Drawer(
      width: drawerWidth,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(AppRadius.sheetValue),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  UnitBrandAvatar(
                    size: 56,
                    preferAppIcon: true,
                    backgroundColor: AppColors.primaryLight,
                    iconColor: AppColors.primary,
                    border: Border.all(color: AppColors.border),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello,',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppColors.text,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        Text(
                          userDetail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close menu',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                children: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.home_outlined,
                    title: "Dashboard",
                    onTap: () => Navigator.pop(context),
                    isSelected: true,
                  ),
                  if (auth.isAdmin)
                    _buildDrawerItem(
                      context,
                      icon: Icons.manage_accounts_outlined,
                      title: 'Staff Management',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const ConfigPage(mode: ConfigPageMode.staff),
                          ),
                        );
                      },
                    ),
                  if (auth.canAccessPatients)
                    _buildDrawerItem(
                      context,
                      icon: Icons.people_outline_rounded,
                      title: "Patients",
                      color: ModulePalettes.patients.primary,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ModuleTheme(
                              palette: ModulePalettes.patients,
                              child: PatientListPage(),
                            ),
                          ),
                        );
                      },
                    ),
                  if (auth.canAccessPatients)
                    _buildDrawerItem(
                      context,
                      icon: Icons.person_off_outlined,
                      title: "Passed Away Patients",
                      color: ModulePalettes.patients.primary,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ModuleTheme(
                              palette: ModulePalettes.patients,
                              child: DeceasedPatientListPage(),
                            ),
                          ),
                        );
                      },
                    ),
                  if (auth.canAccessHomeVisits)
                    _buildDrawerItem(
                      context,
                      icon: Icons.home_work_outlined,
                      title: "Home Visits",
                      color: ModulePalettes.homeVisits.primary,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ModuleTheme(
                              palette: ModulePalettes.homeVisits,
                              child: HomeVisitListPage(),
                            ),
                          ),
                        );
                      },
                    ),
                  if (auth.canAccessSocialSupport)
                    _buildDrawerItem(
                      context,
                      icon: Icons.food_bank_outlined,
                      title: "Social Support",
                      color: ModulePalettes.socialSupport.primary,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ModuleTheme(
                              palette: ModulePalettes.socialSupport,
                              child: SocialSupportListPage(),
                            ),
                          ),
                        );
                      },
                    ),
                  if (auth.canAccessVolunteers)
                    _buildDrawerItem(
                      context,
                      icon: Icons.volunteer_activism_outlined,
                      title: "Volunteers",
                      color: ModulePalettes.volunteers.primary,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ModuleTheme(
                              palette: ModulePalettes.volunteers,
                              child: VolunteerListPage(),
                            ),
                          ),
                        );
                      },
                    ),
                  if (auth.canAccessReports)
                    _buildDrawerSectionLabel('REPORTS'),
                  if (auth.canAccessReports)
                    _buildDrawerItem(
                      context,
                      icon: Icons.assessment_outlined,
                      title: 'Reports',
                      color: ModulePalettes.reports.primary,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ModuleTheme(
                              palette: ModulePalettes.reports,
                              child: ReportsPage(),
                            ),
                          ),
                        );
                      },
                    ),
                  if (auth.canAccessEquipment ||
                      auth.canAccessEquipmentDistribution ||
                      auth.canAccessMedicine)
                    _buildDrawerSectionLabel('INVENTORY'),
                  if (auth.canAccessEquipment)
                    _buildDrawerItem(
                      context,
                      icon: Icons.inventory_2_outlined,
                      title: "Equipment Inventory",
                      color: ModulePalettes.equipmentSupply.primary,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ModuleTheme(
                              palette: ModulePalettes.equipmentSupply,
                              child: EquipmentListPage(),
                            ),
                          ),
                        );
                      },
                    ),
                  if (auth.canAccessEquipmentDistribution)
                    _buildDrawerItem(
                      context,
                      icon: Icons.local_shipping_outlined,
                      title: "Distributed",
                      color: ModulePalettes.equipmentSupply.primary,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ModuleTheme(
                              palette: ModulePalettes.equipmentSupply,
                              child: EquipmentListPage(initialTab: 1),
                            ),
                          ),
                        );
                      },
                    ),
                  if (auth.canAccessEquipmentDistribution)
                    _buildDrawerItem(
                      context,
                      icon: Icons.wheelchair_pickup_outlined,
                      title: "Supply Record",
                      color: ModulePalettes.equipmentSupply.primary,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ModuleTheme(
                              palette: ModulePalettes.equipmentSupply,
                              child: EquipmentSupplyListPage(),
                            ),
                          ),
                        );
                      },
                    ),
                  if (auth.canAccessMedicineMaster)
                    _buildDrawerItem(
                      context,
                      icon: Icons.medication_liquid_outlined,
                      title: "Medicine",
                      color: ModulePalettes.medicineSupply.primary,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ModuleTheme(
                              palette: ModulePalettes.medicineSupply,
                              child: MedicineListPage(),
                            ),
                          ),
                        );
                      },
                    ),
                  if (auth.canAccessMedicineSupply)
                    _buildDrawerItem(
                      context,
                      icon: Icons.vaccines_outlined,
                      title: "Medicine Supply",
                      color: ModulePalettes.medicineSupply.primary,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ModuleTheme(
                              palette: ModulePalettes.medicineSupply,
                              child: MedicineSupplyListPage(),
                            ),
                          ),
                        );
                      },
                    ),
                  if (auth.canAccessEquipmentDistribution)
                    _buildDrawerItem(
                      context,
                      icon: Icons.wheelchair_pickup_outlined,
                      title: "Equipments",
                      color: ModulePalettes.equipmentSupply.primary,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ModuleTheme(
                              palette: ModulePalettes.equipmentSupply,
                              child: EquipmentSupplyListPage(),
                            ),
                          ),
                        );
                      },
                    ),
                  if (auth.canAccessNHC)
                    _buildDrawerItem(
                      context,
                      icon: Icons.assignment_outlined,
                      title: "Visit entry (NHC)",
                      color: ModulePalettes.homeVisits.primary,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const VisitAssessmentVisitPickerScreen(),
                          ),
                        );
                      },
                    ),
                  if (auth.isAdmin) ...[
                    _buildDrawerSectionLabel('REQUESTS'),
                    _buildDrawerItem(
                      context,
                      icon: Icons.event_available_outlined,
                      title: 'Volunteer Requests',
                      color: AppColors.success,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const VolunteerAvailabilityRequestsAdminPage(),
                          ),
                        );
                      },
                    ),
                    _buildDrawerSectionLabel('SYSTEM'),
                    _buildDrawerItem(
                      context,
                      icon: Icons.settings_outlined,
                      title: "System Config",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const ConfigPage(mode: ConfigPageMode.settings),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      context,
                      icon: Icons.auto_stories_outlined,
                      title: "About Our Unit",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AboutUsAdminPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                children: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy & Data Use',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PrivacyPolicyScreen(
                            supportEmail: auth.unitSupportEmail,
                            supportPhone: auth.unitSupportPhone,
                          ),
                        ),
                      );
                    },
                  ),
                  if (auth.isVolunteer)
                    _buildDrawerItem(
                      context,
                      icon: Icons.delete_forever_outlined,
                      title: "Delete Account",
                      color: AppColors.danger,
                      onTap: () {
                        Navigator.pop(context);
                        _confirmDeleteAccount(context);
                      },
                    ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.logout_rounded,
                    title: "Logout",
                    color: AppColors.danger,
                    onTap: () {
                      auth.logout();
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const Loginscreen(),
                        ),
                        (route) => false,
                      );
                    },
                  ),
                  InkWell(
                    onTap: () async {
                      final Uri url = Uri.parse('https://ameen.osperb.com');
                      if (!await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      )) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not launch website'),
                            ),
                          );
                        }
                      }
                    },
                    child: Text(
                      "All rights reserved by Palliative App",
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    _appVersionLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
    Color? color,
  }) {
    final itemColor = color ?? AppColors.text;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Material(
        color: isSelected ? AppColors.surface2 : Colors.transparent,
        borderRadius: AppRadius.md,
        child: ListTile(
          minLeadingWidth: 32,
          leading: Icon(
            icon,
            color: isSelected ? AppColors.primary : itemColor,
            size: AppIcons.large,
          ),
          title: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.text,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          onTap: onTap,
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xxs,
          ),
        ),
      ),
    );
  }
}

class _HomeMetricAction {
  const _HomeMetricAction({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final VoidCallback onTap;
}

class _HomeQuickAction {
  const _HomeQuickAction({
    required this.label,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final VoidCallback onTap;
}

enum _HomeActionTone { neutral, warning, success, danger }

class _HomeMetricCard extends StatelessWidget {
  const _HomeMetricCard({required this.action});

  final _HomeMetricAction action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${action.title}, ${action.value}, ${action.subtitle}',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: action.onTap,
          mouseCursor: SystemMouseCursors.click,
          hoverColor: _homeHoverOverlay,
          focusColor: _homeHoverOverlay,
          highlightColor: _homePressedOverlay,
          splashColor: _homePressedOverlay,
          child: SizedBox(
            height: 124,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: action.iconBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          action.icon,
                          color: action.iconColor,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          action.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(
                                color: _homeInk,
                                fontSize: 15,
                                height: 1.05,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ).copyWith(
                                fontFamilyFallback: const ['NotoSansMalayalam'],
                              ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    action.value,
                    maxLines: 1,
                    style: TextStyle(
                      color: _homeInk,
                      fontSize: action.value.length > 3 ? 25 : 32,
                      height: 0.95,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    action.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _homeMuted,
                      fontSize: 13,
                      height: 1,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeQuickChip extends StatelessWidget {
  const _HomeQuickChip({
    required this.label,
    required this.icon,
    this.iconBackground = AppColors.surface2,
    this.iconColor = AppColors.textSecondary,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        mouseCursor: onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        hoverColor: _homeHoverOverlay,
        focusColor: _homeHoverOverlay,
        highlightColor: _homePressedOverlay,
        splashColor: _homePressedOverlay,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 15, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 19),
              ),
              const SizedBox(width: 9),
              Text(
                label,
                style: const TextStyle(
                  color: _homeInk,
                  fontSize: 15,
                  height: 1,
                  fontWeight: FontWeight.w600,
                ).copyWith(fontFamilyFallback: const ['NotoSansMalayalam']),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeActivityCard extends StatelessWidget {
  const _HomeActivityCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconBackground = _homeBackground,
    this.iconColor = _homeInk,
    this.actionLabel,
    this.actionTone = _HomeActionTone.neutral,
    this.actionBackgroundColor,
    this.actionForegroundColor,
    this.loading = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconBackground;
  final Color iconColor;
  final String? actionLabel;
  final _HomeActionTone actionTone;
  final Color? actionBackgroundColor;
  final Color? actionForegroundColor;
  final bool loading;
  final VoidCallback? onTap;

  Color get _actionBackground =>
      actionBackgroundColor ??
      switch (actionTone) {
        _HomeActionTone.warning => const Color(0xFFFFEDC7),
        _HomeActionTone.success => const Color(0xFFD5F1D1),
        _HomeActionTone.danger => const Color(0xFFF9D3CE),
        _HomeActionTone.neutral => _homeBackground,
      };

  Color get _actionForeground =>
      actionForegroundColor ??
      switch (actionTone) {
        _HomeActionTone.warning => const Color(0xFF745000),
        _HomeActionTone.success => const Color(0xFF236431),
        _HomeActionTone.danger => const Color(0xFF8C3025),
        _ => _homeInk,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: loading ? null : onTap,
        mouseCursor: loading || onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        hoverColor: _homeHoverOverlay,
        focusColor: _homeHoverOverlay,
        highlightColor: _homePressedOverlay,
        splashColor: _homePressedOverlay,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: iconColor, size: 21),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                              color: _homeInk,
                              fontSize: 15,
                              height: 1.05,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.15,
                            ).copyWith(
                              fontFamilyFallback: const ['NotoSansMalayalam'],
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                              color: _homeMuted,
                              fontSize: 13,
                              height: 1,
                              fontWeight: FontWeight.w400,
                            ).copyWith(
                              fontFamilyFallback: const ['NotoSansMalayalam'],
                            ),
                      ),
                    ],
                  ),
                ),
                if (actionLabel != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    constraints: const BoxConstraints(minWidth: 62),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _actionBackground,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: loading
                        ? SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _actionForeground,
                            ),
                          )
                        : Text(
                            actionLabel!,
                            style: TextStyle(
                              color: _actionForeground,
                              fontSize: 13,
                              height: 1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeTaskTabs extends StatelessWidget {
  const _HomeTaskTabs({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const labels = ['Today', 'Upcoming', 'Completed'];
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++)
            Expanded(
              child: Material(
                color: index == selectedIndex ? _homeInk : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => onSelected(index),
                  child: Center(
                    child: Text(
                      labels[index],
                      style: TextStyle(
                        color: index == selectedIndex ? Colors.white : _homeInk,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 5,
      decoration: const BoxDecoration(
        color: AppColors.borderStrong,
        borderRadius: AppRadius.xs,
      ),
    );
  }
}

class _ShellStatusPill extends StatelessWidget {
  const _ShellStatusPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.md,
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: AppIcons.small),
          const SizedBox(width: AppSpacing.xxs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrImageFallback extends StatelessWidget {
  const _QrImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: AppColors.surface1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.qr_code_2_rounded,
            size: AppIcons.feature,
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'QR image unavailable',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportQrImage extends StatelessWidget {
  const _SupportQrImage({this.source});

  final String? source;

  @override
  Widget build(BuildContext context) {
    final imageSource = source?.trim();

    if (imageSource != null && imageSource.isNotEmpty) {
      if (imageSource.startsWith('data:image/')) {
        final commaIndex = imageSource.indexOf(',');
        if (commaIndex > -1) {
          try {
            return Image.memory(
              base64Decode(imageSource.substring(commaIndex + 1)),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const _QrImageFallback(),
            );
          } catch (_) {
            return const _QrImageFallback();
          }
        }
      }

      if (imageSource.startsWith('http://') ||
          imageSource.startsWith('https://')) {
        return Image.network(
          imageSource,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const _QrImageFallback(),
        );
      }
    }

    return const _QrImageFallback();
  }
}
