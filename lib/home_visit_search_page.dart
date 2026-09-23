import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/homevisit.dart';
import 'package:oruma_app/models/home_visit.dart';
import 'package:oruma_app/services/home_visit_service.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:oruma_app/widgets/module_theme.dart';

const _homeVisitPrimary = AppColors.success;
const _homeVisitIconBackground = Color(0xFFDCFCE7);

class HomeVisitSearchPage extends StatefulWidget {
  const HomeVisitSearchPage({super.key});

  @override
  State<HomeVisitSearchPage> createState() => _HomeVisitSearchPageState();
}

class _HomeVisitSearchPageState extends State<HomeVisitSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<HomeVisit> _allVisits = [];
  List<HomeVisit> _filteredVisits = [];
  bool _isLoading = true;
  String? _error;
  String _modeFilter = 'all';
  String _dateFilter = 'all';

  static const _modeOptions = [
    _FilterOption('all', 'All modes', Icons.all_inclusive_rounded),
    _FilterOption('new', 'New', Icons.add_circle_outline),
    _FilterOption('monthly', 'Planned NHC', Icons.calendar_month_outlined),
    _FilterOption('emergency', 'Emergency', Icons.emergency_outlined),
    _FilterOption('dhc_visit', 'DHC', Icons.home_work_outlined),
    _FilterOption('vhc_visit', 'VHC', Icons.local_hospital_outlined),
  ];

  static const _dateOptions = [
    _FilterOption('all', 'Any date', Icons.event_available_outlined),
    _FilterOption('today', 'Today', Icons.today_outlined),
    _FilterOption('upcoming', 'Upcoming', Icons.trending_up_outlined),
    _FilterOption('past', 'Past', Icons.history_rounded),
  ];

  bool get _hasActiveFilters => _modeFilter != 'all' || _dateFilter != 'all';

  @override
  void initState() {
    super.initState();
    _loadVisits();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadVisits() async {
    try {
      final visits = await HomeVisitService.getAllHomeVisits();
      if (!mounted) return;
      setState(() {
        _allVisits = visits;
        _filteredVisits = _buildFilteredVisits(visits);
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterVisits(String query) {
    setState(() {
      _filteredVisits = _buildFilteredVisits();
    });
  }

  List<HomeVisit> _buildFilteredVisits([List<HomeVisit>? visits]) {
    final query = _searchController.text.trim().toLowerCase();
    final hasQuery = query.isNotEmpty;

    if (!hasQuery && !_hasActiveFilters) {
      return [];
    }

    final result = (visits ?? _allVisits).where((visit) {
      final matchesQuery =
          !hasQuery ||
          visit.patientName.toLowerCase().contains(query) ||
          visit.address.toLowerCase().contains(query) ||
          (visit.team?.toLowerCase().contains(query) ?? false) ||
          (visit.notes?.toLowerCase().contains(query) ?? false);

      return matchesQuery &&
          _matchesModeFilter(visit) &&
          _matchesDateFilter(visit);
    }).toList();

    result.sort((a, b) {
      final dateA = DateTime.tryParse(a.visitDate);
      final dateB = DateTime.tryParse(b.visitDate);
      if (dateA == null || dateB == null) return 0;
      return dateB.compareTo(dateA);
    });

    return result;
  }

  bool _matchesModeFilter(HomeVisit visit) {
    return _modeFilter == 'all' || visit.visitMode == _modeFilter;
  }

  bool _matchesDateFilter(HomeVisit visit) {
    if (_dateFilter == 'all') return true;
    final visitDate = DateTime.tryParse(visit.visitDate);
    if (visitDate == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final visitDay = DateTime(visitDate.year, visitDate.month, visitDate.day);

    return switch (_dateFilter) {
      'today' => _isSameDay(visitDay, today),
      'upcoming' => !visitDay.isBefore(today),
      'past' => visitDay.isBefore(today),
      _ => true,
    };
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _clearSearch() {
    _searchController.clear();
    _filterVisits('');
    _searchFocusNode.requestFocus();
  }

  void _clearFilters() {
    setState(() {
      _modeFilter = 'all';
      _dateFilter = 'all';
      _filteredVisits = _buildFilteredVisits();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ModuleTheme(
      palette: ModulePalettes.homeVisits,
      child: Builder(
        builder: (context) {
          final primaryColor = Theme.of(context).colorScheme.primary;

          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              toolbarHeight: 76,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: AppColors.background,
              foregroundColor: AppColors.text,
              titleSpacing: 0,
              title: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _filterVisits,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: _searchDecoration(),
              ),
              actions: [
                if (_searchController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.xs),
                    child: _SearchIconButton(
                      icon: Icons.close_rounded,
                      onPressed: _clearSearch,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.xs,
                    right: AppSpacing.md,
                  ),
                  child: _SearchIconButton(
                    icon: Icons.tune_rounded,
                    active: _hasActiveFilters,
                    onPressed: _showFilterSheet,
                  ),
                ),
              ],
            ),
            body: _buildBody(primaryColor),
          );
        },
      ),
    );
  }

  InputDecoration _searchDecoration() {
    return InputDecoration(
      isDense: true,
      hintText: "Search patient, address, team...",
      hintStyle: const TextStyle(color: AppColors.textMuted),
      prefixIcon: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.all(6),
        decoration: const BoxDecoration(
          color: _homeVisitIconBackground,
          borderRadius: AppRadius.sm,
        ),
        child: const Icon(
          Icons.search_rounded,
          color: _homeVisitPrimary,
          size: AppIcons.normal,
        ),
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
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
    );
  }

  Widget _buildBody(Color primaryColor) {
    if (_isLoading) {
      return const AppListSkeleton(itemCount: 5);
    }

    if (_error != null) {
      return AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Could not load visits',
        message: _error!,
        action: AppPrimaryButton(
          label: 'Retry',
          icon: Icons.refresh,
          onPressed: _loadVisits,
        ),
      );
    }

    if (_searchController.text.isEmpty && !_hasActiveFilters) {
      return _buildSearchPrompt();
    }

    if (_filteredVisits.isEmpty) {
      return _buildNoResults();
    }

    return _buildSearchResults(primaryColor);
  }

  Widget _buildSearchPrompt() {
    return Column(
      children: [
        const Expanded(
          child: AppEmptyState(
            icon: Icons.search_rounded,
            title: 'Search home visits',
            message: 'Find visits by patient name, address, team, or notes.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            surfaceLevel: AppSurfaceLevel.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.home_work_outlined,
                  size: AppIcons.small,
                  color: _homeVisitPrimary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '${_allVisits.length} total visits available',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: _homeVisitPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoResults() {
    return AppEmptyState(
      icon: Icons.search_off_rounded,
      title: 'No visits found',
      message: _hasActiveFilters
          ? 'Try changing the search or filters.'
          : 'Try a different patient name, address, team, or note.',
      action: _hasActiveFilters
          ? AppSecondaryButton(
              label: 'Clear Filters',
              icon: Icons.filter_alt_off_outlined,
              onPressed: _clearFilters,
            )
          : null,
    );
  }

  Widget _buildSearchResults(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            surfaceLevel: AppSurfaceLevel.surface,
            child: Row(
              children: [
                Icon(
                  Icons.filter_list_rounded,
                  size: AppIcons.small,
                  color: primaryColor,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    "${_filteredVisits.length} ${_filteredVisits.length == 1 ? 'result' : 'results'} found",
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_hasActiveFilters)
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            itemCount: _filteredVisits.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final visit = _filteredVisits[index];
              return _buildVisitCard(visit, primaryColor);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVisitCard(HomeVisit visit, Color primaryColor) {
    final date = DateTime.tryParse(visit.visitDate);
    final now = DateTime.now();
    final isToday =
        date != null &&
        date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    final isPast =
        date != null && date.isBefore(DateTime(now.year, now.month, now.day));
    final dateColor = isToday
        ? AppColors.success
        : isPast
        ? AppColors.textSecondary
        : AppColors.primary;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      surfaceLevel: AppSurfaceLevel.elevated,
      onTap: () => _showVisitDetails(visit),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: dateColor.withValues(alpha: 0.1),
              borderRadius: AppRadius.md,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  date != null ? DateFormat('dd').format(date) : '??',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: dateColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  date != null
                      ? DateFormat('MMM').format(date).toUpperCase()
                      : 'N/A',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: dateColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        visit.patientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (isToday)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Today',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                _buildCompactMetaRow(Icons.location_on_outlined, visit.address),
                if (visit.team != null && visit.team!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  _buildCompactMetaRow(Icons.group_outlined, visit.team!),
                ],
                if (visit.notes != null && visit.notes!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  _buildCompactMetaRow(Icons.notes_outlined, visit.notes!),
                ],
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildVisitModeBadge(visit.visitMode),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textMuted,
            size: AppIcons.large,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMetaRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: AppIcons.small, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.xxs),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  void _showVisitDetails(HomeVisit visit) {
    final date = DateTime.tryParse(visit.visitDate);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
            constraints: BoxConstraints(
              maxHeight: mediaQuery.size.height * 0.85,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: _SheetHandle()),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Home Visit Details',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              visit.patientName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          color: _homeVisitIconBackground,
                          borderRadius: AppRadius.md,
                        ),
                        padding: AppInsets.sm,
                        child: const Icon(
                          Icons.home_work_rounded,
                          color: _homeVisitPrimary,
                          size: AppIcons.large,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildDetailRow(
                    Icons.calendar_today_outlined,
                    'Visit Date',
                    date != null
                        ? DateFormat('EEEE, d MMMM yyyy').format(date)
                        : 'Invalid date',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildDetailRow(
                    Icons.medical_services_outlined,
                    'Visit Mode',
                    _visitModeLabel(visit.visitMode),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildDetailRow(
                    Icons.location_on_outlined,
                    'Address',
                    visit.address,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildDetailRow(
                    Icons.group_outlined,
                    'Team',
                    visit.team != null && visit.team!.isNotEmpty
                        ? visit.team!
                        : 'No team assigned',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildDetailRow(
                    Icons.notes_outlined,
                    'Notes',
                    visit.notes != null && visit.notes!.isNotEmpty
                        ? visit.notes!
                        : 'No notes provided',
                  ),
                  if (visit.createdBy != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: Text(
                        'Created by: ${visit.createdBy}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xl),
                  AppPrimaryButton(
                    label: 'Edit Details',
                    icon: Icons.edit_outlined,
                    fullWidth: true,
                    onPressed: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ModuleTheme(
                            palette: ModulePalettes.homeVisits,
                            child: Homevisit(visit: visit),
                          ),
                        ),
                      );
                      if (result == true) {
                        await _loadVisits();
                        _filterVisits(_searchController.text);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
                  color: AppColors.text,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showFilterSheet() async {
    var selectedMode = _modeFilter;
    var selectedDate = _dateFilter;

    final result = await showModalBottomSheet<({String mode, String date})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottomSafePadding = MediaQuery.of(context).viewPadding.bottom;

        return StatefulBuilder(
          builder: (context, setSheetState) {
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: _SheetHandle()),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Filter visits',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildFilterSection(
                    title: 'Visit mode',
                    options: _modeOptions,
                    selectedValue: selectedMode,
                    onSelected: (value) {
                      setSheetState(() => selectedMode = value);
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildFilterSection(
                    title: 'Date range',
                    options: _dateOptions,
                    selectedValue: selectedDate,
                    onSelected: (value) {
                      setSheetState(() => selectedDate = value);
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: AppSecondaryButton(
                          label: 'Clear',
                          icon: Icons.filter_alt_off_outlined,
                          onPressed: () {
                            Navigator.pop(context, (mode: 'all', date: 'all'));
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppPrimaryButton(
                          label: 'Apply',
                          icon: Icons.check_rounded,
                          onPressed: () {
                            Navigator.pop(context, (
                              mode: selectedMode,
                              date: selectedDate,
                            ));
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == null) return;

    setState(() {
      _modeFilter = result.mode;
      _dateFilter = result.date;
      _filteredVisits = _buildFilteredVisits();
    });
  }

  Widget _buildFilterSection({
    required String title,
    required List<_FilterOption> options,
    required String selectedValue,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: options.map((option) {
            final selected = selectedValue == option.value;
            return FilterChip(
              selected: selected,
              avatar: Icon(
                option.icon,
                size: AppIcons.small,
                color: selected ? AppColors.textInverse : _homeVisitPrimary,
              ),
              label: Text(option.label),
              selectedColor: _homeVisitPrimary,
              backgroundColor: AppColors.surface1,
              checkmarkColor: AppColors.textInverse,
              side: BorderSide(
                color: selected ? _homeVisitPrimary : AppColors.border,
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.button,
              ),
              labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected ? AppColors.textInverse : AppColors.text,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) => onSelected(option.value),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildVisitModeBadge(String mode) {
    final color = _visitModeColor(mode);
    final icon = _visitModeIcon(mode);
    final label = _visitModeLabel(mode);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  IconData _visitModeIcon(String mode) {
    return switch (mode) {
      'new' => Icons.add_circle_outline,
      'monthly' => Icons.calendar_month_outlined,
      'emergency' => Icons.emergency_outlined,
      'dhc_visit' => Icons.home_work_outlined,
      'vhc_visit' => Icons.local_hospital_outlined,
      _ => Icons.help_outline,
    };
  }

  Color _visitModeColor(String mode) {
    return switch (mode) {
      'new' => AppColors.success,
      'monthly' => AppColors.primary,
      'emergency' => AppColors.danger,
      'dhc_visit' => AppColors.warning,
      'vhc_visit' => AppColors.scheduled,
      _ => AppColors.textSecondary,
    };
  }

  String _visitModeLabel(String mode) {
    return switch (mode) {
      'new' => 'New',
      'monthly' => 'Planned NHC',
      'emergency' => 'Emergency',
      'dhc_visit' => 'DHC',
      'vhc_visit' => 'VHC',
      _ => mode.toUpperCase(),
    };
  }
}

class _FilterOption {
  const _FilterOption(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;
}

class _SearchIconButton extends StatelessWidget {
  const _SearchIconButton({
    required this.icon,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? _homeVisitPrimary : AppColors.text;

    return Material(
      color: active
          ? _homeVisitPrimary.withValues(alpha: 0.1)
          : AppColors.surface1,
      borderRadius: AppRadius.md,
      child: InkWell(
        borderRadius: AppRadius.md,
        onTap: onPressed,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: color, size: AppIcons.large),
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
