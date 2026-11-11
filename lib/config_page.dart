import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/models/config.dart';
import 'package:oruma_app/models/staff_user.dart';
import 'package:oruma_app/models/ward.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/services/config_service.dart';
import 'package:oruma_app/services/staff_service.dart';
import 'package:oruma_app/services/ward_service.dart';
import 'package:oruma_app/services/feature_permissions.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';
import 'package:oruma_app/widgets/reveal_action_fab.dart';
import 'package:provider/provider.dart';

enum ConfigPageMode { combined, settings, staff, lsg }

enum _DeleteStaffOption { removeFromUnit, deleteUser }

class ConfigPage extends StatefulWidget {
  const ConfigPage({
    super.key,
    this.initialTab = 0,
    this.mode = ConfigPageMode.combined,
  });

  final int initialTab;
  final ConfigPageMode mode;

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage>
    with SingleTickerProviderStateMixin {
  static const _primaryColor = AppColors.primary;
  static const _surfaceColor = AppColors.background;
  static const _inkColor = AppColors.text;
  static const _mutedInkColor = AppColors.textSecondary;
  static const _lineColor = AppColors.border;
  static const _fieldFillColor = AppColors.surface1;
  static const _chipFillColor = AppColors.surface1;
  static const _chipLineColor = AppColors.border;
  static const _softAccentColor = AppColors.primaryLight;
  static const _removeIconColor = AppColors.textMuted;
  static const _roles = ['admin', 'staff', 'member', 'volunteer'];
  static const _permissionRoles = _roles;
  static const _staffModuleIds = [
    AppFeature.patients,
    AppFeature.homeVisits,
    AppFeature.volunteers,
    AppFeature.socialSupport,
    AppFeature.equipment,
    AppFeature.equipmentDistribution,
    AppFeature.medicineMaster,
    AppFeature.medicineStock,
    AppFeature.medicineSupply,
    AppFeature.nhcAssessment,
    AppFeature.advancedReports,
  ];

  late final TabController _tabController;

  Config? _config;
  List<StaffUser> _staff = [];
  List<Ward> _careWards = [];
  Map<String, Set<String>> _rolePermissionDefaults = {
    for (final role in _permissionRoles)
      role: {..._defaultModulesForRole(role)},
  };
  Set<String> _subscribedModuleIds = {..._staffModuleIds};
  String _selectedStaffSection = 'staff';
  String _selectedPermissionRole = 'staff';
  String _staffRoleFilter = 'all';
  String _staffWardFilter = 'all';
  String _staffSearchQuery = '';
  final TextEditingController _staffSearchController = TextEditingController();
  final Set<String> _updatingStaffIds = <String>{};
  final Set<String> _expandedStaffModuleCardIds = <String>{};

  bool _isLoadingConfig = true;
  bool _isLoadingStaff = true;
  bool _isSavingConfig = false;
  bool _isSavingRolePermissions = false;
  String? _configErrorMessage;
  String? _staffErrorMessage;

  List<String> get _assignableRoles => _roles
      .where(
        (role) =>
            role != 'volunteer' ||
            _subscribedModuleIds.contains(AppFeature.volunteers),
      )
      .toList(growable: false);

  final TextEditingController _villageController = TextEditingController();
  final TextEditingController _diseaseController = TextEditingController();
  final TextEditingController _planController = TextEditingController();
  final TextEditingController _wardController = TextEditingController();
  final TextEditingController _settingsSearchController =
      TextEditingController();
  String _settingsSearchQuery = '';
  String? _selectedWardVillage;

  static InputDecoration _fieldDecoration({
    String? labelText,
    String? hintText,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    const enabledBorder = OutlineInputBorder(
      borderRadius: AppRadius.input,
      borderSide: BorderSide(color: _lineColor, width: 1),
    );

    return InputDecoration(
      isDense: true,
      labelText: labelText,
      hintText: hintText,
      filled: true,
      fillColor: _fieldFillColor,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      prefixIcon: prefixIcon == null
          ? null
          : Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: _softAccentColor,
                borderRadius: AppRadius.sm,
              ),
              child: Icon(prefixIcon, color: _primaryColor, size: 18),
            ),
      prefixIconConstraints: prefixIcon == null
          ? null
          : const BoxConstraints(minWidth: 44, minHeight: 44),
      suffixIcon: suffixIcon,
      prefixIconColor: _mutedInkColor,
      suffixIconColor: _mutedInkColor,
      hintStyle: const TextStyle(color: _mutedInkColor, fontSize: 13),
      labelStyle: const TextStyle(color: _mutedInkColor, fontSize: 12),
      floatingLabelStyle: const TextStyle(
        color: _primaryColor,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      enabledBorder: enabledBorder,
      disabledBorder: enabledBorder,
      border: enabledBorder,
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: BorderSide(color: _primaryColor, width: 1.4),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: BorderSide(color: AppColors.danger, width: 1),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: BorderSide(color: AppColors.danger, width: 1.4),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(
          length: 2,
          vsync: this,
          initialIndex: widget.initialTab.clamp(0, 1).toInt(),
        )..addListener(() {
          if (!_tabController.indexIsChanging && mounted) setState(() {});
        });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<AuthService>().isAdmin) {
        _fetchConfig();
        if (widget.mode != ConfigPageMode.settings &&
            widget.mode != ConfigPageMode.lsg) {
          _fetchStaff();
        }
      } else {
        setState(() {
          _isLoadingConfig = false;
          _isLoadingStaff = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _staffSearchController.dispose();
    _settingsSearchController.dispose();
    _villageController.dispose();
    _diseaseController.dispose();
    _planController.dispose();
    _wardController.dispose();
    super.dispose();
  }

  void _ensureSelectedWardVillage(Config config) {
    if (config.villages.isEmpty) {
      _selectedWardVillage = null;
      return;
    }

    if (_selectedWardVillage == null ||
        !config.villages.contains(_selectedWardVillage)) {
      _selectedWardVillage = config.villages.first;
    }
  }

  Future<void> _fetchConfig() async {
    setState(() {
      _isLoadingConfig = true;
      _configErrorMessage = null;
    });

    try {
      final results = await Future.wait([
        ConfigService.getConfig(forceRefresh: true),
        WardService.getWards(forceRefresh: true),
      ]);
      final config = results[0] as Config;
      final wards = results[1] as List<Ward>;
      if (!mounted) return;
      setState(() {
        _config = config;
        _careWards = wards;
        _ensureSelectedWardVillage(config);
        _isLoadingConfig = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _configErrorMessage = e.toString();
        _isLoadingConfig = false;
      });
    }
  }

  Future<void> _fetchStaff() async {
    setState(() {
      _isLoadingStaff = true;
      _staffErrorMessage = null;
    });

    try {
      final results = await Future.wait([
        StaffService.getStaff(),
        StaffService.getRolePermissions(),
        WardService.getWards(forceRefresh: true),
      ]);
      final staff = results[0] as List<StaffUser>;
      final permissions = results[1] as RolePermissionSettings;
      final careWards = results[2] as List<Ward>;
      if (!mounted) return;
      setState(() {
        _staff = staff;
        _careWards = careWards;
        _rolePermissionDefaults = {
          for (final role in _permissionRoles)
            role: {...?permissions.rolePermissions[role]},
        };
        _subscribedModuleIds = {...permissions.subscribedModuleIds};
        if (_selectedPermissionRole == 'volunteer' &&
            !_subscribedModuleIds.contains(AppFeature.volunteers)) {
          _selectedPermissionRole = 'staff';
        }
        _isLoadingStaff = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _staffErrorMessage = e.toString();
        _isLoadingStaff = false;
      });
    }
  }

  Future<void> _saveConfig() async {
    if (_config == null) return;

    setState(() => _isSavingConfig = true);
    try {
      final updatedConfig = await ConfigService.updateConfig(_config!);
      final syncedWards = await WardService.getWards(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _config = updatedConfig;
        _careWards = syncedWards;
        _ensureSelectedWardVillage(updatedConfig);
      });
      final auth = Provider.of<AuthService>(context, listen: false);
      await auth.updateUnitWorkingTime(updatedConfig.workingTime);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuration saved successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $message'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingConfig = false);
    }
  }

  void _addItem(String listName, TextEditingController controller) {
    if (controller.text.trim().isEmpty || _config == null) return;
    final item = controller.text.trim();

    setState(() {
      if (listName == 'villages' && !_config!.villages.contains(item)) {
        _config!.villages.add(item);
        _config!.villages.sort(compareNaturally);
        _ensureSelectedWardVillage(_config!);
      } else if (listName == 'diseases' && !_config!.diseases.contains(item)) {
        _config!.diseases.add(item);
        _config!.diseases.sort(compareNaturally);
      } else if (listName == 'plans' && !_config!.plans.contains(item)) {
        _config!.plans.add(item);
        _config!.plans.sort(compareNaturally);
      }
      controller.clear();
    });
  }

  void _removeItem(String listName, String item) {
    if (_config == null) return;
    setState(() {
      if (listName == 'villages') {
        _config!.villages.remove(item);
        _config!.wards.removeWhere((ward) => ward.village == item);
        _ensureSelectedWardVillage(_config!);
      } else if (listName == 'diseases') {
        _config!.diseases.remove(item);
      } else if (listName == 'plans') {
        _config!.plans.remove(item);
      }
    });
  }

  void _addWard() {
    if (_config == null || _selectedWardVillage == null) return;

    final wardValues = parseWardInput(_wardController.text);
    if (wardValues.isEmpty) return;

    setState(() {
      for (final wardValue in wardValues) {
        final key = wardKey(wardValue);
        final existingIndex = _config!.wards.indexWhere(
          (w) => w.village == _selectedWardVillage && wardKey(w.number) == key,
        );

        if (existingIndex >= 0) {
          _config!.wards[existingIndex] = WardConfig(
            number: wardValue,
            village: _selectedWardVillage!,
          );
        } else {
          _config!.wards.add(
            WardConfig(number: wardValue, village: _selectedWardVillage!),
          );
        }
      }
      _config!.wards.sort(compareWardConfigs);
      _wardController.clear();
    });
  }

  void _removeWard(WardConfig ward) {
    if (_config == null) return;

    setState(() {
      _config!.wards.removeWhere(
        (item) => item.village == ward.village && item.number == ward.number,
      );
    });
  }

  void _toggleWorkingDay(int weekday, bool selected) {
    if (_config == null) return;
    setState(() {
      if (selected) {
        if (!_config!.workingDays.contains(weekday)) {
          _config!.workingDays.add(weekday);
        }
      } else {
        _config!.workingDays.remove(weekday);
      }
      _config!.workingDays.sort();
    });
  }

  Future<void> _updateStaffRole(StaffUser staff, String role) async {
    if (staff.role == role || _updatingStaffIds.contains(staff.id)) return;

    setState(() => _updatingStaffIds.add(staff.id));
    try {
      final updated = await StaffService.updateRole(staff.id, role);
      if (!mounted) return;
      setState(() {
        final index = _staff.indexWhere((item) => item.id == staff.id);
        if (index != -1) {
          _staff[index] = updated;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${updated.name} is now ${_roleLabel(role)}'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update role: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingStaffIds.remove(staff.id));
    }
  }

  Future<void> _confirmDeleteStaff(StaffUser staff) async {
    if (staff.role == 'admin' || _updatingStaffIds.contains(staff.id)) return;

    final selectedOption = await showDialog<_DeleteStaffOption>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.10),
                borderRadius: AppRadius.sm,
              ),
              child: const Icon(
                Icons.person_remove_rounded,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(child: Text('Delete user account?')),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose how you want to handle ${staff.name} (${staff.email}):',
                style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              InkWell(
                borderRadius: AppRadius.md,
                onTap: () => Navigator.pop(
                  dialogContext,
                  _DeleteStaffOption.removeFromUnit,
                ),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: AppRadius.md,
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.16),
                          borderRadius: AppRadius.xs,
                        ),
                        child: const Icon(
                          Icons.domain_disabled_rounded,
                          color: AppColors.warning,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Delete from unit',
                              style: Theme.of(dialogContext)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Removes user from this unit only. When they log in, no previous unit data is shown and they can request access to other units.',
                              style: Theme.of(dialogContext).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.35,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              InkWell(
                borderRadius: AppRadius.md,
                onTap: () =>
                    Navigator.pop(dialogContext, _DeleteStaffOption.deleteUser),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.08),
                    borderRadius: AppRadius.md,
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.16),
                          borderRadius: AppRadius.xs,
                        ),
                        child: const Icon(
                          Icons.delete_forever_rounded,
                          color: AppColors.danger,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Delete user',
                              style: Theme.of(dialogContext)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.danger,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Permanently deletes this user account and all their database records. This action cannot be undone.',
                              style: Theme.of(dialogContext).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.35,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        actions: [
          Builder(
            builder: (context) {
              final isNarrow = MediaQuery.sizeOf(context).width < 540;
              if (isNarrow) {
                return SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.warning,
                          side: BorderSide(
                            color: AppColors.warning.withValues(alpha: 0.8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 12,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.button,
                          ),
                        ),
                        icon: const Icon(
                          Icons.domain_disabled_rounded,
                          size: 18,
                        ),
                        label: const Text('Delete from unit'),
                        onPressed: () => Navigator.pop(
                          dialogContext,
                          _DeleteStaffOption.removeFromUnit,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppDangerButton(
                        label: 'Delete user',
                        icon: Icons.delete_forever_rounded,
                        fullWidth: true,
                        onPressed: () => Navigator.pop(
                          dialogContext,
                          _DeleteStaffOption.deleteUser,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppSecondaryButton(
                        label: 'Cancel',
                        fullWidth: true,
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                );
              }

              return Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  AppSecondaryButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      side: BorderSide(
                        color: AppColors.warning.withValues(alpha: 0.8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 11,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.button,
                      ),
                    ),
                    icon: const Icon(Icons.domain_disabled_rounded, size: 16),
                    label: const Text('Delete from unit'),
                    onPressed: () => Navigator.pop(
                      dialogContext,
                      _DeleteStaffOption.removeFromUnit,
                    ),
                  ),
                  AppDangerButton(
                    label: 'Delete user',
                    icon: Icons.delete_forever_rounded,
                    onPressed: () => Navigator.pop(
                      dialogContext,
                      _DeleteStaffOption.deleteUser,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    if (selectedOption == null || !mounted) return;

    setState(() => _updatingStaffIds.add(staff.id));
    try {
      if (selectedOption == _DeleteStaffOption.removeFromUnit) {
        await StaffService.removeFromUnit(staff.id);
        if (!mounted) return;
        setState(() => _staff.removeWhere((item) => item.id == staff.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${staff.name} was removed from this unit'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        await StaffService.deleteStaff(staff.id);
        if (!mounted) return;
        setState(() => _staff.removeWhere((item) => item.id == staff.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${staff.name} was deleted from database'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to ${selectedOption == _DeleteStaffOption.removeFromUnit ? "remove" : "delete"} user: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingStaffIds.remove(staff.id));
    }
  }

  Future<void> _saveRolePermissions() async {
    if (_isSavingRolePermissions) return;
    final role = _selectedPermissionRole;
    final selected = _rolePermissionDefaults[role] ?? <String>{};
    setState(() => _isSavingRolePermissions = true);
    try {
      final saved = await StaffService.updateRolePermissions(
        role: role,
        permittedModuleIds: selected.toList(),
      );
      if (!mounted) return;
      setState(() => _rolePermissionDefaults[role] = {...saved});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_roleLabel(role)} defaults saved'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save role defaults: $error'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingRolePermissions = false);
    }
  }

  Widget _permissionChip({
    required String moduleId,
    required bool selected,
    required bool disabled,
    required ValueChanged<bool> onSelected,
    bool readOnly = false,
  }) {
    final chip = FilterChip(
      selected: !disabled && selected,
      avatar: disabled
          ? const Icon(
              Icons.lock_outline_rounded,
              size: 14,
              color: AppColors.textMuted,
            )
          : selected
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
      label: Text(AppFeature.label(moduleId)),
      labelStyle: TextStyle(
        color: disabled ? AppColors.textMuted : AppColors.text,
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      showCheckmark: false,
      onSelected: disabled || readOnly ? null : onSelected,
    );
    if (!disabled) return chip;
    return Tooltip(
      message: 'Not included in the current subscription',
      child: chip,
    );
  }

  Widget _buildRolePermissionDefaults() {
    final selectedModules =
        _rolePermissionDefaults[_selectedPermissionRole] ?? <String>{};
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBadge(
                icon: Icons.rule_folder_outlined,
                color: _primaryColor,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Role permissions',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Accounts receive these defaults when a role is assigned.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: _assignableRoles.map((role) {
              final selected = _selectedPermissionRole == role;
              return ChoiceChip(
                selected: selected,
                avatar: Icon(
                  _roleIcon(role),
                  size: 17,
                  color: selected ? Colors.white : _roleColor(role),
                ),
                label: Text(_roleLabel(role)),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppColors.text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surface1,
                disabledColor: AppColors.surface2,
                side: BorderSide(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: selected ? 1.5 : 1,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                showCheckmark: false,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: _isSavingRolePermissions
                    ? null
                    : (_) => setState(() => _selectedPermissionRole = role),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Default permitted modules',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Locked modules are not included in the current subscription.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: _staffModuleIds.map((moduleId) {
              final disabled = !_subscribedModuleIds.contains(moduleId);
              return _permissionChip(
                moduleId: moduleId,
                selected: selectedModules.contains(moduleId),
                disabled: disabled,
                readOnly: _isSavingRolePermissions,
                onSelected: (enabled) => setState(() {
                  final updated = {...selectedModules};
                  if (enabled) {
                    updated.add(moduleId);
                  } else {
                    updated.remove(moduleId);
                  }
                  _rolePermissionDefaults[_selectedPermissionRole] = updated;
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: AppPrimaryButton(
              label: 'Save role defaults',
              icon: Icons.save_outlined,
              loading: _isSavingRolePermissions,
              onPressed: _isSavingRolePermissions ? null : _saveRolePermissions,
            ),
          ),
        ],
      ),
    );
  }

  List<String> get _wardLocalBodies {
    final values = <String>{};
    for (final ward in _careWards) {
      if (ward.isActive &&
          ward.localBody != null &&
          ward.localBody!.trim().isNotEmpty) {
        values.add(ward.localBody!.trim());
      }
    }
    if (_config != null) {
      for (final village in _config!.villages) {
        if (village.trim().isNotEmpty) values.add(village.trim());
      }
      for (final ward in _config!.wards) {
        if (ward.village.trim().isNotEmpty) values.add(ward.village.trim());
      }
    }
    final list = values.toList();
    list.sort(compareNaturally);
    return list;
  }

  String? _defaultWardLocalBody(Set<String> selectedWardIds) {
    for (final ward in _careWards) {
      if (selectedWardIds.contains(ward.id) &&
          (ward.localBody?.trim().isNotEmpty ?? false)) {
        return ward.localBody!.trim();
      }
    }
    final localBodies = _wardLocalBodies;
    return localBodies.isEmpty ? null : localBodies.first;
  }

  Future<void> _showStaffWardSelectionSheet({
    required String? initialLocalBody,
    required Set<String> selectedWardIds,
    required ValueChanged<String?> onLocalBodyChanged,
    required ValueChanged<String> onWardToggled,
  }) async {
    final localBodies = _wardLocalBodies;
    if (localBodies.isEmpty) return;

    var activeLocalBody = localBodies.contains(initialLocalBody)
        ? initialLocalBody!
        : localBodies.first;
    var searchQuery = '';
    final searchController = TextEditingController();

    try {
      await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (pickerContext) => StatefulBuilder(
          builder: (context, setPickerState) {
            final localBodyWards =
                _careWards
                    .where(
                      (ward) =>
                          ward.isActive &&
                          ward.localBody?.trim().toLowerCase() ==
                              activeLocalBody.trim().toLowerCase(),
                    )
                    .toList()
                  ..sort((a, b) => compareNaturally(a.label, b.label));
            final visibleWards = localBodyWards.where((ward) {
              final query = searchQuery.trim().toLowerCase();
              return query.isEmpty ||
                  ward.label.toLowerCase().contains(query) ||
                  (ward.lsgWardValue ?? '').toLowerCase().contains(query);
            }).toList();
            final allLocalBodySelected =
                localBodyWards.isNotEmpty &&
                localBodyWards.every(
                  (ward) => selectedWardIds.contains(ward.id),
                );

            void toggleWard(String wardId) {
              onWardToggled(wardId);
              setPickerState(() {});
            }

            return FractionallySizedBox(
              heightFactor: 0.90,
              child: Material(
                color: AppColors.surfaceModal,
                clipBehavior: Clip.antiAlias,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.borderStrong,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.map_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Choose assigned wards',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                                ),
                                Text(
                                  '${selectedWardIds.length} selected across all local bodies',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(pickerContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: activeLocalBody,
                            isExpanded: true,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.normal,
                              color: AppColors.text,
                            ),
                            decoration: _fieldDecoration(
                              labelText: 'Local body / Village',
                              prefixIcon: Icons.location_city_outlined,
                            ),
                            items: localBodies
                                .map(
                                  (localBody) => DropdownMenuItem(
                                    value: localBody,
                                    child: Text(
                                      localBody,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.normal,
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              searchController.clear();
                              onLocalBodyChanged(value);
                              setPickerState(() {
                                activeLocalBody = value;
                                searchQuery = '';
                              });
                            },
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: searchController,
                            onChanged: (value) =>
                                setPickerState(() => searchQuery = value),
                            decoration:
                                _fieldDecoration(
                                  labelText: 'Search ward name or number',
                                  prefixIcon: Icons.search,
                                ).copyWith(
                                  suffixIcon: searchQuery.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'Clear search',
                                          onPressed: () {
                                            searchController.clear();
                                            setPickerState(
                                              () => searchQuery = '',
                                            );
                                          },
                                          icon: const Icon(Icons.close),
                                        ),
                                ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${localBodyWards.length} wards in $activeLocalBody',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: localBodyWards.isEmpty
                                ? null
                                : () {
                                    for (final ward in localBodyWards) {
                                      final selected = selectedWardIds.contains(
                                        ward.id,
                                      );
                                      if (allLocalBodySelected && selected) {
                                        onWardToggled(ward.id);
                                      } else if (!allLocalBodySelected &&
                                          !selected) {
                                        onWardToggled(ward.id);
                                      }
                                    }
                                    setPickerState(() {});
                                  },
                            child: Text(
                              allLocalBodySelected
                                  ? 'Deselect local body'
                                  : 'Select all',
                            ),
                          ),
                          if (selectedWardIds.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                for (final id in selectedWardIds.toList()) {
                                  onWardToggled(id);
                                }
                                setPickerState(() {});
                              },
                              child: const Text(
                                'Clear all',
                                style: TextStyle(color: AppColors.danger),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: visibleWards.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: Text(
                                  localBodyWards.isEmpty
                                      ? 'No linked wards are available for this local body.'
                                      : 'No wards match your search.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(8, 2, 8, 12),
                              itemCount: visibleWards.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1, indent: 48, thickness: 0.5),
                              itemBuilder: (context, index) {
                                final ward = visibleWards[index];
                                final selected = selectedWardIds.contains(
                                  ward.id,
                                );
                                return CheckboxListTile(
                                  value: selected,
                                  onChanged: (_) => toggleWard(ward.id),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  activeColor: AppColors.primary,
                                  dense: true,
                                  visualDensity: const VisualDensity(
                                    horizontal: -2,
                                    vertical: -3,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 0,
                                  ),
                                  title: Text(
                                    ward.label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                );
                              },
                            ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        border: Border(
                          top: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${selectedWardIds.length} ward${selectedWardIds.length == 1 ? '' : 's'} selected',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () => Navigator.pop(pickerContext),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Done'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } finally {
      searchController.dispose();
    }
  }

  Widget _buildStaffWardPicker({
    required String? selectedLocalBody,
    required Set<String> selectedWardIds,
    required bool required,
    required bool disabled,
    required ValueChanged<String?> onLocalBodyChanged,
    required ValueChanged<String> onWardToggled,
  }) {
    final linkedWards = _careWards.where((ward) => ward.isActive).toList();
    final configuredWardCount = _config?.wards.length ?? 0;
    final selectedWards = linkedWards
        .where((ward) => selectedWardIds.contains(ward.id))
        .toList();
    final selectedLocalBodies =
        selectedWards
            .map((ward) => ward.localBody?.trim())
            .whereType<String>()
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort(compareNaturally);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Assigned wards${required ? ' *' : ' (optional)'}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            if (selectedWardIds.isNotEmpty)
              Text(
                '${selectedWardIds.length} selected',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (linkedWards.isEmpty)
          Text(
            configuredWardCount > 0
                ? '$configuredWardCount LSG wards are waiting to be linked. Save LSGs & Wards, then refresh.'
                : required
                ? 'Add wards under LSGs & Wards before adding staff.'
                : 'No LSG wards are available yet.',
            style: TextStyle(
              color: required ? AppColors.danger : AppColors.textSecondary,
            ),
          )
        else
          InkWell(
            onTap: disabled
                ? null
                : () => _showStaffWardSelectionSheet(
                    initialLocalBody: selectedLocalBody,
                    selectedWardIds: selectedWardIds,
                    onLocalBodyChanged: onLocalBodyChanged,
                    onWardToggled: onWardToggled,
                  ),
            borderRadius: AppRadius.input,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: AppRadius.input,
                border: Border.all(
                  color: selectedWardIds.isEmpty
                      ? AppColors.borderStrong
                      : AppColors.primary,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.map_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedWardIds.isEmpty
                              ? 'Choose wards'
                              : '${selectedWardIds.length} ward${selectedWardIds.length == 1 ? '' : 's'} selected',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selectedWardIds.isEmpty
                              ? 'Tap to search by ward name or number'
                              : selectedLocalBodies.isEmpty
                              ? 'Tap to review the selection'
                              : selectedLocalBodies.join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.chevron_right,
                    color: disabled ? AppColors.textMuted : AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        if (linkedWards.isEmpty && configuredWardCount > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: disabled
                  ? null
                  : () async {
                      try {
                        final wards = await WardService.getWards(
                          forceRefresh: true,
                        );
                        if (!mounted) return;
                        setState(() => _careWards = wards);
                        onLocalBodyChanged(
                          _defaultWardLocalBody(selectedWardIds),
                        );
                      } catch (error) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Could not refresh ward links: $error',
                            ),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh ward links'),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showAddStaffSheet([String? initialRole]) async {
    if (_config == null) {
      await _fetchConfig();
    }
    if (_careWards.isEmpty) {
      try {
        final wards = await WardService.getWards(forceRefresh: true);
        if (mounted) setState(() => _careWards = wards);
      } catch (_) {}
    }
    if (!mounted) return;
    final wardRequired = context.read<AuthService>().wardRestrictionEnabled;
    final assignableRoles = _assignableRoles;
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final defaultRole =
        (initialRole != null && assignableRoles.contains(initialRole))
        ? initialRole
        : 'staff';
    var selectedRole = defaultRole;
    var selectedModules = <String>{..._modulesForRole(defaultRole)};
    var selectedWardIds = <String>{};
    var selectedWardLocalBody =
        _defaultWardLocalBody(selectedWardIds) ??
        (_wardLocalBodies.isNotEmpty ? _wardLocalBodies.first : null);
    var obscurePassword = true;
    var isSubmitting = false;
    var modulesExpanded = false;
    String? formError;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              Future<void> submit() async {
                if (!(formKey.currentState?.validate() ?? false) ||
                    isSubmitting) {
                  return;
                }

                if (wardRequired &&
                    selectedRole == 'staff' &&
                    selectedWardIds.isEmpty) {
                  setSheetState(() {
                    formError = 'Select at least one ward for a staff user';
                  });
                  return;
                }
                final navigator = Navigator.of(sheetContext);
                final messenger = ScaffoldMessenger.of(this.context);
                setSheetState(() {
                  isSubmitting = true;
                  formError = null;
                });

                try {
                  final staff = await StaffService.createStaff(
                    name: nameController.text,
                    email: emailController.text,
                    password: passwordController.text,
                    role: selectedRole,
                    permittedModuleIds: selectedModules.toList(),
                    wardIds: selectedWardIds.toList(),
                  );
                  if (!mounted) return;
                  setState(() {
                    _staff = [..._staff, staff]..sort(_compareStaffUsers);
                  });
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        '${staff.name} added as ${_roleLabel(staff.role)}',
                      ),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } catch (e) {
                  setSheetState(() {
                    formError = e.toString();
                    isSubmitting = false;
                  });
                }
              }

              return Padding(
                padding: EdgeInsets.only(
                  left: AppInsets.screenHorizontal(context),
                  right: AppInsets.screenHorizontal(context),
                  bottom:
                      MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
                ),
                child: Material(
                  color: AppColors.surfaceModal,
                  borderRadius: AppRadius.sheet,
                  clipBehavior: Clip.antiAlias,
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        AppSpacing.md,
                      ),
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 42,
                                height: 4,
                                margin: const EdgeInsets.only(
                                  bottom: AppSpacing.lg,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.borderStrong,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                const _IconBadge(
                                  icon: Icons.person_add_alt_1_outlined,
                                  color: _primaryColor,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    'Add ${_roleLabel(selectedRole)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: AppColors.text,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            TextFormField(
                              controller: nameController,
                              style: const TextStyle(
                                color: _inkColor,
                                fontSize: 14,
                              ),
                              textInputAction: TextInputAction.next,
                              decoration: _fieldDecoration(
                                labelText: 'Full name',
                                prefixIcon: Icons.person_outline,
                              ),
                              validator: (value) =>
                                  value?.trim().isEmpty ?? true
                                  ? 'Name is required'
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextFormField(
                              controller: emailController,
                              style: const TextStyle(
                                color: _inkColor,
                                fontSize: 14,
                              ),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: _fieldDecoration(
                                labelText: 'Email',
                                prefixIcon: Icons.mail_outline,
                              ),
                              validator: (value) {
                                final email = value?.trim() ?? '';
                                if (email.isEmpty) return 'Email is required';
                                if (!email.contains('@')) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextFormField(
                              controller: passwordController,
                              style: const TextStyle(
                                color: _inkColor,
                                fontSize: 14,
                              ),
                              obscureText: obscurePassword,
                              textInputAction: TextInputAction.done,
                              decoration: _fieldDecoration(
                                labelText: 'Temporary password',
                                prefixIcon: Icons.lock_outline,
                                suffixIcon: IconButton(
                                  tooltip: obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  icon: Icon(
                                    obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () => setSheetState(
                                    () => obscurePassword = !obscurePassword,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                final password = value ?? '';
                                if (password.trim().isEmpty) {
                                  return 'Password is required';
                                }
                                if (password.length < 8) {
                                  return 'Use at least 8 characters';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => submit(),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            DropdownButtonFormField<String>(
                              initialValue: selectedRole,
                              style: const TextStyle(
                                color: _inkColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                              decoration: _fieldDecoration(
                                labelText: 'Role',
                                prefixIcon: Icons.admin_panel_settings,
                              ),
                              items: assignableRoles
                                  .map(
                                    (role) => DropdownMenuItem(
                                      value: role,
                                      child: Text(
                                        _roleLabel(role),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.normal,
                                          color: _inkColor,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: isSubmitting
                                  ? null
                                  : (value) => setSheetState(() {
                                      selectedRole = value ?? 'staff';
                                      selectedModules = <String>{
                                        ..._modulesForRole(selectedRole),
                                      };
                                    }),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _buildStaffWardPicker(
                              selectedLocalBody: selectedWardLocalBody,
                              selectedWardIds: selectedWardIds,
                              required: wardRequired && selectedRole == 'staff',
                              disabled: isSubmitting,
                              onLocalBodyChanged: (value) => setSheetState(
                                () => selectedWardLocalBody = value,
                              ),
                              onWardToggled: (wardId) => setSheetState(() {
                                selectedWardIds.contains(wardId)
                                    ? selectedWardIds.remove(wardId)
                                    : selectedWardIds.add(wardId);
                              }),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            InkWell(
                              borderRadius: AppRadius.sm,
                              onTap: () => setSheetState(
                                () => modulesExpanded = !modulesExpanded,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface1,
                                  borderRadius: AppRadius.input,
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.tune_outlined,
                                      size: 18,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                'Permitted modules',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelLarge
                                                    ?.copyWith(
                                                      color: AppColors.text,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                              const SizedBox(
                                                width: AppSpacing.xs,
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primarySoft,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '${selectedModules.length} selected',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            modulesExpanded
                                                ? 'Locked modules are not included in the current subscription.'
                                                : 'Default collapsed • Tap to view and edit module permissions',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: AppColors.textMuted,
                                                  fontSize: 11.5,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      modulesExpanded
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      color: AppColors.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (modulesExpanded) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Wrap(
                                spacing: AppSpacing.xs,
                                runSpacing: AppSpacing.xs,
                                children: _staffModuleIds.map((moduleId) {
                                  final selected = selectedModules.contains(
                                    moduleId,
                                  );
                                  return _permissionChip(
                                    moduleId: moduleId,
                                    selected: selected,
                                    disabled: !_subscribedModuleIds.contains(
                                      moduleId,
                                    ),
                                    readOnly: isSubmitting,
                                    onSelected: (enabled) {
                                      if (isSubmitting) return;
                                      setSheetState(() {
                                        if (enabled) {
                                          selectedModules.add(moduleId);
                                        } else {
                                          selectedModules.remove(moduleId);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                            if (formError != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Container(
                                width: double.infinity,
                                padding: AppInsets.md,
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: AppRadius.input,
                                  border: Border.all(
                                    color: AppColors.danger.withValues(
                                      alpha: 0.18,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  formError!,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.lg),
                            AppPrimaryButton(
                              label: 'Add ${_roleLabel(selectedRole)}',
                              icon: selectedRole == 'volunteer'
                                  ? Icons.volunteer_activism_outlined
                                  : Icons.person_add_alt_1,
                              fullWidth: true,
                              loading: isSubmitting,
                              onPressed: isSubmitting ? null : submit,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nameController.dispose();
        emailController.dispose();
        passwordController.dispose();
      });
    }
  }

  Future<void> _showEditStaffDialog(StaffUser staff) async {
    if (_careWards.isEmpty) {
      try {
        final wards = await WardService.getWards(forceRefresh: true);
        if (mounted) setState(() => _careWards = wards);
      } catch (_) {}
    }
    if (!mounted) return;
    final wardRequired = context.read<AuthService>().wardRestrictionEnabled;
    final assignableRoles = _assignableRoles;
    final nameController = TextEditingController(text: staff.name);
    final emailController = TextEditingController(text: staff.email);
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var selectedRole = assignableRoles.contains(staff.role) ? staff.role : '';
    var selectedModules = <String>{
      ...(staff.hasExplicitModulePermissions
          ? staff.permittedModuleIds
          : _modulesForRole(selectedRole.isEmpty ? staff.role : selectedRole)),
    };
    var selectedWardIds = staff.assignedWards.map((ward) => ward.id).toSet();
    var selectedWardLocalBody =
        _defaultWardLocalBody(selectedWardIds) ??
        (_wardLocalBodies.isNotEmpty ? _wardLocalBodies.first : null);
    var obscurePassword = true;
    var saving = false;
    var modulesExpanded = false;
    String? errorMessage;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              if (saving || !(formKey.currentState?.validate() ?? false)) {
                return;
              }
              if (wardRequired &&
                  selectedRole == 'staff' &&
                  selectedWardIds.isEmpty) {
                setDialogState(() {
                  errorMessage = 'Select at least one ward for a staff user';
                });
                return;
              }
              setDialogState(() {
                saving = true;
                errorMessage = null;
              });
              try {
                final updated = await StaffService.updateStaff(
                  id: staff.id,
                  name: nameController.text,
                  email: emailController.text,
                  role: selectedRole,
                  permittedModuleIds: selectedModules.toList(),
                  wardIds: selectedWardIds.toList(),
                  password: passwordController.text.trim().isEmpty
                      ? null
                      : passwordController.text,
                );
                if (!mounted) return;
                setState(() {
                  final index = _staff.indexWhere(
                    (item) => item.id == updated.id,
                  );
                  if (index >= 0) _staff[index] = updated;
                  _staff.sort(_compareStaffUsers);
                });
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text('${updated.name} updated'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } catch (error) {
                setDialogState(() {
                  saving = false;
                  errorMessage = error.toString();
                });
              }
            }

            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.dialog,
              ),
              title: const Row(
                children: [
                  Icon(Icons.manage_accounts_outlined, size: 21),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    'Edit user access',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 560,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: nameController,
                          enabled: !saving,
                          style: const TextStyle(
                            color: _inkColor,
                            fontSize: 14,
                          ),
                          decoration: _fieldDecoration(
                            labelText: 'Full name',
                            prefixIcon: Icons.person_outline,
                          ),
                          validator: (value) => value?.trim().isEmpty ?? true
                              ? 'Name is required'
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          controller: emailController,
                          enabled: !saving,
                          style: const TextStyle(
                            color: _inkColor,
                            fontSize: 14,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          decoration: _fieldDecoration(
                            labelText: 'Email',
                            prefixIcon: Icons.mail_outline,
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty) return 'Email is required';
                            if (!email.contains('@')) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          controller: passwordController,
                          enabled: !saving,
                          style: const TextStyle(
                            color: _inkColor,
                            fontSize: 14,
                          ),
                          obscureText: obscurePassword,
                          decoration: _fieldDecoration(
                            labelText: 'New password (optional)',
                            prefixIcon: Icons.lock_reset_outlined,
                            suffixIcon: IconButton(
                              tooltip: obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () => setDialogState(
                                () => obscurePassword = !obscurePassword,
                              ),
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if ((value ?? '').isNotEmpty && value!.length < 8) {
                              return 'Use at least 8 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        DropdownButtonFormField<String>(
                          initialValue: selectedRole.isEmpty
                              ? null
                              : selectedRole,
                          hint: const Text('Select an available role'),
                          style: const TextStyle(
                            color: _inkColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                          decoration: _fieldDecoration(
                            labelText: 'Role',
                            prefixIcon: Icons.admin_panel_settings_outlined,
                          ),
                          items: assignableRoles
                              .map(
                                (role) => DropdownMenuItem(
                                  value: role,
                                  child: Text(
                                    _roleLabel(role),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.normal,
                                      color: _inkColor,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          validator: (value) =>
                              value == null ? 'Select an available role' : null,
                          onChanged: saving
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setDialogState(() {
                                    selectedRole = value;
                                    selectedModules = {
                                      ..._modulesForRole(selectedRole),
                                    };
                                  });
                                },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildStaffWardPicker(
                          selectedLocalBody: selectedWardLocalBody,
                          selectedWardIds: selectedWardIds,
                          required: wardRequired && selectedRole == 'staff',
                          disabled: saving,
                          onLocalBodyChanged: (value) => setDialogState(
                            () => selectedWardLocalBody = value,
                          ),
                          onWardToggled: (wardId) => setDialogState(() {
                            selectedWardIds.contains(wardId)
                                ? selectedWardIds.remove(wardId)
                                : selectedWardIds.add(wardId);
                          }),
                        ),
                        if (wardRequired &&
                            selectedRole == 'staff' &&
                            selectedWardIds.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: AppSpacing.xs),
                            child: Text(
                              'At least one ward is required for staff.',
                              style: TextStyle(color: AppColors.danger),
                            ),
                          ),
                        const SizedBox(height: AppSpacing.md),
                        InkWell(
                          borderRadius: AppRadius.sm,
                          onTap: () => setDialogState(
                            () => modulesExpanded = !modulesExpanded,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface1,
                              borderRadius: AppRadius.input,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.tune_outlined,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Permitted modules',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelLarge
                                                ?.copyWith(
                                                  color: AppColors.text,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(width: AppSpacing.xs),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primarySoft,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '${selectedModules.length} selected',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        modulesExpanded
                                            ? 'Locked modules are not included in the current subscription.'
                                            : 'Default collapsed • Tap to view and edit module permissions',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.textMuted,
                                              fontSize: 11.5,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  modulesExpanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (modulesExpanded) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: _staffModuleIds.map((moduleId) {
                              return _permissionChip(
                                moduleId: moduleId,
                                selected: selectedModules.contains(moduleId),
                                disabled: !_subscribedModuleIds.contains(
                                  moduleId,
                                ),
                                readOnly: saving,
                                onSelected: (enabled) {
                                  if (saving) return;
                                  setDialogState(() {
                                    if (enabled) {
                                      selectedModules.add(moduleId);
                                    } else {
                                      selectedModules.remove(moduleId);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                        if (errorMessage != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            errorMessage!,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              actions: [
                Row(
                  children: [
                    Builder(
                      builder: (btnContext) {
                        final auth = btnContext.watch<AuthService>();
                        final isSelf =
                            staff.id == auth.userId ||
                            (auth.userEmail != null &&
                                auth.userEmail!.isNotEmpty &&
                                staff.email.toLowerCase() ==
                                    auth.userEmail!.toLowerCase());
                        if (isSelf || staff.role == 'admin') {
                          return const SizedBox.shrink();
                        }
                        return TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.danger,
                          ),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                          label: const Text('Delete user'),
                          onPressed: saving
                              ? null
                              : () {
                                  Navigator.pop(dialogContext);
                                  _confirmDeleteStaff(staff);
                                },
                        );
                      },
                    ),
                    const Spacer(),
                    AppSecondaryButton(
                      label: 'Cancel',
                      onPressed: saving
                          ? null
                          : () => Navigator.pop(dialogContext),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppPrimaryButton(
                      label: 'Save changes',
                      icon: Icons.check_circle_outline_rounded,
                      loading: saving,
                      onPressed: saving ? null : save,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nameController.dispose();
        emailController.dispose();
        passwordController.dispose();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final activeIndex = switch (widget.mode) {
      ConfigPageMode.settings => 0,
      ConfigPageMode.lsg => 0,
      ConfigPageMode.staff => 1,
      ConfigPageMode.combined => _tabController.index,
    };
    final pageTitle = switch (widget.mode) {
      ConfigPageMode.settings => 'Settings',
      ConfigPageMode.staff => 'Staff Management',
      ConfigPageMode.lsg => 'LSGs & Wards',
      ConfigPageMode.combined => 'System Config',
    };

    return AdaptiveAppScaffold(
      backgroundColor: _surfaceColor,
      appBar: AppBar(
        toolbarHeight: 76,
        titleSpacing: AppSpacing.md,
        title: Text(pageTitle, style: Theme.of(context).textTheme.titleLarge),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: auth.isAdmin && widget.mode == ConfigPageMode.combined
            ? PreferredSize(
                preferredSize: const Size.fromHeight(66),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppInsets.screenHorizontal(context),
                    0,
                    AppInsets.screenHorizontal(context),
                    AppSpacing.sm,
                  ),
                  child: _ConfigTabBar(controller: _tabController),
                ),
              )
            : null,
      ),
      body: auth.isAdmin
          ? Stack(
              children: [
                if (widget.mode == ConfigPageMode.settings)
                  _buildConfigurationView()
                else if (widget.mode == ConfigPageMode.staff)
                  _buildStaffView()
                else if (widget.mode == ConfigPageMode.lsg)
                  _buildLsgView()
                else
                  TabBarView(
                    controller: _tabController,
                    children: [_buildConfigurationView(), _buildStaffView()],
                  ),
                if (_isSavingConfig)
                  Container(
                    color: AppColors.scrim.withValues(alpha: 0.08),
                    child: Center(
                      child: AppCard(
                        padding: AppInsets.md,
                        surfaceLevel: AppSurfaceLevel.floating,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Saving changes',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : _buildAccessDenied(),
      floatingActionButton:
          auth.isAdmin &&
              !(activeIndex == 1 && _selectedStaffSection == 'role') &&
              widget.mode != ConfigPageMode.settings
          ? widget.mode == ConfigPageMode.lsg
                ? FloatingActionButton.extended(
                    onPressed:
                        _isLoadingConfig || _config == null || _isSavingConfig
                        ? null
                        : _saveConfig,
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save changes'),
                  )
                : RevealActionFab(
                    onPressed: activeIndex == 0
                        ? (_isLoadingConfig ||
                                  _config == null ||
                                  _isSavingConfig
                              ? null
                              : _saveConfig)
                        : (_isLoadingStaff
                              ? null
                              : () => _showAddStaffSheet(
                                  _staffRoleFilter == 'all'
                                      ? null
                                      : _staffRoleFilter,
                                )),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    icon: activeIndex == 0
                        ? Icons.save_outlined
                        : (_staffRoleFilter == 'volunteer'
                              ? Icons.volunteer_activism_outlined
                              : Icons.person_add),
                    label: activeIndex == 0
                        ? 'Save Changes'
                        : (_staffRoleFilter != 'all'
                              ? 'Add ${_roleLabel(_staffRoleFilter)}'
                              : 'Add User'),
                  )
          : null,
    );
  }

  Widget _buildAccessDenied() {
    return const AppEmptyState(
      icon: Icons.lock_outline,
      title: 'Admin Access Required',
      message: 'System configuration is available only for admin users.',
    );
  }

  Widget _buildLoadingList() {
    return Padding(
      padding: AppInsets.screen(
        context,
        top: AppSpacing.md,
        bottom: AppSpacing.md,
      ),
      child: const AppListSkeleton(itemCount: 5),
    );
  }

  Widget _buildConfigurationView() {
    if (_isLoadingConfig && _config == null) {
      return _buildLoadingList();
    }

    if (_configErrorMessage != null && _config == null) {
      return _ErrorState(message: _configErrorMessage!, onRetry: _fetchConfig);
    }

    final config = _config!;

    return RefreshIndicator(
      onRefresh: _fetchConfig,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          _buildSettingsSearchBar(),
          if (_settingsSearchQuery.isNotEmpty)
            _buildSettingsSearchResults(config)
          else ...[
            _buildSettingsGroupSection(
              header: 'OPERATIONS & SCHEDULE',
              items: [
                _SettingsItem(
                  title: 'Unit working hours',
                  subtitle: 'Displayed on the home top card',
                  icon: Icons.schedule_rounded,
                  trailingText: config.workingTime?.trim().isNotEmpty == true
                      ? config.workingTime!.trim()
                      : 'Not set',
                  onTap: _openWorkingTimeEditorDialog,
                ),
                _SettingsItem(
                  title: 'Volunteer shift hours',
                  subtitle: 'Daily availability window',
                  icon: Icons.access_time_rounded,
                  trailingText:
                      '${config.volunteerAvailabilityStartTime.isNotEmpty ? config.volunteerAvailabilityStartTime : '09:30 AM'} - ${config.volunteerAvailabilityEndTime.isNotEmpty ? config.volunteerAvailabilityEndTime : '03:30 PM'}',
                  onTap: _openAvailabilityTimeDialog,
                ),
                _SettingsItem(
                  title: 'Volunteer working days',
                  subtitle: 'Days volunteers can be assigned',
                  icon: Icons.calendar_month_outlined,
                  trailingText: _getWorkingDaysSummary(config.workingDays),
                  onTap: _openWorkingDaysDialog,
                ),
              ],
            ),
            _buildSettingsGroupSection(
              header: 'CARE STRUCTURE & WARDS',
              items: [
                _SettingsItem(
                  title: 'LSGs & Wards',
                  subtitle: 'Villages, municipalities & ward numbers',
                  icon: Icons.holiday_village_outlined,
                  trailingText:
                      '${config.villages.length} local bodies • ${config.wards.length} wards',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const ConfigPage(mode: ConfigPageMode.lsg),
                      ),
                    );
                  },
                ),
              ],
            ),
            _buildSettingsGroupSection(
              header: 'CLINICAL MASTER DATA',
              items: [
                _SettingsItem(
                  title: 'Diseases catalog',
                  subtitle: 'Medical conditions for patient files',
                  icon: Icons.medical_information_outlined,
                  trailingText: '${config.diseases.length} diseases',
                  onTap: () => _openMasterListPage(
                    title: 'Diseases Catalog',
                    icon: Icons.medical_information_outlined,
                    listName: 'diseases',
                    hintText: 'Add disease',
                  ),
                ),
                _SettingsItem(
                  title: 'Care plans',
                  subtitle: 'Standard plan templates for visits',
                  icon: Icons.event_repeat_outlined,
                  trailingText: '${config.plans.length} plans',
                  onTap: () => _openMasterListPage(
                    title: 'Care Plans',
                    icon: Icons.event_repeat_outlined,
                    listName: 'plans',
                    hintText: 'Add care plan',
                  ),
                ),
              ],
            ),
            _buildSettingsGroupSection(
              header: 'PATIENT TRANSFER & SAFETY',
              items: [
                _SettingsItem(
                  title: 'Patient transfer review',
                  subtitle: 'Approval expiry & required checks',
                  icon: Icons.swap_horiz_rounded,
                  trailingText:
                      '${config.transferSettings.expiryDays} day expiry',
                  onTap: _openTransferSettingsPage,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsSearchBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: TextField(
        controller: _settingsSearchController,
        style: const TextStyle(fontSize: 14, color: AppColors.text),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search settings',
          hintStyle: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13.5,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textMuted,
            size: 20,
          ),
          suffixIcon: _settingsSearchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () {
                    _settingsSearchController.clear();
                    setState(() => _settingsSearchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 11,
          ),
        ),
        onChanged: (val) =>
            setState(() => _settingsSearchQuery = val.trim().toLowerCase()),
      ),
    );
  }

  Widget _buildSettingsGroupSection({
    required String header,
    required List<_SettingsItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8, top: 18),
          child: Text(
            header,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 0.7,
                      indent: 58,
                      endIndent: 0,
                      color: AppColors.border.withValues(alpha: 0.6),
                    ),
                  _buildSettingsRow(items[i]),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsRow(_SettingsItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _softAccentColor,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(item.icon, size: 20, color: _primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                        height: 1.2,
                      ),
                    ),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (item.trailingText != null) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    item.trailingText!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSearchResults(Config config) {
    final allItems = [
      _SettingsItem(
        title: 'Unit working hours',
        subtitle: 'Displayed on the home top card',
        icon: Icons.schedule_rounded,
        trailingText: config.workingTime?.trim().isNotEmpty == true
            ? config.workingTime!.trim()
            : 'Not set',
        onTap: _openWorkingTimeEditorDialog,
      ),
      _SettingsItem(
        title: 'Volunteer shift hours',
        subtitle: 'Daily availability window',
        icon: Icons.access_time_rounded,
        trailingText:
            '${config.volunteerAvailabilityStartTime.isNotEmpty ? config.volunteerAvailabilityStartTime : '09:30 AM'} - ${config.volunteerAvailabilityEndTime.isNotEmpty ? config.volunteerAvailabilityEndTime : '03:30 PM'}',
        onTap: _openAvailabilityTimeDialog,
      ),
      _SettingsItem(
        title: 'Volunteer working days',
        subtitle: 'Days volunteers can be assigned',
        icon: Icons.calendar_month_outlined,
        trailingText: _getWorkingDaysSummary(config.workingDays),
        onTap: _openWorkingDaysDialog,
      ),
      _SettingsItem(
        title: 'LSGs & Wards',
        subtitle: 'Villages, municipalities & ward numbers',
        icon: Icons.holiday_village_outlined,
        trailingText:
            '${config.villages.length} local bodies • ${config.wards.length} wards',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ConfigPage(mode: ConfigPageMode.lsg),
            ),
          );
        },
      ),
      _SettingsItem(
        title: 'Diseases catalog',
        subtitle: 'Medical conditions for patient files',
        icon: Icons.medical_information_outlined,
        trailingText: '${config.diseases.length} diseases',
        onTap: () => _openMasterListPage(
          title: 'Diseases Catalog',
          icon: Icons.medical_information_outlined,
          listName: 'diseases',
          hintText: 'Add disease',
        ),
      ),
      _SettingsItem(
        title: 'Care plans',
        subtitle: 'Standard plan templates for visits',
        icon: Icons.event_repeat_outlined,
        trailingText: '${config.plans.length} plans',
        onTap: () => _openMasterListPage(
          title: 'Care Plans',
          icon: Icons.event_repeat_outlined,
          listName: 'plans',
          hintText: 'Add care plan',
        ),
      ),
      _SettingsItem(
        title: 'Patient transfer review',
        subtitle: 'Approval expiry & required checks',
        icon: Icons.swap_horiz_rounded,
        trailingText: '${config.transferSettings.expiryDays} day expiry',
        onTap: _openTransferSettingsPage,
      ),
    ];

    final matched = allItems.where((item) {
      final t = item.title.toLowerCase();
      final s = (item.subtitle ?? '').toLowerCase();
      return t.contains(_settingsSearchQuery) ||
          s.contains(_settingsSearchQuery);
    }).toList();

    if (matched.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 40,
                color: AppColors.textMuted,
              ),
              SizedBox(height: AppSpacing.xs),
              Text(
                'No matching settings found',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13.5),
              ),
            ],
          ),
        ),
      );
    }

    return _buildSettingsGroupSection(
      header: 'MATCHING SETTINGS (${matched.length})',
      items: matched,
    );
  }

  String _getWorkingDaysSummary(List<int> days) {
    if (days.isEmpty) return 'Not set';
    if (days.length == 7) return 'All 7 days';
    if (days.length == 6 && !days.contains(DateTime.sunday)) return 'Mon - Sat';
    if (days.length == 5 &&
        !days.contains(DateTime.saturday) &&
        !days.contains(DateTime.sunday)) {
      return 'Mon - Fri';
    }
    return '${days.length} days active';
  }

  Future<void> _openWorkingDaysDialog() async {
    final config = _config;
    if (config == null) return;
    const days = [
      (value: DateTime.monday, label: 'Monday'),
      (value: DateTime.tuesday, label: 'Tuesday'),
      (value: DateTime.wednesday, label: 'Wednesday'),
      (value: DateTime.thursday, label: 'Thursday'),
      (value: DateTime.friday, label: 'Friday'),
      (value: DateTime.saturday, label: 'Saturday'),
      (value: DateTime.sunday, label: 'Sunday'),
    ];
    final selectedDays = Set<int>.from(config.workingDays);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _softAccentColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.calendar_month_outlined,
                      color: _primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Text(
                      'Volunteer Working Days',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Select which days volunteers are available to be assigned visits.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: days.map((day) {
                  final selected = selectedDays.contains(day.value);
                  return FilterChip(
                    selected: selected,
                    showCheckmark: true,
                    label: Text(day.label),
                    onSelected: (val) {
                      setModalState(() {
                        if (val) {
                          selectedDays.add(day.value);
                        } else {
                          selectedDays.remove(day.value);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    Navigator.pop(modalCtx);
                    final sorted = selectedDays.toList()..sort();
                    setState(() {
                      _config?.workingDays.clear();
                      _config?.workingDays.addAll(sorted);
                    });
                    await _saveConfig();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.button,
                    ),
                  ),
                  child: const Text(
                    'Save Working Days',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAvailabilityTimeDialog() async {
    final config = _config;
    if (config == null) return;
    var start = config.volunteerAvailabilityStartTime.isNotEmpty
        ? config.volunteerAvailabilityStartTime
        : '09:30 AM';
    var end = config.volunteerAvailabilityEndTime.isNotEmpty
        ? config.volunteerAvailabilityEndTime
        : '03:30 PM';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _softAccentColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.access_time_rounded,
                      color: _primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Text(
                      'Volunteer Shift Hours',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Standard daily shift time window displayed to volunteers.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _buildTimePickerTile(
                      label: 'Start time',
                      value: start,
                      onTap: () async {
                        final initial =
                            _parseTimeOfDay(start) ??
                            const TimeOfDay(hour: 9, minute: 30);
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: initial,
                        );
                        if (picked != null) {
                          setModalState(() => start = _formatTimeOfDay(picked));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _buildTimePickerTile(
                      label: 'End time',
                      value: end,
                      onTap: () async {
                        final initial =
                            _parseTimeOfDay(end) ??
                            const TimeOfDay(hour: 15, minute: 30);
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: initial,
                        );
                        if (picked != null) {
                          setModalState(() => end = _formatTimeOfDay(picked));
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    Navigator.pop(modalCtx);
                    setState(() {
                      _config?.volunteerAvailabilityStartTime = start;
                      _config?.volunteerAvailabilityEndTime = end;
                    });
                    await _saveConfig();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.button,
                    ),
                  ),
                  child: const Text(
                    'Save Shift Hours',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMasterListPage({
    required String title,
    required IconData icon,
    required String listName,
    required String hintText,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _MasterListSettingsPage(
          title: title,
          icon: icon,
          listName: listName,
          hintText: hintText,
          configState: this,
        ),
      ),
    );
  }

  void _openTransferSettingsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _TransferSettingsPage(configState: this),
      ),
    );
  }

  Widget _buildLsgNavigationCard(Config config) {
    return _SectionCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: AppRadius.card,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ConfigPage(mode: ConfigPageMode.lsg),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const _IconBadge(
                icon: Icons.holiday_village_outlined,
                color: _primaryColor,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LSGs & Wards',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${config.villages.length} local bodies • ${config.wards.length} wards',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLsgView() {
    if (_isLoadingConfig && _config == null) {
      return _buildLoadingList();
    }

    if (_configErrorMessage != null && _config == null) {
      return _ErrorState(message: _configErrorMessage!, onRetry: _fetchConfig);
    }

    final config = _config!;

    return RefreshIndicator(
      onRefresh: _fetchConfig,
      child: ListView(
        padding: AppInsets.screen(context, top: AppSpacing.sm, bottom: 96),
        children: [
          _buildLsgOverviewHeader(config),
          const SizedBox(height: AppSpacing.sm),
          _buildLsgManagementCard(config),
        ],
      ),
    );
  }

  Widget _buildLsgOverviewHeader(Config config) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBadge(
                icon: Icons.holiday_village_outlined,
                color: _primaryColor,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Local Bodies & Wards',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Village • Municipality • Corporation',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _isLoadingConfig ? null : _fetchConfig,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricPill(
                label: 'Local bodies',
                value: config.villages.length.toString(),
                icon: Icons.location_city_outlined,
              ),
              _MetricPill(
                label: 'Total Wards',
                value: config.wards.length.toString(),
                icon: Icons.map_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLsgManagementCard(Config config) {
    final wards = sortWardConfigs(config.wards);
    final selectedLocalBody = _selectedWardVillage;
    final selectedWards = selectedLocalBody == null
        ? const <WardConfig>[]
        : wards.where((ward) => ward.village == selectedLocalBody).toList();

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LsgSectionHeader(
            icon: Icons.location_city_outlined,
            title: 'Local bodies',
            subtitle: 'Village, municipality, or corporation',
            count: config.villages.length,
          ),
          const SizedBox(height: AppSpacing.sm),
          _AddInlineField(
            controller: _villageController,
            hintText: 'Add local body',
            compact: true,
            onSubmitted: () => _addItem('villages', _villageController),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (config.villages.isEmpty)
            const _EmptyInlineState(
              label: 'No local bodies added yet',
              compact: true,
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: config.villages.map((localBody) {
                return _ConfigChip(
                  label: Text(localBody),
                  icon: Icons.location_city_outlined,
                  onDeleted: () => _removeItem('villages', localBody),
                );
              }).toList(),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Divider(height: 1),
          ),
          _LsgSectionHeader(
            icon: Icons.map_outlined,
            title: 'Wards',
            subtitle:
                selectedLocalBody ?? 'Select a local body to manage its wards',
            count: wards.length,
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final localBodyField = DropdownButtonFormField<String>(
                key: ValueKey(_selectedWardVillage),
                initialValue: _selectedWardVillage,
                isExpanded: true,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.normal,
                  color: AppColors.text,
                ),
                decoration: _fieldDecoration(
                  labelText: 'Local body',
                  prefixIcon: Icons.location_city_outlined,
                ),
                items: config.villages
                    .map(
                      (localBody) => DropdownMenuItem(
                        value: localBody,
                        child: Text(
                          localBody,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.normal,
                            color: AppColors.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: config.villages.isEmpty
                    ? null
                    : (value) => setState(() => _selectedWardVillage = value),
              );
              final wardField = _AddInlineField(
                controller: _wardController,
                hintText: 'Add wards, separated by commas',
                compact: true,
                enabled: config.villages.isNotEmpty,
                keyboardType: TextInputType.text,
                onSubmitted: _addWard,
              );

              if (constraints.maxWidth >= 560) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: localBodyField),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: wardField),
                  ],
                );
              }
              return Column(
                children: [
                  localBodyField,
                  const SizedBox(height: AppSpacing.xs),
                  wardField,
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          if (selectedLocalBody == null)
            const _EmptyInlineState(
              label: 'Add a local body before adding wards',
              compact: true,
            )
          else if (selectedWards.isEmpty)
            _EmptyInlineState(
              label: 'No wards added for $selectedLocalBody yet',
              compact: true,
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: selectedWards.map((ward) {
                return _ConfigChip(
                  label: Text(formatWardLabel(ward.number)),
                  icon: Icons.map_outlined,
                  onDeleted: () => _removeWard(ward),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildOverviewHeader(Config config) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBadge(
                icon: Icons.admin_panel_settings,
                color: _primaryColor,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Configuration Hub',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _isLoadingConfig ? null : _fetchConfig,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricPill(
                label: 'Local bodies',
                value: config.villages.length.toString(),
                icon: Icons.location_city_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const ConfigPage(mode: ConfigPageMode.lsg),
                    ),
                  );
                },
              ),
              _MetricPill(
                label: 'Wards',
                value: config.wards.length.toString(),
                icon: Icons.map_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const ConfigPage(mode: ConfigPageMode.lsg),
                    ),
                  );
                },
              ),
              _MetricPill(
                label: 'Diseases',
                value: config.diseases.length.toString(),
                icon: Icons.medical_information_outlined,
              ),
              _MetricPill(
                label: 'Plans',
                value: config.plans.length.toString(),
                icon: Icons.event_repeat_outlined,
              ),
              _MetricPill(
                label: 'Working days',
                value: config.workingDays.length.toString(),
                icon: Icons.event_available_outlined,
              ),
              _MetricPill(
                label: 'Shift hours',
                value: config.volunteerAvailabilityTimeWindow,
                icon: Icons.schedule_outlined,
              ),
              _MetricPill(
                label: 'Working time',
                value: config.workingTime?.trim().isNotEmpty == true
                    ? config.workingTime!.trim()
                    : 'Not set',
                icon: Icons.schedule_rounded,
                onTap: _openWorkingTimeEditorDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnitWorkingTimeSection() {
    final current = _config?.workingTime?.trim();
    final isConfigured = current != null && current.isNotEmpty;

    return _ConfigSection(
      title: 'Unit working hours',
      icon: Icons.schedule_rounded,
      badgeText: isConfigured ? 'Active' : 'Not set',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Displayed on the home top card for this unit. Leave empty if you do not want working hours shown.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: isConfigured
                  ? AppColors.primaryLight.withValues(alpha: 0.35)
                  : AppColors.surface1,
              borderRadius: AppRadius.sm,
              border: Border.all(
                color: isConfigured
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isConfigured
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : AppColors.surface,
                    borderRadius: AppRadius.sm,
                  ),
                  child: Icon(
                    isConfigured
                        ? Icons.schedule_rounded
                        : Icons.timer_off_outlined,
                    size: 20,
                    color: isConfigured
                        ? AppColors.primary
                        : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isConfigured
                            ? 'Active Working Hours'
                            : 'Status: Hidden',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isConfigured
                            ? current
                            : 'Not set for this unit. Top card will not display working hours.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isConfigured
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isConfigured
                              ? AppColors.text
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                FilledButton.tonalIcon(
                  onPressed: _openWorkingTimeEditorDialog,
                  icon: Icon(
                    isConfigured ? Icons.edit_rounded : Icons.add_rounded,
                    size: 16,
                  ),
                  label: Text(isConfigured ? 'Edit' : 'Set time'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
                if (isConfigured) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Clear working time',
                    icon: const Icon(
                      Icons.clear_rounded,
                      size: 18,
                      color: AppColors.danger,
                    ),
                    onPressed: _clearUnitWorkingTime,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openWorkingTimeEditorDialog() async {
    final current = _config?.workingTime?.trim() ?? '';
    final controller = TextEditingController(text: current);
    const presets = [
      'Mon - Sat: 9:00am - 4:30pm',
      'Monday to Saturday 9:00am to 4:30pm',
      'Mon - Fri: 9:00am - 5:00pm',
      'All Days: 9:00am - 5:00pm',
    ];

    final result = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.dialog),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: AppRadius.sm,
                ),
                child: const Icon(
                  Icons.schedule_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Text(
                  'Set Unit Working Time',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This text will appear in the top dashboard card of the home screen for your unit.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: controller,
                  decoration: _fieldDecoration(
                    labelText: 'Working time text',
                    hintText: 'e.g. Mon - Sat: 9:00am - 4:30pm',
                    prefixIcon: Icons.schedule_rounded,
                    suffixIcon: controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              controller.clear();
                              setDialogState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Quick suggestions:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: presets.map((preset) {
                    final isSelected = controller.text.trim() == preset;
                    return ActionChip(
                      label: Text(
                        preset,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.text,
                        ),
                      ),
                      backgroundColor: isSelected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.surface1,
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                      onPressed: () {
                        controller.text = preset;
                        setDialogState(() {});
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(null),
              child: const Text('Cancel'),
            ),
            if (current.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop('__CLEAR__'),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Clear / Hide'),
              ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop(controller.text.trim());
              },
              child: const Text('Save & Apply'),
            ),
          ],
        ),
      ),
    );

    if (result == null || !mounted) return;

    if (result == '__CLEAR__') {
      await _clearUnitWorkingTime();
    } else {
      setState(() {
        _config?.workingTime = result;
      });
      await _saveConfig();
    }
  }

  Future<void> _clearUnitWorkingTime() async {
    if (_config == null) return;
    setState(() {
      _config?.workingTime = '';
    });
    await _saveConfig();
  }

  Widget _buildTransferSettingsSection() {
    final settings = _config!.transferSettings;
    const checks = [
      (key: 'identity_verified', label: 'Identity verified'),
      (key: 'address_verified', label: 'Address verified'),
      (key: 'consent_confirmed', label: 'Consent confirmed'),
      (key: 'records_reviewed', label: 'Records reviewed'),
    ];
    final expiryOptions = <int>{
      3,
      7,
      14,
      30,
      60,
      90,
      settings.expiryDays,
    }.toList()..sort();
    return _ConfigSection(
      title: 'Patient transfer review',
      icon: Icons.swap_horiz_rounded,
      badgeText: '${settings.expiryDays} day expiry',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set when pending requests expire and which checks destination '
            'administrators must complete before accepting.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<int>(
            initialValue: settings.expiryDays,
            isExpanded: true,
            style: const TextStyle(
              color: _inkColor,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            decoration: const InputDecoration(
              labelText: 'Pending request expiry',
              prefixIcon: Icon(Icons.timer_outlined),
            ),
            items: expiryOptions
                .map(
                  (days) => DropdownMenuItem(
                    value: days,
                    child: Text(
                      '$days days',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => settings.expiryDays = value);
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Required acceptance checks',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: checks.map((check) {
              final selected = settings.requiredChecks.contains(check.key);
              return FilterChip(
                selected: selected,
                showCheckmark: true,
                label: Text(check.label),
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      settings.requiredChecks.add(check.key);
                    } else {
                      settings.requiredChecks.remove(check.key);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkingDaysSection() {
    const days = [
      (value: DateTime.monday, label: 'Monday'),
      (value: DateTime.tuesday, label: 'Tuesday'),
      (value: DateTime.wednesday, label: 'Wednesday'),
      (value: DateTime.thursday, label: 'Thursday'),
      (value: DateTime.friday, label: 'Friday'),
      (value: DateTime.saturday, label: 'Saturday'),
      (value: DateTime.sunday, label: 'Sunday'),
    ];
    final selectedDays = _config?.workingDays ?? const <int>[];
    return _ConfigSection(
      title: 'Volunteer working days',
      icon: Icons.event_available_outlined,
      count: selectedDays.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Volunteers can request availability only on these weekdays.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: days.map((day) {
              final selected = selectedDays.contains(day.value);
              return FilterChip(
                selected: selected,
                showCheckmark: true,
                label: Text(day.label),
                onSelected: (value) => _toggleWorkingDay(day.value, value),
              );
            }).toList(),
          ),
          if (selectedDays.isEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'No dates will be available until at least one day is selected.',
              style: TextStyle(color: AppColors.warning, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvailabilityTimeSection() {
    final startTime = _config?.volunteerAvailabilityStartTime.isNotEmpty == true
        ? _config!.volunteerAvailabilityStartTime
        : '09:30 AM';
    final endTime = _config?.volunteerAvailabilityEndTime.isNotEmpty == true
        ? _config!.volunteerAvailabilityEndTime
        : '03:30 PM';
    return _ConfigSection(
      title: 'Volunteer availability time',
      icon: Icons.schedule_outlined,
      badgeText: '$startTime - $endTime',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set the standard shift or availability hours shown to volunteers (e.g. 9:30 AM to 3:30 PM).',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildTimePickerTile(
                  label: 'Start time',
                  value: startTime,
                  onTap: () => _pickAvailabilityTime(isStart: true),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildTimePickerTile(
                  label: 'End time',
                  value: endTime,
                  onTap: () => _pickAvailabilityTime(isStart: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Active time window: $startTime to $endTime',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickerTile({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.sm,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.sm,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.access_time_rounded,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_drop_down_rounded,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAvailabilityTime({required bool isStart}) async {
    if (_config == null) return;
    final currentStr = isStart
        ? _config!.volunteerAvailabilityStartTime
        : _config!.volunteerAvailabilityEndTime;
    final initial =
        _parseTimeOfDay(currentStr) ??
        (isStart
            ? const TimeOfDay(hour: 9, minute: 30)
            : const TimeOfDay(hour: 15, minute: 30));

    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !mounted) return;

    final formatted = _formatTimeOfDay(picked);
    setState(() {
      if (isStart) {
        _config!.volunteerAvailabilityStartTime = formatted;
      } else {
        _config!.volunteerAvailabilityEndTime = formatted;
      }
    });
  }

  static TimeOfDay? _parseTimeOfDay(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return null;
    final trimmed = timeStr.trim().toUpperCase();
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$').firstMatch(trimmed);
    if (match == null) return null;
    var hour = int.tryParse(match.group(1)!) ?? 0;
    final minute = int.tryParse(match.group(2)!) ?? 0;
    final period = match.group(3);
    if (period == 'PM' && hour < 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  Widget _buildListSection({
    required String title,
    required IconData icon,
    required String listName,
    required List<String> items,
    required TextEditingController controller,
    required String hintText,
  }) {
    return _ConfigSection(
      title: title,
      icon: icon,
      count: items.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AddInlineField(
            controller: controller,
            hintText: hintText,
            onSubmitted: () => _addItem(listName, controller),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (items.isEmpty)
            _EmptyInlineState(label: 'No ${title.toLowerCase()} added yet')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((item) {
                return _ConfigChip(
                  label: Text(item),
                  icon: icon,
                  onDeleted: () => _removeItem(listName, item),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildStaffSectionTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: AppRadius.input,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final item in const [
            (value: 'staff', label: 'Staff', icon: Icons.groups_2_outlined),
            (value: 'role', label: 'Role', icon: Icons.rule_folder_outlined),
          ])
            Expanded(
              child: Material(
                color: _selectedStaffSection == item.value
                    ? AppColors.surface
                    : Colors.transparent,
                borderRadius: AppRadius.sm,
                child: InkWell(
                  borderRadius: AppRadius.sm,
                  onTap: () =>
                      setState(() => _selectedStaffSection = item.value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.icon,
                          size: 16,
                          color: _selectedStaffSection == item.value
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: _selectedStaffSection == item.value
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStaffView() {
    if (_isLoadingStaff && _staff.isEmpty) {
      return _buildLoadingList();
    }

    if (_staffErrorMessage != null && _staff.isEmpty) {
      return _ErrorState(message: _staffErrorMessage!, onRetry: _fetchStaff);
    }

    final roleCounts = {
      for (final role in _roles)
        role: _staff.where((staff) => staff.role == role).length,
    };

    final filteredStaff = _staff.where((staff) {
      if (_staffRoleFilter != 'all' && staff.role != _staffRoleFilter) {
        return false;
      }
      if (_staffWardFilter != 'all' &&
          !staff.assignedWards.any((ward) => ward.id == _staffWardFilter)) {
        return false;
      }
      if (_staffSearchQuery.isNotEmpty) {
        final query = _staffSearchQuery.toLowerCase();
        final matchesName = staff.name.toLowerCase().contains(query);
        final matchesEmail = staff.email.toLowerCase().contains(query);
        final matchesRole = _roleLabel(
          staff.role,
        ).toLowerCase().contains(query);
        if (!matchesName && !matchesEmail && !matchesRole) return false;
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _fetchStaff,
      child: ListView(
        padding: AppInsets.screen(context, top: AppSpacing.md, bottom: 112),
        children: [
          _buildStaffSectionTabs(),
          const SizedBox(height: AppSpacing.sm),
          if (_selectedStaffSection == 'role')
            _buildRolePermissionDefaults()
          else ...[
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _IconBadge(
                        icon: Icons.groups_2_outlined,
                        color: _primaryColor,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Staff Module',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: _isLoadingStaff ? null : _fetchStaff,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetricPill(
                        label: 'Total',
                        value: _staff.length.toString(),
                        icon: Icons.badge_outlined,
                        isSelected: _staffRoleFilter == 'all',
                        onTap: () => setState(() => _staffRoleFilter = 'all'),
                      ),
                      for (final role in _roles)
                        _MetricPill(
                          label: _roleLabel(role),
                          value: (roleCounts[role] ?? 0).toString(),
                          icon: _roleIcon(role),
                          isSelected: _staffRoleFilter == role,
                          onTap: () => setState(() => _staffRoleFilter = role),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _staffSearchController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search by name, email, or role...',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      suffixIcon: _staffSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () {
                                _staffSearchController.clear();
                                setState(() => _staffSearchQuery = '');
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      filled: true,
                      fillColor: _ConfigPageState._fieldFillColor,
                      border: const OutlineInputBorder(
                        borderRadius: AppRadius.sm,
                        borderSide: BorderSide(
                          color: _ConfigPageState._lineColor,
                        ),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderRadius: AppRadius.sm,
                        borderSide: BorderSide(
                          color: _ConfigPageState._lineColor,
                        ),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: AppRadius.sm,
                        borderSide: BorderSide(
                          color: _primaryColor,
                          width: 1.4,
                        ),
                      ),
                    ),
                    onChanged: (val) =>
                        setState(() => _staffSearchQuery = val.trim()),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String>(
                    initialValue: _staffWardFilter,
                    isExpanded: true,
                    style: const TextStyle(
                      color: _inkColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                    decoration: _fieldDecoration(
                      labelText: 'Filter by ward',
                      prefixIcon: Icons.local_hospital_outlined,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text(
                          'All wards',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      ..._careWards
                          .where((ward) => ward.isActive)
                          .map(
                            (ward) => DropdownMenuItem(
                              value: ward.id,
                              child: Text(
                                ward.fullLabel,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                    ],
                    onChanged: (value) =>
                        setState(() => _staffWardFilter = value ?? 'all'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (filteredStaff.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(
                  child: Text(
                    _staff.isEmpty
                        ? 'No staff members found'
                        : 'No results matching your filter',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
              )
            else
              ...filteredStaff.map(_buildStaffCard),
          ],
        ],
      ),
    );
  }

  Widget _buildStaffCard(StaffUser staff) {
    final isUpdating = _updatingStaffIds.contains(staff.id);
    final assignableRoles = _assignableRoles;
    final currentRoleIsAssignable = assignableRoles.contains(staff.role);
    final joined = staff.createdAt == null
        ? 'Joined date unavailable'
        : 'Joined ${DateFormat('dd MMM yyyy').format(staff.createdAt!.toLocal())}';

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: AppInsets.md,
      surfaceLevel: AppSurfaceLevel.elevated,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 540;
          final profile = Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _roleColor(staff.role).withValues(alpha: 0.10),
                  borderRadius: AppRadius.md,
                ),
                child: Text(
                  staff.name.isNotEmpty ? staff.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: _roleColor(staff.role),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staff.name.isEmpty ? 'Unnamed staff' : staff.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      staff.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      joined,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit access and permissions',
                onPressed: isUpdating
                    ? null
                    : () => _showEditStaffDialog(staff),
                icon: const Icon(Icons.edit_outlined),
              ),
              Builder(
                builder: (btnContext) {
                  final auth = btnContext.watch<AuthService>();
                  final isSelf =
                      staff.id == auth.userId ||
                      (auth.userEmail != null &&
                          auth.userEmail!.isNotEmpty &&
                          staff.email.toLowerCase() ==
                              auth.userEmail!.toLowerCase());
                  if (isSelf || staff.role == 'admin') {
                    return const SizedBox.shrink();
                  }
                  return IconButton(
                    tooltip: 'Delete user',
                    color: AppColors.danger,
                    onPressed: isUpdating
                        ? null
                        : () => _confirmDeleteStaff(staff),
                    icon: const Icon(Icons.delete_outline_rounded),
                  );
                },
              ),
            ],
          );

          final visibleModules = staff.hasExplicitModulePermissions
              ? staff.permittedModuleIds
              : _modulesForRole(staff.role);
          final isModulesExpanded = _expandedStaffModuleCardIds.contains(
            staff.id,
          );

          final permissions = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (staff.assignedWards.isNotEmpty) ...[
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: staff.assignedWards
                      .map(
                        (ward) => Chip(
                          avatar: const Icon(
                            Icons.local_hospital_outlined,
                            size: 15,
                          ),
                          label: Text(ward.fullLabel),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: AppSpacing.xs),
              ] else if (staff.role == 'staff') ...[
                const Text(
                  'No ward assigned',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              const SizedBox(height: AppSpacing.xs),
              InkWell(
                borderRadius: AppRadius.sm,
                onTap: () {
                  setState(() {
                    if (isModulesExpanded) {
                      _expandedStaffModuleCardIds.remove(staff.id);
                    } else {
                      _expandedStaffModuleCardIds.add(staff.id);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        isModulesExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Permitted modules',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${visibleModules.length} enabled',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        isModulesExpanded ? 'Hide' : 'Show',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isModulesExpanded) ...[
                const SizedBox(height: AppSpacing.xs),
                if (visibleModules.isEmpty)
                  Text(
                    'No modules permitted',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
                  )
                else
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: visibleModules
                        .map(
                          (moduleId) => Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: const Icon(Icons.check_rounded, size: 15),
                            label: Text(AppFeature.label(moduleId)),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ],
          );

          final roleControl = SizedBox(
            width: compact ? double.infinity : 190,
            child: DropdownButtonFormField<String>(
              key: ValueKey('${staff.id}:${staff.role}'),
              initialValue: currentRoleIsAssignable ? staff.role : null,
              hint: const Text('Select an available role'),
              style: const TextStyle(
                color: _inkColor,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
              decoration: _fieldDecoration(
                labelText: 'Role',
                prefixIcon: isUpdating
                    ? null
                    : currentRoleIsAssignable
                    ? _roleIcon(staff.role)
                    : Icons.admin_panel_settings_outlined,
                suffixIcon: isUpdating
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              items: assignableRoles
                  .map(
                    (role) => DropdownMenuItem(
                      value: role,
                      child: Text(
                        _roleLabel(role),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: isUpdating
                  ? null
                  : (role) {
                      if (role != null) _updateStaffRole(staff, role);
                    },
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                profile,
                const SizedBox(height: 14),
                roleControl,
                permissions,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: profile),
                  const SizedBox(width: 16),
                  roleControl,
                ],
              ),
              permissions,
            ],
          );
        },
      ),
    );
  }

  static int _compareStaffUsers(StaffUser a, StaffUser b) {
    final aIndex = _roles.indexOf(a.role);
    final bIndex = _roles.indexOf(b.role);
    final roleCompare = (aIndex == -1 ? 99 : aIndex).compareTo(
      bIndex == -1 ? 99 : bIndex,
    );
    if (roleCompare != 0) return roleCompare;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  String _roleLabel(String role) {
    return context.read<AuthService>().roleLabel(role);
  }

  static List<String> _defaultModulesForRole(String role) {
    if (role == 'admin') return List<String>.from(_staffModuleIds);
    if (role == 'member' || role == 'volunteer') {
      return const [
        AppFeature.patients,
        AppFeature.homeVisits,
        AppFeature.volunteers,
        AppFeature.socialSupport,
      ];
    }
    return _staffModuleIds
        .where((moduleId) => moduleId != AppFeature.advancedReports)
        .toList();
  }

  List<String> _modulesForRole(String role) {
    final saved = _rolePermissionDefaults[role];
    if (saved != null) {
      return saved.where(_subscribedModuleIds.contains).toList(growable: false);
    }
    return _defaultModulesForRole(
      role,
    ).where(_subscribedModuleIds.contains).toList(growable: false);
  }

  static IconData _roleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings_outlined;
      case 'staff':
        return Icons.medical_services_outlined;
      case 'member':
        return Icons.people_outline_rounded;
      case 'volunteer':
        return Icons.volunteer_activism_outlined;
      default:
        return Icons.person_outline;
    }
  }

  static Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return _primaryColor;
      case 'staff':
        return const Color(0xFF0F6E56);
      case 'member':
        return const Color(0xFF8A2454);
      case 'volunteer':
        return const Color(0xFFDB2777);
      default:
        return const Color(0xFF656A73);
    }
  }
}

class _ConfigTabBar extends StatelessWidget {
  const _ConfigTabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadius.button,
        border: Border.all(color: AppColors.border),
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        indicator: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.md,
          boxShadow: AppShadow.small,
        ),
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.tune_outlined, size: 18),
                SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text('Configuration', overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.groups_2_outlined, size: 18),
                SizedBox(width: AppSpacing.xs),
                Flexible(child: Text('Staff', overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigSection extends StatelessWidget {
  const _ConfigSection({
    required this.title,
    required this.icon,
    this.count,
    this.badgeText,
    required this.child,
  });

  final String title;
  final IconData icon;
  final int? count;
  final String? badgeText;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(icon: icon, color: _ConfigPageState._primaryColor),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (badgeText != null || count != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Container(
                  constraints: const BoxConstraints(minWidth: 34),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: const BoxDecoration(
                    color: _ConfigPageState._softAccentColor,
                    borderRadius: AppRadius.button,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badgeText ?? count.toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: _ConfigPageState._primaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _LsgSectionHeader extends StatelessWidget {
  const _LsgSectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: _ConfigPageState._softAccentColor,
            borderRadius: AppRadius.sm,
          ),
          child: Icon(icon, size: 18, color: _ConfigPageState._primaryColor),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Container(
          constraints: const BoxConstraints(minWidth: 30),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: const BoxDecoration(
            color: _ConfigPageState._softAccentColor,
            borderRadius: AppRadius.button,
          ),
          alignment: Alignment.center,
          child: Text(
            count.toString(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: _ConfigPageState._primaryColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.margin = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: margin,
      padding: AppInsets.md,
      surfaceLevel: AppSurfaceLevel.elevated,
      child: child,
    );
  }
}

class _AddInlineField extends StatelessWidget {
  const _AddInlineField({
    required this.controller,
    required this.hintText,
    required this.onSubmitted,
    this.enabled = true,
    this.compact = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback onSubmitted;
  final bool enabled;
  final bool compact;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            decoration: _ConfigPageState._fieldDecoration(
              hintText: hintText,
              prefixIcon: Icons.edit_outlined,
            ),
            onSubmitted: (_) => onSubmitted(),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        SizedBox(
          width: compact ? 44 : 50,
          height: compact ? 44 : 50,
          child: IconButton.filledTonal(
            tooltip: hintText,
            onPressed: enabled ? onSubmitted : null,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textInverse,
              disabledBackgroundColor: AppColors.surface2,
              disabledForegroundColor: _ConfigPageState._mutedInkColor,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.input,
              ),
            ),
            icon: Icon(Icons.add_rounded, size: compact ? 21 : 24),
          ),
        ),
      ],
    );
  }
}

class _ConfigChip extends StatelessWidget {
  const _ConfigChip({
    required this.label,
    required this.icon,
    required this.onDeleted,
  });

  final Widget label;
  final IconData icon;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: DefaultTextStyle.merge(
        style: const TextStyle(
          color: _ConfigPageState._inkColor,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        child: label,
      ),
      avatar: Icon(
        icon,
        size: 15,
        color: _ConfigPageState._primaryColor.withValues(alpha: 0.84),
      ),
      deleteIcon: const Icon(Icons.close_rounded, size: 16),
      onDeleted: onDeleted,
      backgroundColor: _ConfigPageState._chipFillColor,
      selectedColor: _ConfigPageState._softAccentColor,
      deleteIconColor: _ConfigPageState._removeIconColor,
      side: const BorderSide(color: _ConfigPageState._chipLineColor),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sm),
      labelPadding: const EdgeInsets.only(left: 2, right: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color}) : size = 40;

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadius.md,
      ),
      child: Icon(icon, color: color, size: size <= 40 ? 21 : 26),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
    required this.icon,
    this.isSelected = false,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = _ConfigPageState._primaryColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.sm,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? primary.withValues(alpha: 0.12)
                : _ConfigPageState._fieldFillColor,
            borderRadius: AppRadius.sm,
            border: Border.all(
              color: isSelected ? primary : _ConfigPageState._lineColor,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? primary : _ConfigPageState._mutedInkColor,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                value,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isSelected ? primary : _ConfigPageState._primaryColor,
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected ? primary : _ConfigPageState._mutedInkColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyInlineState extends StatelessWidget {
  const _EmptyInlineState({required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: compact
          ? const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            )
          : AppInsets.md,
      decoration: const BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadius.input,
        border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          fontSize: compact ? 12.5 : null,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.error_outline,
      title: 'Something went wrong',
      message: message,
      action: AppSecondaryButton(
        label: 'Retry',
        icon: Icons.refresh,
        onPressed: onRetry,
      ),
    );
  }
}

class _SettingsItem {
  const _SettingsItem({
    required this.title,
    this.subtitle,
    required this.icon,
    this.trailingText,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final String? trailingText;
  final VoidCallback onTap;
}

class _MasterListSettingsPage extends StatefulWidget {
  const _MasterListSettingsPage({
    required this.title,
    required this.icon,
    required this.listName,
    required this.hintText,
    required this.configState,
  });

  final String title;
  final IconData icon;
  final String listName;
  final String hintText;
  final _ConfigPageState configState;

  @override
  State<_MasterListSettingsPage> createState() =>
      _MasterListSettingsPageState();
}

class _MasterListSettingsPageState extends State<_MasterListSettingsPage> {
  final TextEditingController _addController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  List<String> get _items {
    final cfg = widget.configState._config;
    if (cfg == null) return [];
    return widget.listName == 'diseases' ? cfg.diseases : cfg.plans;
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final filtered = items
        .where((item) => item.toLowerCase().contains(_filter.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addController,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) async {
                      if (_addController.text.trim().isNotEmpty) {
                        widget.configState._addItem(
                          widget.listName,
                          _addController,
                        );
                        await widget.configState._saveConfig();
                        if (mounted) setState(() {});
                      }
                    },
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    if (_addController.text.trim().isNotEmpty) {
                      widget.configState._addItem(
                        widget.listName,
                        _addController,
                      );
                      await widget.configState._saveConfig();
                      if (mounted) setState(() {});
                    }
                  },
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: AppColors.primary,
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (items.length > 5) ...[
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.5),
                ),
              ),
              child: TextField(
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Filter items...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                onChanged: (val) => setState(() => _filter = val.trim()),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'ALL ITEMS (${items.length})',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
          ),
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              alignment: Alignment.center,
              child: Text(
                items.isEmpty
                    ? 'No items added yet'
                    : 'No items matching "$_filter"',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.7),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  children: [
                    for (var i = 0; i < filtered.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          indent: 48,
                          color: AppColors.border.withValues(alpha: 0.5),
                        ),
                      ListTile(
                        dense: true,
                        leading: Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.surface1,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            widget.icon,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
                        title: Text(
                          filtered[i],
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AppColors.danger,
                          ),
                          tooltip: 'Remove',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Confirm removal'),
                                content: Text(
                                  'Remove "${filtered[i]}" from ${widget.title.toLowerCase()}?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.danger,
                                    ),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Remove'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true && mounted) {
                              widget.configState._removeItem(
                                widget.listName,
                                filtered[i],
                              );
                              await widget.configState._saveConfig();
                              if (mounted) setState(() {});
                            }
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TransferSettingsPage extends StatefulWidget {
  const _TransferSettingsPage({required this.configState});

  final _ConfigPageState configState;

  @override
  State<_TransferSettingsPage> createState() => _TransferSettingsPageState();
}

class _TransferSettingsPageState extends State<_TransferSettingsPage> {
  static const _checks = [
    (key: 'identity_verified', label: 'Identity verified'),
    (key: 'address_verified', label: 'Address verified'),
    (key: 'consent_confirmed', label: 'Consent confirmed'),
    (key: 'records_reviewed', label: 'Records reviewed'),
  ];

  @override
  Widget build(BuildContext context) {
    final config = widget.configState._config;
    if (config == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Patient Transfer Review')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final settings = config.transferSettings;
    final expiryOptions = <int>{
      3,
      7,
      14,
      30,
      60,
      90,
      settings.expiryDays,
    }.toList()..sort();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Patient Transfer Review',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: _ConfigPageState._softAccentColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _ConfigPageState._primaryColor.withValues(alpha: 0.2),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: _ConfigPageState._primaryColor,
                  size: 20,
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Configure rules and checklists required when patients are transferred between care units.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: _ConfigPageState._primaryColor,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.7),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pending Request Expiry',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Number of days before an unaccepted transfer request expires.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<int>(
                  initialValue: settings.expiryDays,
                  isExpanded: true,
                  style: const TextStyle(
                    color: _ConfigPageState._inkColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.timer_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: AppRadius.sm),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                  items: expiryOptions
                      .map(
                        (days) => DropdownMenuItem(
                          value: days,
                          child: Text(
                            '$days days',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) async {
                    if (value != null) {
                      setState(() => settings.expiryDays = value);
                      await widget.configState._saveConfig();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.7),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Required Acceptance Checks',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Destination administrator must complete these checks before accepting a patient.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _checks.map((check) {
                    final selected = settings.requiredChecks.contains(
                      check.key,
                    );
                    return FilterChip(
                      selected: selected,
                      showCheckmark: true,
                      label: Text(check.label),
                      onSelected: (value) async {
                        setState(() {
                          if (value) {
                            settings.requiredChecks.add(check.key);
                          } else {
                            settings.requiredChecks.remove(check.key);
                          }
                        });
                        await widget.configState._saveConfig();
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
