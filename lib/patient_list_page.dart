import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:provider/provider.dart';
import 'package:oruma_app/models/patient.dart';
import 'package:oruma_app/services/patient_service.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/pt_registration.dart';
import 'package:oruma_app/patient_details_page.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:oruma_app/widgets/module_theme.dart';
import 'package:oruma_app/services/config_service.dart';
import 'package:oruma_app/models/config.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';
import 'package:oruma_app/widgets/app_bottom_nav_router.dart';
import 'package:oruma_app/widgets/compact_app_bottom_bar.dart';
import 'package:oruma_app/widgets/reveal_action_fab.dart';

class PatientListPage extends StatefulWidget {
  const PatientListPage({super.key});

  @override
  State<PatientListPage> createState() => _PatientListPageState();
}

class _PatientListPageState extends State<PatientListPage> {
  // Data
  List<Patient> _allPatients = [];
  PatientCounts? _counts;
  bool _isLoading = true;
  String? _error;
  String _currentFilter = 'all';

  // Filters
  List<String> _villagesList = ['All'];
  List<WardConfig> _allWards = [];
  List<String> _filteredWardsList = ['All'];
  String _selectedVillage = 'All';
  String _selectedWard = 'All';

  // Search
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    _loadConfig();
    _loadPatients();
  }

  Future<void> _loadConfig() async {
    try {
      final config = await ConfigService.getConfig();
      if (mounted) {
        setState(() {
          _villagesList = ['All', ...config.villages];
          _allWards = sortWardConfigs(config.wards);
          _updateFilteredWardsList();
        });
      }
    } catch (e) {
      // ignore
    }
  }

  void _updateFilteredWardsList() {
    if (_selectedVillage == 'All') {
      _filteredWardsList = ['All'];
    } else {
      final wardNumbers =
          _allWards
              .where((w) => w.village == _selectedVillage)
              .map((w) => w.number)
              .toList()
            ..sort(compareWardNumbers);
      _filteredWardsList = ['All', ...wardNumbers];
    }
    // If current selected ward is not in the filtered list, reset it to 'All'
    if (!_filteredWardsList.contains(_selectedWard)) {
      _selectedWard = 'All';
    }
  }

  String _wardFilterLabel(String value) {
    if (value == 'All') {
      return 'Ward';
    }

    return 'Ward $value';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await PatientService.getPatientsList(
        filter: _currentFilter,
        village: _selectedVillage != 'All' ? _selectedVillage : null,
        ward: _selectedWard != 'All' ? _selectedWard : null,
      );
      if (mounted) {
        setState(() {
          _allPatients = response.patients;
          _counts = response.counts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    void handleBottomNavigation(AppBottomSection section) {
      AppBottomNavRouter.handle(
        context,
        current: AppBottomSection.patients,
        target: section,
      );
    }

    return AdaptiveAppScaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: AppSpacing.md,
        title: _isSearching
            ? _buildSearchField('Search patients...')
            : Text("Patients", style: Theme.of(context).textTheme.titleLarge),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: _PatientIconButton(
              icon: _isSearching ? Icons.close : Icons.search,
              onPressed: () {
                setState(() {
                  if (_isSearching) {
                    _isSearching = false;
                    _searchController.clear();
                    _searchQuery = '';
                  } else {
                    _isSearching = true;
                  }
                });
              },
            ),
          ),
          if (!_isSearching)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: _PatientIconButton(
                icon: Icons.refresh,
                onPressed: _loadPatients,
              ),
            ),
        ],
      ),
      backgroundColor: AppColors.background,
      currentSection: AppBottomSection.patients,
      onNavigationSelected: handleBottomNavigation,
      contentMaxWidth: 820,
      body: Column(
        children: [
          if (_counts != null) _buildFilterTabs(),
          if (_counts != null) _buildSecondaryFilters(),
          Expanded(
            child: Builder(
              builder: (context) {
                if (_isLoading) {
                  return const AppListSkeleton(itemCount: 6);
                }

                if (_error != null) {
                  return AppEmptyState(
                    icon: Icons.error_outline,
                    title: 'Could not load patients',
                    message: _error!,
                    action: AppPrimaryButton(
                      label: 'Retry',
                      icon: Icons.refresh,
                      onPressed: _loadPatients,
                    ),
                  );
                }

                // Client-side filtering as fallback/robustness
                // We check if the API returned a mixed list despite the filter request.
                final filteredPatients = _allPatients.where((p) {
                  if (_selectedVillage != 'All' &&
                      p.village != _selectedVillage) {
                    return false;
                  }
                  if (_selectedWard != 'All' && p.ward != _selectedWard) {
                    return false;
                  }

                  // Text search filter
                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    final matchesSearch =
                        p.name.toLowerCase().contains(q) ||
                        p.village.toLowerCase().contains(q) ||
                        (p.registerId ?? '').toLowerCase().contains(q) ||
                        p.phone.toLowerCase().contains(q);
                    if (!matchesSearch) return false;
                  }

                  // Status filter (double check in case API returns mixed results)
                  if (_currentFilter == 'alive' && p.isDead) return false;
                  if (_currentFilter == 'dead' && !p.isDead) return false;

                  return true;
                }).toList();

                if (filteredPatients.isEmpty) {
                  if (_searchQuery.isNotEmpty) {
                    return const AppEmptyState(
                      icon: Icons.search_off,
                      title: 'No matching patients',
                      message:
                          'Try a different name, register ID, village, or phone number.',
                    );
                  }
                  return AppEmptyState(
                    icon: Icons.groups_outlined,
                    title: 'No patients yet',
                    message:
                        'Create the first patient record to begin managing home visits and care history.',
                    action: Provider.of<AuthService>(context).canCreate
                        ? AppPrimaryButton(
                            label: 'Add Patient',
                            icon: Icons.person_add_alt_1,
                            onPressed: _navigateToCreatePatient,
                          )
                        : null,
                  );
                }

                return RefreshIndicator(
                  onRefresh: _loadPatients,
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      AppInsets.screenHorizontal(context),
                      AppSpacing.md,
                      AppInsets.screenHorizontal(context),
                      112,
                    ),
                    itemCount: filteredPatients.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final patient = filteredPatients[index];
                      return _buildPatientCard(context, patient);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Provider.of<AuthService>(context).canCreate
          ? RevealActionFab(
              onPressed: _navigateToCreatePatient,
              label: 'Add Patient',
              icon: Icons.person_add,
            )
          : null,
    );
  }

  Widget _buildSearchField(String hintText) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search, size: AppIcons.normal),
          filled: true,
          fillColor: AppColors.surface1,
          contentPadding: AppInsets.input,
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
            borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToCreatePatient() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ModuleTheme(
          palette: ModulePalettes.patients,
          child: patientrigister(),
        ),
      ),
    );
    if (result == true) {
      _loadPatients();
    }
  }

  Widget _buildFilterTabs() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppInsets.screenHorizontal(context),
        AppSpacing.sm,
        AppInsets.screenHorizontal(context),
        AppSpacing.xs,
      ),
      child: Container(
        height: 52,
        padding: const EdgeInsets.all(AppSpacing.xxs),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: AppRadius.card,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _buildTab("All", _counts?.allCount ?? 0, 'all'),
            _buildTab("Active", _counts?.aliveCount ?? 0, 'alive'),
            _buildTab("Passed", _counts?.deadCount ?? 0, 'dead'),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, int count, String filterKey) {
    final isSelected = _currentFilter == filterKey;
    final activeColor = switch (filterKey) {
      'alive' => AppColors.success,
      'dead' => AppColors.danger,
      _ => AppColors.primary,
    };

    return Expanded(
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.md,
        child: InkWell(
          borderRadius: AppRadius.md,
          onTap: () {
            if (_currentFilter != filterKey) {
              setState(() {
                _currentFilter = filterKey;
              });
              _loadPatients();
            }
          },
          child: AnimatedContainer(
            duration: AppMotion.normal,
            curve: AppMotion.easeOutCubic,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.surface : Colors.transparent,
              borderRadius: AppRadius.md,
              boxShadow: isSelected ? AppShadow.small : AppShadow.none,
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected ? activeColor : AppColors.textSecondary,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? activeColor.withValues(alpha: 0.11)
                            : AppColors.surface2,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        count > 99 ? '99+' : count.toString(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isSelected
                              ? activeColor
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryFilters() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppInsets.screenHorizontal(context),
        AppSpacing.xs,
        AppInsets.screenHorizontal(context),
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: _PatientDropdown(
              value: _selectedVillage,
              icon: Icons.location_on_outlined,
              items: _villagesList,
              labelBuilder: (value) => value == 'All' ? 'All villages' : value,
              onChanged: (newValue) {
                if (newValue != null && newValue != _selectedVillage) {
                  setState(() {
                    _selectedVillage = newValue;
                    _updateFilteredWardsList();
                  });
                  _loadPatients();
                }
              },
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _PatientDropdown(
              value: _selectedWard,
              icon: Icons.map_outlined,
              items: _filteredWardsList,
              labelBuilder: _wardFilterLabel,
              onChanged: (newValue) {
                if (newValue != null && newValue != _selectedWard) {
                  setState(() {
                    _selectedWard = newValue;
                  });
                  _loadPatients();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToEditPatient(Patient patient) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ModuleTheme(
          palette: ModulePalettes.patients,
          child: patientrigister(patient: patient),
        ),
      ),
    );
    if (result != null) {
      _loadPatients();
    }
  }

  Future<void> _deletePatient(Patient patient) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: AppRadius.md,
              ),
              child: const Icon(Icons.delete_outline, color: AppColors.danger),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Delete patient',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ${patient.name}? This cannot be undone.',
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
            onPressed: () {
              Navigator.pop(context, false);
            },
          ),
          AppDangerButton(
            label: 'Delete',
            icon: Icons.delete_outline,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true && patient.id != null) {
      try {
        await PatientService.deletePatient(patient.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Patient deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadPatients();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting patient: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  Widget _buildPatientCard(BuildContext context, Patient patient) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isAdmin = authService.isAdmin;
    final details = <String>[
      '${patient.age} years',
      patient.gender,
      patient.plan,
    ].where((item) => item.trim().isNotEmpty).join(' • ');

    Widget cardContent = AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      surfaceLevel: patient.isDead
          ? AppSurfaceLevel.surface
          : AppSurfaceLevel.elevated,
      borderColor: patient.isDead ? AppColors.borderStrong : AppColors.border,
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ModuleTheme(
              palette: ModulePalettes.patients,
              child: PatientDetailsPage(patient: patient),
            ),
          ),
        );
        if (result == true) {
          _loadPatients();
        }
      },
      child: Row(
        children: [
          _PatientAvatar(patient: patient),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        patient.name,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (patient.isDead) ...[
                      const SizedBox(width: AppSpacing.xs),
                      const _PatientStatusPill(
                        label: 'Passed away',
                        color: AppColors.danger,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if (patient.registerId != null &&
                        patient.registerId!.isNotEmpty)
                      _PatientMetaPill(
                        icon: Icons.badge_outlined,
                        label: 'REG ${patient.registerId}',
                        color: AppColors.primary,
                      ),
                    if (details.isNotEmpty)
                      _PatientMetaPill(
                        icon: Icons.person_outline,
                        label: details,
                        color: AppColors.textSecondary,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: AppIcons.small,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Expanded(
                      child: Text(
                        patient.place.isNotEmpty
                            ? patient.place
                            : patient.village,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (isAdmin && patient.phone.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      const Icon(
                        Icons.phone_outlined,
                        size: AppIcons.small,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      Expanded(
                        child: Text(
                          patient.phone,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textMuted,
            size: AppIcons.large,
          ),
        ],
      ),
    );

    final canEdit = authService.canEdit;
    final canDelete = authService.canDelete;

    if (canEdit || canDelete) {
      final actions = <Widget>[];

      if (canEdit) {
        actions.add(
          SlidableAction(
            onPressed: (_) => _navigateToEditPatient(patient),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: Icons.edit_outlined,
            label: 'Edit',
            borderRadius: AppRadius.card,
          ),
        );
      }

      if (canDelete) {
        actions.add(
          SlidableAction(
            onPressed: (_) => _deletePatient(patient),
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'Delete',
            borderRadius: AppRadius.card,
          ),
        );
      }

      return ClipRRect(
        borderRadius: AppRadius.card,
        child: Slidable(
          key: ValueKey(patient.id),
          endActionPane: ActionPane(
            motion: const ScrollMotion(),
            extentRatio: (actions.length * 0.24).clamp(0.24, 0.48),
            children: actions,
          ),
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}

class _PatientIconButton extends StatelessWidget {
  const _PatientIconButton({required this.icon, required this.onPressed});

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
          child: Icon(icon, size: AppIcons.large, color: AppColors.text),
        ),
      ),
    );
  }
}

class _PatientDropdown extends StatelessWidget {
  const _PatientDropdown({
    required this.value,
    required this.items,
    required this.icon,
    required this.labelBuilder,
    required this.onChanged,
  });

  final String value;
  final List<String> items;
  final IconData icon;
  final String Function(String value) labelBuilder;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: AppIcons.normal,
            color: AppColors.textSecondary,
          ),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.normal,
          ),
          selectedItemBuilder: (context) {
            return items.map((item) {
              return Row(
                children: [
                  Icon(icon, color: AppColors.primary, size: AppIcons.normal),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      labelBuilder(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            }).toList();
          },
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(labelBuilder(item), overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _PatientAvatar extends StatelessWidget {
  const _PatientAvatar({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final background = patient.isDead
        ? AppColors.surface2
        : AppColors.primaryLight;
    final foreground = patient.isDead ? AppColors.textMuted : AppColors.primary;

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(color: background, borderRadius: AppRadius.md),
      child: Center(
        child: patient.isDead
            ? const Icon(Icons.person_off_outlined, color: AppColors.textMuted)
            : Text(
                patient.name.isNotEmpty ? patient.name[0].toUpperCase() : '?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

class _PatientMetaPill extends StatelessWidget {
  const _PatientMetaPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
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
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientStatusPill extends StatelessWidget {
  const _PatientStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
