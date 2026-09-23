import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/eq_supply.dart';
import 'package:oruma_app/eq_supply_edit.dart';
import 'package:oruma_app/equipment_list_page.dart';
import 'package:oruma_app/models/equipment_supply.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/services/equipment_supply_service.dart';
import 'package:oruma_app/services/feature_permissions.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';
import 'package:oruma_app/widgets/feature_permission_gate.dart';
import 'package:oruma_app/widgets/module_switch_tabs.dart';
import 'package:oruma_app/widgets/module_theme.dart';
import 'package:oruma_app/widgets/reveal_action_fab.dart';
import 'package:provider/provider.dart';

const _equipmentSupplyStrong = Color(0xFFB45309);
const _equipmentSupplySurface = Color(0xFFFFFBEB);
const _equipmentSupplyIconSurface = Color(0xFFFEF3C7);

class EquipmentSupplyListPage extends StatefulWidget {
  const EquipmentSupplyListPage({super.key});

  @override
  State<EquipmentSupplyListPage> createState() =>
      _EquipmentSupplyListPageState();
}

class _EquipmentSupplyListPageState extends State<EquipmentSupplyListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Active supplies (currently distributed)
  List<EquipmentSupply> _activeSupplies = [];
  bool _loadingActive = true;
  String? _errorActive;

  // All supplies (history)
  List<EquipmentSupply> _allSupplies = [];
  bool _loadingAll = true;
  String? _errorAll;

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _searchController.addListener(_handleSearchChanged);
    _loadData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging && mounted) {
      setState(() {});
    }
  }

  void _loadData() {
    _fetchActiveSupplies();
    _fetchAllSupplies();
  }

  void _handleSearchChanged() {
    final query = _searchController.text.trim();

    setState(() {
      _searchQuery = query;
    });

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        _fetchActiveSupplies(showLoading: false);
        _fetchAllSupplies(showLoading: false);
      }
    });
  }

  Future<void> _fetchActiveSupplies({bool showLoading = true}) async {
    final search = _searchQuery.trim();

    if (showLoading) {
      setState(() {
        _loadingActive = true;
        _errorActive = null;
      });
    }

    try {
      final list = await EquipmentSupplyService.getActiveSupplies(
        search: search.isEmpty ? null : search,
      );
      if (!mounted || search != _searchQuery.trim()) return;
      setState(() {
        _activeSupplies = list;
        _errorActive = null;
      });
    } catch (e) {
      if (!mounted || search != _searchQuery.trim()) return;
      setState(() => _errorActive = e.toString());
    } finally {
      if (mounted && search == _searchQuery.trim()) {
        setState(() => _loadingActive = false);
      }
    }
  }

  Future<void> _fetchAllSupplies({bool showLoading = true}) async {
    final search = _searchQuery.trim();

    if (showLoading) {
      setState(() {
        _loadingAll = true;
        _errorAll = null;
      });
    }

    try {
      final list = await EquipmentSupplyService.getAllSupplies(
        search: search.isEmpty ? null : search,
      );
      if (!mounted || search != _searchQuery.trim()) return;
      setState(() {
        _allSupplies = list;
        _errorAll = null;
      });
    } catch (e) {
      if (!mounted || search != _searchQuery.trim()) return;
      setState(() => _errorAll = e.toString());
    } finally {
      if (mounted && search == _searchQuery.trim()) {
        setState(() => _loadingAll = false);
      }
    }
  }

  void _navigateToCreateSupply() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EqSupply()),
    ).then((result) {
      if (result == true) {
        _loadData();
      }
    });
  }

  void _navigateToEditSupply(EquipmentSupply supply) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EqSupplyEdit(supply: supply)),
    ).then((result) {
      if (result == true) {
        _loadData();
      }
    });
  }

  Future<void> _returnSupply(EquipmentSupply supply) async {
    final noteController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.dialog),
          title: const _EquipmentSupplyDialogHeader(
            icon: Icons.assignment_return_outlined,
            title: 'Confirm return',
            color: _equipmentSupplyStrong,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mark "${supply.equipmentUniqueId}" as returned from ${supply.patientName}?',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Return Date',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: supply.supplyDate,
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) {
                      setState(() => selectedDate = picked);
                    }
                  },
                  borderRadius: AppRadius.input,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 50),
                    padding: const EdgeInsets.only(
                      left: 6,
                      right: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface1,
                      border: Border.all(color: AppColors.border),
                      borderRadius: AppRadius.input,
                    ),
                    child: Row(
                      children: [
                        _compactPrefixIcon(Icons.calendar_today_outlined),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: noteController,
                  decoration: _compactInputDecoration(
                    'Condition of equipment, etc.',
                    Icons.notes_outlined,
                  ),
                  minLines: 1,
                  maxLines: 2,
                ),
              ],
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
              onPressed: () => Navigator.pop(context),
            ),
            AppPrimaryButton(
              label: 'Mark Returned',
              icon: Icons.assignment_return_outlined,
              onPressed: () => Navigator.pop(context, {
                'confirmed': true,
                'date': selectedDate,
                'note': noteController.text.trim(),
              }),
            ),
          ],
        ),
      ),
    );

    if (result != null && result['confirmed'] == true && supply.id != null) {
      try {
        await EquipmentSupplyService.returnSupply(
          supply.id!,
          date: result['date'],
          note: result['note'],
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Equipment marked as returned'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return ModuleTheme(
      palette: ModulePalettes.equipmentSupply,
      child: AdaptiveAppScaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          toolbarHeight: 76,
          titleSpacing: AppSpacing.md,
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.text,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: ModuleSwitchTabs(
            labels: const ['Supplies', 'Equipment'],
            icons: const [
              Icons.assignment_turned_in_outlined,
              Icons.medical_services_outlined,
            ],
            selectedIndex: 0,
            color: _equipmentSupplyStrong,
            onSelected: (index) {
              if (index == 1) {
                if (!FeaturePermissionMiddleware.ensure(
                  context,
                  AppFeature.equipment,
                  moduleName: 'Equipment Inventory',
                )) {
                  return;
                }
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ModuleTheme(
                      palette: ModulePalettes.equipmentSupply,
                      child: EquipmentListPage(),
                    ),
                  ),
                );
              }
            },
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppInsets.screenHorizontal(context),
                0,
                AppInsets.screenHorizontal(context),
                AppSpacing.sm,
              ),
              child: _buildSupplyTabs(),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: _EquipmentSupplyIconButton(
                icon: Icons.refresh,
                onPressed: _loadData,
              ),
            ),
          ],
        ),
        floatingActionButton:
            auth.canCreate && auth.canAccessEquipmentDistribution
            ? RevealActionFab(
                onPressed: _navigateToCreateSupply,
                backgroundColor: _equipmentSupplyStrong,
                foregroundColor: AppColors.textInverse,
                icon: Icons.add,
                label: 'New Supply',
              )
            : null,
        contentMaxWidth: 860,
        body: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildActiveList(), _buildHistoryList()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplyTabs() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.button,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.small,
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: _equipmentSupplyStrong,
        unselectedLabelColor: AppColors.textSecondary,
        indicator: const BoxDecoration(
          color: _equipmentSupplySurface,
          borderRadius: AppRadius.md,
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.pending_actions, size: 18),
                const SizedBox(width: AppSpacing.xs),
                const Text('Active'),
                if (_activeSupplies.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.xs),
                  _countBadge(_activeSupplies.length),
                ],
              ],
            ),
          ),
          const Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 18),
                SizedBox(width: AppSpacing.xs),
                Text('History'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return AppCard(
      margin: EdgeInsets.fromLTRB(
        AppInsets.screenHorizontal(context),
        AppSpacing.sm,
        AppInsets.screenHorizontal(context),
        AppSpacing.xs,
      ),
      padding: AppInsets.md,
      surfaceLevel: AppSurfaceLevel.elevated,
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: _compactInputDecoration(
          'Search patient, care of, or equipment',
          Icons.search,
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    FocusScope.of(context).unfocus();
                  },
                )
              : null,
        ),
      ),
    );
  }

  bool _matchesSearch(EquipmentSupply supply) {
    if (_searchQuery.isEmpty) return true;

    final q = _searchQuery.toLowerCase();
    return (supply.patientName?.toLowerCase().contains(q) ?? false) ||
        (supply.receiverName?.toLowerCase().contains(q) ?? false) ||
        (supply.careOf?.toLowerCase().contains(q) ?? false) ||
        (supply.patientPlace?.toLowerCase().contains(q) ?? false) ||
        (supply.receiverPlace?.toLowerCase().contains(q) ?? false) ||
        supply.equipmentName.toLowerCase().contains(q);
  }

  // --- Active Supplies Tab ---
  Widget _buildActiveList() {
    if (_loadingActive) {
      return const AppListSkeleton(itemCount: 5);
    }
    if (_errorActive != null) {
      return _buildErrorWidget(_errorActive!, _fetchActiveSupplies);
    }
    final filteredList = _activeSupplies.where(_matchesSearch).toList();

    if (filteredList.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return _buildEmptyWidget(
          icon: Icons.search_off,
          title: 'No results found',
          subtitle: 'Try a different search term',
        );
      }
      return _buildEmptyWidget(
        icon: Icons.assignment_turned_in_outlined,
        title: 'No Active Supplies',
        subtitle: 'All equipment has been returned',
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchActiveSupplies,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          AppInsets.screenHorizontal(context),
          AppSpacing.xs,
          AppInsets.screenHorizontal(context),
          112,
        ),
        itemCount: filteredList.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final supply = filteredList[index];
          return _buildSupplyCard(supply, isActive: true);
        },
      ),
    );
  }

  // --- History Tab (All Supplies) ---
  Widget _buildHistoryList() {
    if (_loadingAll) {
      return const AppListSkeleton(itemCount: 5);
    }
    if (_errorAll != null) {
      return _buildErrorWidget(_errorAll!, _fetchAllSupplies);
    }
    final filteredList = _allSupplies.where(_matchesSearch).toList();

    if (filteredList.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return _buildEmptyWidget(
          icon: Icons.search_off,
          title: 'No results found',
          subtitle: 'Try a different search term',
        );
      }
      return _buildEmptyWidget(
        icon: Icons.history,
        title: 'No Supply History',
        subtitle: 'Start by distributing equipment',
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAllSupplies,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          AppInsets.screenHorizontal(context),
          AppSpacing.xs,
          AppInsets.screenHorizontal(context),
          112,
        ),
        itemCount: filteredList.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final supply = filteredList[index];
          return _buildSupplyCard(supply, isActive: supply.status == 'active');
        },
      ),
    );
  }

  Future<void> _deleteSupply(EquipmentSupply supply) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        title: const _EquipmentSupplyDialogHeader(
          icon: Icons.delete_outline,
          title: 'Delete supply?',
          color: AppColors.danger,
        ),
        content: Text(
          'Are you sure you want to delete the supply record for ${supply.equipmentName}?',
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

    if (confirm == true && supply.id != null) {
      try {
        await EquipmentSupplyService.deleteSupply(supply.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Supply deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting supply: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  Widget _buildSupplyCard(EquipmentSupply supply, {required bool isActive}) {
    final statusColor = _getStatusColor(supply.status);
    final authService = Provider.of<AuthService>(context, listen: false);
    final canEdit = authService.canEdit;
    final canDelete = authService.canDelete;
    final recipientName = _supplyRecipientName(supply);
    final placeLabel = _supplyPlaceLabel(supply);

    Widget buildReturnButton() {
      if (isActive && canEdit) {
        return InkWell(
          onTap: () => _returnSupply(supply),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _equipmentSupplySurface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _equipmentSupplyIconSurface),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Return',
                  style: TextStyle(
                    color: _equipmentSupplyStrong,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 10,
                  color: _equipmentSupplyStrong,
                ),
              ],
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    Widget cardContent = AppCard(
      padding: EdgeInsets.zero,
      surfaceLevel: AppSurfaceLevel.elevated,
      onTap: () => _showSupplyDetails(supply),
      child: ClipRRect(
        borderRadius: AppRadius.card,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: statusColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _idBadge(supply.equipmentUniqueId),
                          Text(
                            _formatDate(supply.supplyDate),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        recipientName,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        supply.equipmentName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (placeLabel != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        _inlineDetail(Icons.place_outlined, placeLabel),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _inlineDetail(
                              Icons.phone_rounded,
                              _supplyPhone(supply),
                            ),
                          ),
                          buildReturnButton(),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (canEdit || canDelete) {
      List<Widget> actions = [];

      if (canEdit) {
        actions.add(
          SlidableAction(
            onPressed: (_) => _navigateToEditSupply(supply),
            backgroundColor: AppColors.info,
            foregroundColor: Colors.white,
            icon: Icons.edit_rounded,
            label: 'Edit',
          ),
        );
      }

      if (canDelete) {
        actions.add(
          SlidableAction(
            onPressed: (_) => _deleteSupply(supply),
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            icon: Icons.delete_rounded,
            label: 'Delete',
          ),
        );
      }

      return Padding(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: AppRadius.card,
          child: Slidable(
            key: ValueKey(supply.id),
            endActionPane: ActionPane(
              motion: const ScrollMotion(),
              extentRatio:
                  actions.length *
                  0.25, // Adjust ratio based on number of actions
              children: actions,
            ),
            child: cardContent,
          ),
        ),
      );
    }

    return Padding(padding: EdgeInsets.zero, child: cardContent);
  }

  String _supplyRecipientName(EquipmentSupply supply) {
    return _firstNonEmpty([
          supply.patientName,
          supply.receiverName,
          supply.careOf,
        ]) ??
        'Unknown';
  }

  String _supplyPhone(EquipmentSupply supply) {
    return _firstNonEmpty([supply.patientPhone, supply.receiverPhone]) ?? 'N/A';
  }

  String? _supplyPlaceLabel(EquipmentSupply supply) {
    return _firstNonEmpty([
      supply.patientPlace,
      supply.receiverPlace,
      supply.patientAddress,
      supply.receiverAddress,
    ]);
  }

  String? _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  Widget _buildEmptyWidget({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: AppEmptyState(icon: icon, title: title, message: subtitle),
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget(String error, VoidCallback retry) {
    return AppEmptyState(
      icon: Icons.cloud_off_outlined,
      title: 'Something went wrong',
      message: error.replaceFirst(RegExp(r'^Exception:\s*'), ''),
      action: AppPrimaryButton(
        label: 'Retry',
        icon: Icons.refresh,
        onPressed: retry,
      ),
    );
  }

  void _showSupplyDetails(EquipmentSupply supply) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.sheet,
        ),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg + MediaQuery.of(context).viewPadding.bottom,
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
                  _supplyAvatar(Icons.medical_services_outlined, size: 48),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          supply.equipmentName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          supply.equipmentUniqueId,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: _equipmentSupplyStrong,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  _statusBadge(supply.status),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (supply.patientName != null &&
                  supply.patientName!.isNotEmpty) ...[
                _buildDetailRow(
                  Icons.person,
                  'Patient',
                  supply.patientName!.toUpperCase(),
                ),
                _buildDetailRow(
                  Icons.phone,
                  'Phone',
                  supply.patientPhone ?? 'N/A',
                ),
                if (supply.patientAddress != null &&
                    supply.patientAddress!.isNotEmpty)
                  _buildDetailRow(
                    Icons.location_on,
                    'Address',
                    supply.patientAddress!,
                  ),
                if (supply.patientPlace != null &&
                    supply.patientPlace!.isNotEmpty)
                  _buildDetailRow(
                    Icons.location_city,
                    'Place',
                    supply.patientPlace!,
                  ),
                if (supply.careOf != null && supply.careOf!.isNotEmpty)
                  _buildDetailRow(
                    Icons.supervised_user_circle,
                    'Care Of',
                    supply.careOf!,
                  ),
              ] else ...[
                _buildDetailRow(
                  Icons.person,
                  'Receiver',
                  (supply.receiverName ?? 'Unknown').toUpperCase(),
                ),
                _buildDetailRow(
                  Icons.phone,
                  'Phone',
                  supply.receiverPhone ?? 'N/A',
                ),
                if (supply.receiverAddress != null &&
                    supply.receiverAddress!.isNotEmpty)
                  _buildDetailRow(
                    Icons.location_on,
                    'Address',
                    supply.receiverAddress!,
                  ),
                if (supply.receiverPlace != null &&
                    supply.receiverPlace!.isNotEmpty)
                  _buildDetailRow(
                    Icons.location_city,
                    'Place',
                    supply.receiverPlace!,
                  ),
                if (supply.careOf != null && supply.careOf!.isNotEmpty)
                  _buildDetailRow(
                    Icons.supervised_user_circle,
                    'Care Of',
                    supply.careOf!,
                  ),
              ],
              const SizedBox(height: AppSpacing.lg),
              _buildDetailRow(
                Icons.calendar_today,
                'Supply Date',
                _formatDate(supply.supplyDate),
              ),
              if (supply.returnDate != null)
                _buildDetailRow(
                  Icons.event_available,
                  'Expected Return',
                  _formatDate(supply.returnDate!),
                ),
              if (supply.actualReturnDate != null) ...[
                const SizedBox(height: 8),
                _buildDetailRow(
                  Icons.check_circle_outlined,
                  'Returned On',
                  _formatDate(supply.actualReturnDate!),
                ),
              ],
              if (supply.notes != null && supply.notes!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _buildDetailRow(Icons.note, 'Notes', supply.notes!),
              ],
              if (supply.returnNote != null &&
                  supply.returnNote!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildDetailRow(
                  Icons.assignment_return_outlined,
                  'Return Notes',
                  supply.returnNote!,
                ),
              ],
              if (supply.createdBy != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Padding(
                  padding: const EdgeInsets.only(top: 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Created by: ${supply.createdBy}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (supply.createdAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Created on: ${_formatDate(supply.createdAt!)}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: _equipmentSupplyIconSurface,
              borderRadius: AppRadius.sm,
            ),
            child: Icon(
              icon,
              size: AppIcons.normal,
              color: _equipmentSupplyStrong,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return _equipmentSupplyStrong;
      case 'returned':
        return AppColors.success;
      case 'lost':
        return AppColors.danger;
      default:
        return AppColors.offline;
    }
  }

  Widget _statusBadge(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        status.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _countBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _equipmentSupplyStrong,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.textInverse,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _idBadge(String id) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _equipmentSupplySurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _equipmentSupplyIconSurface),
      ),
      child: Text(
        id,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: _equipmentSupplyStrong,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _supplyAvatar(IconData icon, {double size = 44}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: _equipmentSupplyIconSurface,
        borderRadius: AppRadius.md,
      ),
      child: Icon(icon, color: _equipmentSupplyStrong, size: size * 0.52),
    );
  }

  Widget _inlineDetail(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppIcons.small, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            text,
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

  Widget _compactPrefixIcon(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      margin: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: _equipmentSupplyIconSurface,
        borderRadius: AppRadius.sm,
      ),
      child: Icon(icon, color: _equipmentSupplyStrong, size: AppIcons.normal),
    );
  }

  InputDecoration _compactInputDecoration(
    String hint,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textSecondary),
      prefixIcon: _compactPrefixIcon(icon),
      prefixIconConstraints: const BoxConstraints(minWidth: 50, minHeight: 50),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.surface1,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
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
        borderSide: const BorderSide(color: _equipmentSupplyStrong, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _EquipmentSupplyIconButton extends StatelessWidget {
  const _EquipmentSupplyIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

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
          child: Icon(
            icon,
            color: onPressed == null ? AppColors.textMuted : AppColors.text,
            size: AppIcons.large,
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

class _EquipmentSupplyDialogHeader extends StatelessWidget {
  const _EquipmentSupplyDialogHeader({
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
