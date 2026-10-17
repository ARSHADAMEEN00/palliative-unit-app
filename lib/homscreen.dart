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
import 'package:oruma_app/deceased_patient_list_page.dart';
import 'package:provider/provider.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/loginscreen.dart';
import 'package:oruma_app/services/equipment_supply_service.dart';
import 'package:oruma_app/services/feature_permissions.dart';
import 'package:oruma_app/services/notification_service.dart';
import 'package:oruma_app/models/app_notification.dart';
import 'package:oruma_app/models/equipment_supply.dart';
import 'package:oruma_app/models/volunteer_activity.dart';
import 'package:oruma_app/services/volunteer_application_service.dart';
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
import 'package:oruma_app/features/reports/presentation/reports_page.dart';

const _appVersionLabel = 'Version 1.0.0 (Build 1)';

class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

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
  bool _volunteerActivityLoading = false;
  bool _checkingApproval = false;

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
    if (!mounted || auth.isAccessBlocked || !auth.isVolunteerApproved) return;
    if (auth.isVolunteer) _loadVolunteerActivity();
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
    setState(() => _volunteerActivityLoading = true);
    try {
      final activity = await VolunteerApplicationService.getMyActivity();
      if (!mounted) return;
      setState(() => _volunteerActivity = activity);
    } catch (_) {
      // The dashboard remains usable if activity history is temporarily offline.
    } finally {
      if (mounted) setState(() => _volunteerActivityLoading = false);
    }
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
                          style: textTheme.headlineMedium?.copyWith(
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
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
            ),
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
                MaterialPageRoute(
                  builder: (context) => const Loginscreen(),
                ),
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

  Widget _buildVolunteerActivitySection(BuildContext context) {
    if (_volunteerActivityLoading && _volunteerActivity == null) {
      return const AppCard(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final activity = _volunteerActivity;
    if (activity == null) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(child: Text('Activity history is unavailable.')),
            IconButton(
              tooltip: 'Retry',
              onPressed: _loadVolunteerActivity,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      );
    }

    final tierColor = _achievementColor(activity.achievementTier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDashboardSectionHeader(
          context,
          title: 'My Social Work',
          subtitle: 'Your contribution milestones and recent activity.',
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                borderColor: AppColors.primary.withValues(alpha: 0.18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.volunteer_activism_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      activity.totalSocialWorks.toString(),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Social works',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                borderColor: tierColor.withValues(alpha: 0.22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.workspace_premium_rounded, color: tierColor),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      activity.achievementTier,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: tierColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      activity.nextTierAt == null
                          ? 'Highest reward'
                          : '${activity.nextTierAt! - activity.totalSocialWorks} to next reward',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (activity.history.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          ...activity.history
              .take(3)
              .map(
                (item) => AppCard(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: AppRadius.md,
                        ),
                        child: const Icon(
                          Icons.favorite_outline_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.supportTypes
                                  .map(_socialWorkTypeLabel)
                                  .join(', '),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${item.patientName} • ${DateFormat('d MMM yyyy').format(item.givenAt.toLocal())}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ],
    );
  }

  String _socialWorkTypeLabel(String type) {
    return switch (type) {
      'ration_kit' => 'Ration kit',
      'vegetables' => 'Vegetables',
      'medicine' => 'Medicine',
      _ => type.replaceAll('_', ' '),
    };
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('User Role: ${context.read<AuthService>().role}');
    final auth = context.watch<AuthService>();
    final isPendingApproval = auth.isVolunteer && !auth.isVolunteerApproved;
    final maintenanceNotification = !auth.isAdmin || auth.isTrialUnit
        ? null
        : _visibleMaintenanceDueNotification();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < AppBreakpoints.tablet;
    final horizontalPadding = isCompact ? AppSpacing.md : AppSpacing.lg;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFD8ECFD), // Serene palliative sky blue
            Color(0xFFDEF5EB), // Soothing restorative mint / eucalyptus
            Color(0xFFF5EDFA), // Gentle compassionate warm lavender
            Color(0xFFEDF4FA), // Calming pearl base
          ],
          stops: [0.0, 0.35, 0.70, 1.0],
        ),
      ),
      child: AdaptiveAppScaffold(
        scaffoldKey: _scaffoldKey,
        drawer: isPendingApproval ? null : _buildProfessionalDrawer(context),
        backgroundColor: Colors.transparent,
        currentSection: isPendingApproval ? null : AppBottomSection.home,
        onNavigationSelected: isPendingApproval ? null : _handleBottomNavigation,
        contentMaxWidth: 1040,
        body: SafeArea(
          bottom: false,
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
                  const SizedBox(height: AppSpacing.lg),
                  _buildVolunteerApprovalCard(auth),
                ] else ...[
                  if (maintenanceNotification != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _buildMaintenanceDueBanner(context, maintenanceNotification),
                  ],
                if (auth.isVolunteer) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _buildVolunteerActivitySection(context),
                ],
                const SizedBox(height: AppSpacing.lg),
                _buildDashboardSectionHeader(
                  context,
                  title: 'Care Modules',
                  subtitle: 'Open the work area you need now.',
                ),
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
                  const SizedBox(height: AppSpacing.xl),
                  _buildDashboardSectionHeader(
                    context,
                    title: 'Active Supplies',
                    subtitle: 'Equipment currently assigned to patients.',
                    actionLabel: 'View all',
                    onAction: () {
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
                  const SizedBox(height: AppSpacing.md),
                  _buildActiveSuppliesList(context),
                ],
              ],
            ],
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

    return AppCard(
      surfaceLevel: AppSurfaceLevel.elevated,
      padding: EdgeInsets.all(isCompact ? AppSpacing.md : AppSpacing.lg),
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
              ),
              const Spacer(),
              if (auth.unitSupportQr != null && !isPendingApproval) ...[
                _buildShellIconButton(
                  tooltip: 'Show QR',
                  icon: Icons.qr_code_2_rounded,
                  onTap: () => _showQRModal(context),
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
              ),
              if (auth.canCreate) ...[
                const SizedBox(width: AppSpacing.xs),
                _buildShellIconButton(
                  tooltip: 'Quick add',
                  icon: Icons.add_rounded,
                  onTap: _showQuickAddOptions,
                ),
              ],
              const SizedBox(width: AppSpacing.xs),
              GestureDetector(
                onTap: () => _showUserProfile(context),
                child: UnitBrandAvatar(
                  size: 44,
                  preferAppIcon: true,
                  backgroundColor: AppColors.primaryLight,
                  iconColor: AppColors.primary,
                  border: Border.all(color: AppColors.border),
                  fallbackIcon: Icons.person_rounded,
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? AppSpacing.md : AppSpacing.lg),
          Text(
            _getGreeting(auth),
            style: textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            auth.unitName,
            style: GoogleFonts.outfit(
              textStyle: textTheme.headlineMedium,
              color: AppColors.text,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              height: 1.15,
            ).copyWith(fontFamilyFallback: const ['NotoSansMalayalam']),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _ShellStatusPill(
                label: auth.unitLocation,
                icon: Icons.location_on_outlined,
                color: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShellIconButton({
    required String tooltip,
    required IconData icon,
    VoidCallback? onTap,
    String? badgeLabel,
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
              const SizedBox.square(dimension: 44),
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
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleLarge?.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                subtitle,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
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
