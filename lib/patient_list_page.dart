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
import 'package:oruma_app/volunteer_patient_registration_page.dart';
import 'package:oruma_app/patient_enquiry_list_page.dart';
import 'package:oruma_app/patient_transfer_requests_page.dart';
import 'package:oruma_app/services/patient_transfer_service.dart';
import 'package:oruma_app/transferred_patient_list_page.dart';
import 'package:oruma_app/models/ward.dart';
import 'package:oruma_app/services/ward_service.dart';
import 'package:oruma_app/features/reports/models/report_models.dart';
import 'package:oruma_app/features/reports/presentation/reports_page.dart';
import 'package:oruma_app/core/utils/format_utils.dart';

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
  List<Ward> _careWards = const [];
  Set<String> _selectedCareWardIds = <String>{};

  // Search
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';
  int _incomingTransferCount = 0;

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
    _loadTransferCount();
  }

  Future<void> _loadTransferCount() async {
    try {
      final count = await PatientTransferService.incomingCount();
      if (mounted) setState(() => _incomingTransferCount = count);
    } catch (_) {}
  }

  Future<void> _loadConfig() async {
    try {
      final results = await Future.wait([
        ConfigService.getConfig(),
        WardService.getWards(),
      ]);
      final config = results[0] as Config;
      final careWards = results[1] as List<Ward>;
      if (mounted) {
        setState(() {
          _villagesList = ['All', ...config.villages];
          _allWards = sortWardConfigs(config.wards);
          _careWards = careWards;
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
        currentWardIds: _selectedCareWardIds.toList(),
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
    final auth = Provider.of<AuthService>(context);

    void handleBottomNavigation(AppBottomSection section) {
      AppBottomNavRouter.handle(
        context,
        current: AppBottomSection.patients,
        target: section,
      );
    }

    if (!auth.canAccessPatients) {
      return AdaptiveAppScaffold(
        appBar: AppBar(
          title: const Text('Patients'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.text,
          elevation: 0,
        ),
        backgroundColor: AppColors.background,
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 48,
                  color: AppColors.danger,
                ),
                SizedBox(height: AppSpacing.md),
                Text(
                  'Access Denied',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  'You do not have permission to access patient management.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isSmall = screenWidth < 440;
    final actionGap = isSmall ? 3.0 : AppSpacing.xs;
    final actionEndPadding = isSmall ? AppSpacing.xs : AppSpacing.md;
    final actionSize = isSmall ? 36.0 : 44.0;
    final actionIconSize = isSmall ? 19.0 : AppIcons.large;

    return AdaptiveAppScaffold(
      appBar: AppBar(
        toolbarHeight: isSmall ? 64 : 72,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: isSmall ? AppSpacing.xs : AppSpacing.md,
        title: _isSearching
            ? _buildSearchField('Search patients...')
            : Text(
                "Patients",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (isSmall
                        ? Theme.of(context).textTheme.titleMedium
                        : Theme.of(context).textTheme.titleLarge)
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: actionGap),
            child: _PatientIconButton(
              size: actionSize,
              iconSize: actionIconSize,
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
          if (!_isSearching && auth.isAdmin)
            Padding(
              padding: EdgeInsets.only(right: actionGap),
              child: Tooltip(
                message: 'Patient Enquiries',
                child: _PatientIconButton(
                  size: actionSize,
                  iconSize: actionIconSize,
                  icon: Icons.mark_email_unread_outlined,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PatientEnquiryListPage(),
                      ),
                    );
                  },
                ),
              ),
            ),
          if (!_isSearching && auth.canViewPatientTransfers)
            Padding(
              padding: EdgeInsets.only(right: actionGap),
              child: Tooltip(
                message: 'Patient Transfers',
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Material(
                      color: AppColors.surface1,
                      borderRadius:
                          actionSize <= 38 ? AppRadius.sm : AppRadius.md,
                      child: SizedBox(
                        width: actionSize,
                        height: actionSize,
                        child: PopupMenuButton<String>(
                          tooltip: 'Patient transfer menu',
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.swap_horiz_rounded,
                            size: actionIconSize,
                            color: AppColors.text,
                          ),
                          onSelected: (value) async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => value == 'archive'
                                    ? const TransferredPatientListPage()
                                    : const PatientTransferRequestsPage(),
                              ),
                            );
                            _loadPatients();
                            _loadTransferCount();
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'requests',
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.move_to_inbox_outlined),
                                title: Text('Transfer requests'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'archive',
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.archive_outlined),
                                title: Text('Transferred patients'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_incomingTransferCount > 0)
                      Positioned(
                        right: isSmall ? -2 : -3,
                        top: isSmall ? -3 : -5,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmall ? 4 : 6,
                            vertical: isSmall ? 1 : 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.background),
                          ),
                          child: Text(
                            FormatUtils.formatCompactCount(
                              _incomingTransferCount,
                            ),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmall ? 9 : 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (!_isSearching && auth.canAccessReports)
            Padding(
              padding: EdgeInsets.only(right: actionGap),
              child: Tooltip(
                message: 'Patient Report',
                child: _PatientIconButton(
                  size: actionSize,
                  iconSize: actionIconSize,
                  icon: Icons.assessment_outlined,
                  onPressed: () =>
                      openReports(context, initialReport: ReportType.patients),
                ),
              ),
            ),
          if (!_isSearching)
            Padding(
              padding: EdgeInsets.only(right: actionEndPadding),
              child: _PatientIconButton(
                size: actionSize,
                iconSize: actionIconSize,
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
                  if (_selectedCareWardIds.isNotEmpty) {
                    final value = p.currentWardId ?? 'unassigned';
                    if (!_selectedCareWardIds.contains(value)) return false;
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
                    action: auth.canCreate
                        ? AppPrimaryButton(
                            label: 'Add Patient',
                            icon: Icons.person_add_alt_1,
                            onPressed: _navigateToCreatePatient,
                          )
                        : (auth.canVolunteerRegisterPatient
                              ? AppPrimaryButton(
                                  label: 'Register Patient',
                                  icon: Icons.person_add_alt_1,
                                  onPressed:
                                      _navigateToVolunteerPatientRegister,
                                )
                              : null),
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
                        const SizedBox(height: AppSpacing.xs),
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
      floatingActionButton: () {
        if (auth.canCreate) {
          return RevealActionFab(
            onPressed: _navigateToCreatePatient,
            label: 'Add Patient',
            icon: Icons.person_add,
          );
        }
        if (auth.canVolunteerRegisterPatient) {
          return RevealActionFab(
            onPressed: _navigateToVolunteerPatientRegister,
            label: 'Register Patient',
            icon: Icons.person_add_alt_1,
          );
        }
        return null;
      }(),
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

  Future<void> _navigateToVolunteerPatientRegister() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ModuleTheme(
          palette: ModulePalettes.patients,
          child: VolunteerPatientRegistrationPage(),
        ),
      ),
    );
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
                        FormatUtils.formatCompactCount(count),
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
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _PatientDropdown(
                  value: _selectedVillage,
                  icon: Icons.location_on_outlined,
                  items: _villagesList,
                  labelBuilder: (value) =>
                      value == 'All' ? 'All villages' : value,
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
          if (_careWards.isNotEmpty || _selectedCareWardIds.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: _selectedCareWardIds.isNotEmpty
                        ? OutlinedButton.styleFrom(
                            backgroundColor: AppColors.primarySoft,
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                          )
                        : null,
                    onPressed: _showCareWardFilter,
                    icon: Icon(
                      _selectedCareWardIds.isNotEmpty
                          ? Icons.filter_alt_rounded
                          : Icons.local_hospital_outlined,
                      size: 18,
                    ),
                    label: Text(
                      _selectedCareWardIds.isEmpty
                          ? 'Filter by care ward'
                          : '${_selectedCareWardIds.length} care ward filter(s)',
                    ),
                  ),
                ),
                if (_selectedCareWardIds.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.xs),
                  IconButton(
                    tooltip: 'Clear ward filter',
                    onPressed: () {
                      setState(() => _selectedCareWardIds.clear());
                      _loadPatients();
                    },
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showCareWardFilter() async {
    var selected = <String>{..._selectedCareWardIds};
    var searchQuery = '';
    final searchController = TextEditingController();

    // Natural sort: 1, 2, ..., 42, 43, 44
    final allWardsSorted = _careWards.toList()
      ..sort((a, b) => compareNaturally(a.label, b.label));

    final localBodies = _careWards
        .map((w) => w.localBody?.trim() ?? '')
        .where((lb) => lb.isNotEmpty)
        .toSet();
    final hasMultipleLocalBodies = localBodies.length > 1;

    try {
      final applied = await showDialog<Set<String>>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            final query = searchQuery.trim().toLowerCase();
            final unassignedMatches = query.isEmpty ||
                'unassigned'.contains(query) ||
                'no ward'.contains(query);

            final visibleWards = allWardsSorted.where((ward) {
              if (query.isEmpty) return true;
              return ward.label.toLowerCase().contains(query) ||
                  (ward.localBody ?? '').toLowerCase().contains(query) ||
                  (ward.lsgWardValue ?? '').toLowerCase().contains(query);
            }).toList();

            final visibleWardIds = visibleWards.map((w) => w.id).toSet();
            if (unassignedMatches) visibleWardIds.add('unassigned');

            final allVisibleSelected = visibleWardIds.isNotEmpty &&
                visibleWardIds.every((id) => selected.contains(id));

            final mediaSize = MediaQuery.sizeOf(context);
            final dialogWidth = (mediaSize.width - 32.0).clamp(0.0, 420.0);
            final dialogHeight = (mediaSize.height * 0.80).clamp(360.0, 620.0);

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: AppColors.surfaceModal,
              clipBehavior: Clip.antiAlias,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              child: SizedBox(
                width: dialogWidth,
                height: dialogHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.local_hospital_outlined,
                              color: AppColors.primary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Filter by care ward',
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                                ),
                                Text(
                                  selected.isEmpty
                                      ? 'All wards showing'
                                      : '${selected.length} of ${allWardsSorted.length} selected',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: selected.isEmpty
                                        ? AppColors.textSecondary
                                        : AppColors.primary,
                                    fontWeight: selected.isEmpty
                                        ? FontWeight.normal
                                        : FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),
                    ),

                    // Search input
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                      child: TextField(
                        controller: searchController,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search ward name or number...',
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                          suffixIcon: searchQuery.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: () {
                                    searchController.clear();
                                    setDialogState(() => searchQuery = '');
                                  },
                                ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          filled: true,
                          fillColor: AppColors.surface2,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (val) =>
                            setDialogState(() => searchQuery = val.trim()),
                      ),
                    ),

                    // Quick Actions Row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                      child: Row(
                        children: [
                          Text(
                            '${visibleWards.length + (unassignedMatches ? 1 : 0)} wards',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 0,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: visibleWardIds.isEmpty
                                ? null
                                : () {
                                    setDialogState(() {
                                      if (allVisibleSelected) {
                                        selected.removeAll(visibleWardIds);
                                      } else {
                                        selected.addAll(visibleWardIds);
                                      }
                                    });
                                  },
                            child: Text(
                              allVisibleSelected
                                  ? 'Deselect all'
                                  : 'Select all',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          if (selected.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            TextButton(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 0,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                setDialogState(() => selected.clear());
                              },
                              child: const Text(
                                'Clear all',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.danger,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 0.5),

                    // List of care wards
                    Expanded(
                      child: visibleWards.isEmpty && !unassignedMatches
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: Text(
                                  'No care wards match "$searchQuery"',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                              children: [
                                if (unassignedMatches) ...[
                                  CheckboxListTile(
                                    value: selected.contains('unassigned'),
                                    onChanged: (checked) {
                                      setDialogState(() {
                                        if (checked == true) {
                                          selected.add('unassigned');
                                        } else {
                                          selected.remove('unassigned');
                                        }
                                      });
                                    },
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    dense: true,
                                    visualDensity: const VisualDensity(
                                      horizontal: -2,
                                      vertical: -3,
                                    ),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 0,
                                        ),
                                    activeColor: AppColors.primary,
                                    checkboxShape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    tileColor: selected.contains('unassigned')
                                        ? AppColors.primarySoft.withValues(
                                            alpha: 0.5,
                                          )
                                        : null,
                                    title: Text(
                                      'Unassigned (no care ward)',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight:
                                            selected.contains('unassigned')
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ),
                                  const Divider(
                                    height: 1,
                                    indent: 44,
                                    thickness: 0.5,
                                  ),
                                ],
                                for (
                                  int i = 0;
                                  i < visibleWards.length;
                                  i++
                                ) ...[
                                  () {
                                    final ward = visibleWards[i];
                                    final isSelected = selected.contains(
                                      ward.id,
                                    );
                                    return CheckboxListTile(
                                      value: isSelected,
                                      onChanged: (checked) {
                                        setDialogState(() {
                                          if (checked == true) {
                                            selected.add(ward.id);
                                          } else {
                                            selected.remove(ward.id);
                                          }
                                        });
                                      },
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      dense: true,
                                      visualDensity: const VisualDensity(
                                        horizontal: -2,
                                        vertical: -3,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 0,
                                          ),
                                      activeColor: AppColors.primary,
                                      checkboxShape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      tileColor: isSelected
                                          ? AppColors.primarySoft.withValues(
                                              alpha: 0.5,
                                            )
                                          : null,
                                      title: Text(
                                        ward.label,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: AppColors.text,
                                        ),
                                      ),
                                      subtitle: hasMultipleLocalBodies &&
                                              ward.localBody != null &&
                                              ward.localBody!.trim().isNotEmpty
                                          ? Text(
                                              ward.localBody!.trim(),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                              ),
                                            )
                                          : null,
                                    );
                                  }(),
                                  if (i < visibleWards.length - 1)
                                    const Divider(
                                      height: 1,
                                      indent: 44,
                                      thickness: 0.5,
                                    ),
                                ],
                              ],
                            ),
                    ),

                    // Footer actions
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        border: Border(
                          top: BorderSide(
                            color: AppColors.border,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, <String>{}),
                            child: const Text('Clear'),
                          ),
                          const Spacer(),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              shape: const RoundedRectangleBorder(
                                borderRadius: AppRadius.button,
                              ),
                            ),
                            onPressed: () =>
                                Navigator.pop(dialogContext, selected),
                            child: Text(
                              selected.isEmpty
                                  ? 'Apply'
                                  : 'Apply (${selected.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
      if (applied == null || !mounted) return;
      setState(() => _selectedCareWardIds = applied);
      await _loadPatients();
    } finally {
      searchController.dispose();
    }
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
    final canViewContacts = authService.canViewContactNumbers;
    final canViewDetails = authService.canViewPatientDetails;
    final hasAssignedCareWard =
        patient.currentWardId?.trim().isNotEmpty == true;
    final demographics = <String>[
      '${patient.age} years',
      patient.gender,
      patient.plan,
    ].where((item) => item.trim().isNotEmpty).join(' • ');

    final placeText =
        patient.place.isNotEmpty ? patient.place : patient.village;

    Widget cardContent = Stack(
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          surfaceLevel: patient.isDead
              ? AppSurfaceLevel.surface
              : AppSurfaceLevel.elevated,
          borderColor: patient.isDead
              ? AppColors.borderStrong
              : AppColors.border,
          onTap: canViewDetails
              ? () async {
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
                }
              : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _PatientAvatar(patient: patient, size: 44),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ROW 1: Full row for the name with REG/status pill & chevron
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            patient.name,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                  color: AppColors.text,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (patient.isDead) ...[
                          const SizedBox(width: 6),
                          const _PatientStatusPill(
                            label: 'Passed away',
                            color: AppColors.danger,
                          ),
                        ] else if (patient.transferStatus ==
                            'TRANSFER_PENDING') ...[
                          const SizedBox(width: 6),
                          const _PatientStatusPill(
                            label: 'Transfer pending',
                            color: AppColors.warning,
                          ),
                        ] else if (patient.registerId != null &&
                            patient.registerId!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'REG ${patient.registerId}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                        if (canViewDetails) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.textMuted,
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),

                    // ROW 2: Demographics & Care Ward
                    Row(
                      children: [
                        if (demographics.isNotEmpty) ...[
                          Flexible(
                            child: Text(
                              demographics,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        if (patient.currentWard != null) ...[
                          if (demographics.isNotEmpty)
                            const Text(
                              ' • ',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          const Icon(
                            Icons.local_hospital_outlined,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              patient.currentWard!.label,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),

                    // ROW 3: Location & Phone
                    Row(
                      children: [
                        if (placeText.isNotEmpty) ...[
                          const Icon(
                            Icons.place_outlined,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              placeText,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        if (canViewContacts && patient.phone.isNotEmpty) ...[
                          if (placeText.isNotEmpty)
                            const Text(
                              ' • ',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          const Icon(
                            Icons.phone_outlined,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              patient.phone,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!hasAssignedCareWard)
          Positioned(
            top: 8,
            right: 8,
            child: Semantics(
              label: 'Care ward not assigned',
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.warning.withValues(alpha: 0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );

    final canEdit =
        authService.canEdit && patient.transferStatus != 'TRANSFER_PENDING';
    final canDelete =
        authService.canDelete && patient.transferStatus != 'TRANSFER_PENDING';

    if (canEdit || canDelete) {
      final actions = <Widget>[];

      if (canEdit) {
        actions.add(
          SlidableAction(
            onPressed: (_) => _navigateToEditPatient(patient),
            backgroundColor: AppColors.primaryLight,
            foregroundColor: AppColors.primary,
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
            backgroundColor: AppColors.danger.withValues(alpha: 0.1),
            foregroundColor: AppColors.danger,
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
  const _PatientIconButton({
    required this.icon,
    required this.onPressed,
    this.size = 44,
    this.iconSize,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface1,
      borderRadius: size <= 38 ? AppRadius.sm : AppRadius.md,
      child: InkWell(
        borderRadius: size <= 38 ? AppRadius.sm : AppRadius.md,
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: iconSize ?? (size <= 38 ? 19.0 : AppIcons.large),
            color: AppColors.text,
          ),
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
  const _PatientAvatar({required this.patient, this.size = 44});

  final Patient patient;
  final double size;

  @override
  Widget build(BuildContext context) {
    final background = patient.isDead
        ? AppColors.surface2
        : AppColors.primaryLight;
    final foreground = patient.isDead ? AppColors.textMuted : AppColors.primary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: patient.isDead
            ? Icon(
                Icons.person_off_outlined,
                color: AppColors.textMuted,
                size: size * 0.45,
              )
            : Text(
                patient.name.isNotEmpty ? patient.name[0].toUpperCase() : '?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  fontSize: size * 0.42,
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
