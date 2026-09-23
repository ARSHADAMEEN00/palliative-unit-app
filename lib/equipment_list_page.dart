import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/equipment_supply_list_page.dart';
import 'package:oruma_app/eq_supply.dart'; // Import for Distribute Page
import 'package:intl/intl.dart';
import 'package:oruma_app/models/equipment.dart';
import 'package:oruma_app/models/equipment_supply.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/services/equipment_service.dart';
import 'package:oruma_app/services/equipment_supply_service.dart';
import 'package:oruma_app/services/feature_permissions.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';
import 'package:oruma_app/widgets/feature_permission_gate.dart';
import 'package:oruma_app/widgets/module_switch_tabs.dart';
import 'package:oruma_app/widgets/module_theme.dart';
import 'package:oruma_app/widgets/reveal_action_fab.dart';
import 'package:provider/provider.dart';

const _equipmentPrimary = Color(0xFFF59E0B);
const _equipmentStrong = Color(0xFFB45309);
const _equipmentSurface = Color(0xFFFFFBEB);
const _equipmentIconSurface = Color(0xFFFEF3C7);

class EquipmentListPage extends StatefulWidget {
  final int initialTab;

  const EquipmentListPage({super.key, this.initialTab = 0});

  @override
  State<EquipmentListPage> createState() => _EquipmentListPageState();
}

class _EquipmentListPageState extends State<EquipmentListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;

  // Available list data
  List<Equipment> _availableItems = [];
  bool _loadingAvailable = true;
  String? _errorAvailable;

  // Distributed list data
  List<EquipmentSupply> _distributedItems = [];
  bool _loadingDistributed = true;
  String? _errorDistributed;

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _availableSearchDebounce;
  int _availableRequestId = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab == 1 ? 1 : 0;
    _tabController = TabController(
      length: 2,
      initialIndex: _currentIndex,
      vsync: this,
    );
    _tabController.addListener(_handleTabSelection);
    _searchController.addListener(_handleSearchChanged);
    _loadAllData();
  }

  @override
  void dispose() {
    _availableSearchDebounce?.cancel();
    _searchController.removeListener(_handleSearchChanged);
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });

    if (_currentIndex == 0) {
      _availableSearchDebounce?.cancel();
      _availableSearchDebounce = Timer(
        const Duration(milliseconds: 300),
        () => _fetchAvailableEquipment(search: _searchQuery),
      );
    }
  }

  void _handleTabSelection() {
    if (_tabController.index != _currentIndex) {
      setState(() {
        _currentIndex = _tabController.index;
      });
      final auth = context.read<AuthService>();
      if (_currentIndex == 0) {
        if (auth.canAccessEquipment) {
          _fetchAvailableEquipment(search: _searchQuery);
        }
      } else {
        if (auth.canAccessEquipmentDistribution) {
          _fetchDistributedEquipment();
        }
      }
    }
  }

  void _loadAllData() {
    final auth = context.read<AuthService>();
    if (auth.canAccessEquipment) {
      _fetchAvailableEquipment(search: _searchQuery);
    } else {
      setState(() => _loadingAvailable = false);
    }
    if (auth.canAccessEquipmentDistribution) {
      _fetchDistributedEquipment();
    } else {
      setState(() => _loadingDistributed = false);
    }
  }

  Future<void> _fetchAvailableEquipment({String? search}) async {
    final requestId = ++_availableRequestId;
    final normalizedSearch = (search ?? _searchQuery).trim();

    setState(() {
      _loadingAvailable = true;
      _errorAvailable = null;
    });

    try {
      final list = await EquipmentService.getAvailableEquipment(
        search: normalizedSearch,
      );
      if (!mounted || requestId != _availableRequestId) {
        return;
      }
      setState(() => _availableItems = list);
    } catch (e) {
      if (!mounted || requestId != _availableRequestId) {
        return;
      }
      setState(() => _errorAvailable = e.toString());
    } finally {
      if (mounted && requestId == _availableRequestId) {
        setState(() => _loadingAvailable = false);
      }
    }
  }

  Future<void> _fetchDistributedEquipment() async {
    setState(() {
      _loadingDistributed = true;
      _errorDistributed = null;
    });

    try {
      final list = await EquipmentSupplyService.getActiveSupplies();
      if (mounted) setState(() => _distributedItems = list);
    } catch (e) {
      if (mounted) setState(() => _errorDistributed = e.toString());
    } finally {
      if (mounted) setState(() => _loadingDistributed = false);
    }
  }

  void _navigateToAdd() {
    if (_tabController.index == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const EquipmentFormPage()),
      ).then((val) {
        if (val == true) {
          _fetchAvailableEquipment(search: _searchQuery);
        }
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const EqSupply()),
      ).then((val) {
        if (val == true) _fetchDistributedEquipment();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final canUseFab =
        auth.canCreate &&
        (_currentIndex == 0
            ? auth.canAccessEquipment
            : auth.canAccessEquipmentDistribution);

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
            selectedIndex: 1,
            color: _equipmentStrong,
            onSelected: (index) {
              if (index == 0) {
                if (!FeaturePermissionMiddleware.ensure(
                  context,
                  AppFeature.equipmentDistribution,
                  moduleName: 'Equipment Supply',
                )) {
                  return;
                }
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ModuleTheme(
                      palette: ModulePalettes.equipmentSupply,
                      child: EquipmentSupplyListPage(),
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
              child: _buildInventoryTabs(),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: _EquipmentIconButton(
                icon: Icons.refresh,
                onPressed: _loadAllData,
              ),
            ),
          ],
        ),
        floatingActionButton: canUseFab
            ? RevealActionFab(
                onPressed: _navigateToAdd,
                backgroundColor: _equipmentStrong,
                foregroundColor: AppColors.textInverse,
                icon: Icons.add,
                label: _tabController.index == 0
                    ? 'Add Equipment'
                    : 'Distribute',
              )
            : null,
        contentMaxWidth: 860,
        body: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildAvailableList(), _buildDistributedList()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryTabs() {
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
        labelColor: _equipmentStrong,
        unselectedLabelColor: AppColors.textSecondary,
        indicator: const BoxDecoration(
          color: _equipmentSurface,
          borderRadius: AppRadius.md,
        ),
        labelStyle: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Available'),
          Tab(text: 'Distributed'),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final isAvailableTab = _currentIndex == 0;

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
        decoration: _searchDecoration(
          isAvailableTab
              ? 'Search equipment name or unique ID'
              : 'Search patient or equipment',
        ),
      ),
    );
  }

  // --- Available List Tab ---
  Widget _buildAvailableList() {
    if (_loadingAvailable) {
      return const AppListSkeleton(itemCount: 5);
    }
    if (_errorAvailable != null) {
      return _errorState(_errorAvailable!, () {
        _fetchAvailableEquipment(search: _searchQuery);
      });
    }
    if (_availableItems.isEmpty) {
      return _emptyState(
        icon: _searchQuery.trim().isNotEmpty
            ? Icons.search_off_outlined
            : Icons.inventory_2_outlined,
        title: _searchQuery.trim().isNotEmpty
            ? 'No matching equipment'
            : 'No available equipment',
        message: _searchQuery.trim().isNotEmpty
            ? 'Try another equipment name or unique ID.'
            : 'Equipment ready for distribution will appear here.',
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        AppInsets.screenHorizontal(context),
        AppSpacing.xs,
        AppInsets.screenHorizontal(context),
        112,
      ),
      itemCount: _availableItems.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final eq = _availableItems[index];
        final auth = context.read<AuthService>();
        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          surfaceLevel: AppSurfaceLevel.elevated,
          onTap: () => _showEquipmentDetails(eq),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _equipmentAvatar(Icons.medical_services_outlined),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eq.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      eq.uniqueId,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _equipmentStrong,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (eq.storagePlace?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: AppSpacing.xs),
                      _inlineDetail(
                        Icons.warehouse_outlined,
                        eq.storagePlace!.trim(),
                      ),
                    ],
                  ],
                ),
              ),
              if (auth.canEdit || auth.canDelete)
                PopupMenuButton<String>(
                  iconColor: AppColors.textSecondary,
                  onSelected: (value) async {
                    if (value == 'edit') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              EquipmentFormPage(equipment: eq),
                        ),
                      ).then((result) {
                        if (result == true) {
                          _fetchAvailableEquipment(search: _searchQuery);
                        }
                      });
                    } else if (value == 'delete') {
                      await _deleteEquipment(eq);
                    }
                  },
                  itemBuilder: (context) => [
                    if (auth.canEdit)
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (auth.canDelete)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete',
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ),
                  ],
                )
              else
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        );
      },
    );
  }

  // --- Distributed List Tab ---
  Widget _buildDistributedList() {
    if (_loadingDistributed) {
      return const AppListSkeleton(itemCount: 5);
    }
    if (_errorDistributed != null) {
      return _errorState(_errorDistributed!, _fetchDistributedEquipment);
    }
    if (_distributedItems.isEmpty) {
      return _emptyState(
        icon: Icons.assignment_turned_in_outlined,
        title: 'No distributed equipment',
        message: 'Active equipment distributions will appear here.',
      );
    }

    final filteredItems = _distributedItems.where((supply) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return (supply.patientName?.toLowerCase().contains(query) ?? false) ||
          supply.equipmentUniqueId.toLowerCase().contains(query) ||
          supply.equipmentName.toLowerCase().contains(query);
    }).toList();

    if (filteredItems.isEmpty) {
      return _emptyState(
        icon: Icons.search_off_outlined,
        title: 'No matching distribution',
        message: 'Try another patient name, equipment name, or unique ID.',
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        AppInsets.screenHorizontal(context),
        AppSpacing.xs,
        AppInsets.screenHorizontal(context),
        112,
      ),
      itemCount: filteredItems.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final supply = filteredItems[index];
        final recipient =
            supply.patientName ?? supply.receiverName ?? 'Unknown';
        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          surfaceLevel: AppSurfaceLevel.elevated,
          onTap: () => _showSupplyDetails(supply),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _equipmentAvatar(Icons.person_outline),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipient,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${supply.equipmentUniqueId} - ${supply.equipmentName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _equipmentStrong,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _inlineDetail(
                      Icons.calendar_today_outlined,
                      'Supplied ${_formatDate(supply.supplyDate)}',
                    ),
                  ],
                ),
              ),
              if (context.read<AuthService>().canEdit)
                PopupMenuButton<String>(
                  iconColor: AppColors.textSecondary,
                  onSelected: (val) {
                    if (val == 'return') _returnSupply(supply);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'return',
                      child: Row(
                        children: [
                          Icon(
                            Icons.assignment_return,
                            color: _equipmentStrong,
                          ),
                          SizedBox(width: 8),
                          Text('Mark Returned'),
                        ],
                      ),
                    ),
                  ],
                )
              else
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        );
      },
    );
  }

  void _showSupplyDetails(EquipmentSupply supply) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottomSafePadding = MediaQuery.of(context).viewPadding.bottom;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: _SheetHandle()),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    _equipmentAvatar(Icons.medical_services_outlined, size: 48),
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
                                  color: _equipmentStrong,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(supply.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Receiver Details',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: AppColors.text),
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildDetailRow(
                  Icons.person_outline,
                  'Name',
                  supply.receiverName ?? 'N/A',
                ),
                _buildDetailRow(
                  Icons.phone_outlined,
                  'Phone',
                  supply.receiverPhone ?? 'N/A',
                ),
                if (supply.receiverAddress != null &&
                    supply.receiverAddress!.isNotEmpty)
                  _buildDetailRow(
                    Icons.location_on_outlined,
                    'Address',
                    '${supply.receiverAddress}${supply.receiverPlace != null ? ', ${supply.receiverPlace}' : ''}',
                  ),
                if (supply.patientName != null &&
                    supply.patientName!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Patient Details',
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: AppColors.text),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildDetailRow(
                    Icons.person_outlined,
                    'Name',
                    supply.patientName!,
                  ),
                  if (supply.patientPhone != null &&
                      supply.patientPhone!.isNotEmpty)
                    _buildDetailRow(
                      Icons.phone_outlined,
                      'Phone',
                      supply.patientPhone!,
                    ),
                  if (supply.patientAddress != null &&
                      supply.patientAddress!.isNotEmpty)
                    _buildDetailRow(
                      Icons.location_on_outlined,
                      'Address',
                      supply.patientAddress!,
                    ),
                ],
                const SizedBox(height: AppSpacing.lg),
                _buildDetailRow(
                  Icons.calendar_today_outlined,
                  'Supply Date',
                  _formatDate(supply.supplyDate),
                ),
                if (supply.notes != null && supply.notes!.isNotEmpty)
                  _buildDetailRow(Icons.note_outlined, 'Notes', supply.notes!),
                if (supply.createdBy != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      'Created by: ${supply.createdBy}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                if (context.read<AuthService>().canEdit) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppSecondaryButton(
                    label: 'Mark as Returned',
                    icon: Icons.assignment_return_outlined,
                    fullWidth: true,
                    onPressed: () {
                      Navigator.pop(context);
                      _returnSupply(supply);
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEquipmentDetails(Equipment eq) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottomSafePadding = MediaQuery.of(context).viewPadding.bottom;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: _SheetHandle()),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    _equipmentAvatar(Icons.medical_services_outlined, size: 48),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            eq.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            eq.uniqueId,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: _equipmentStrong,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(eq.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (eq.storagePlace != null && eq.storagePlace!.isNotEmpty)
                  _buildDetailRow(
                    Icons.warehouse_outlined,
                    'Storage Place',
                    eq.storagePlace!,
                  ),
                _buildDetailRow(
                  Icons.store_outlined,
                  'Purchased From',
                  eq.purchasedFrom.isEmpty ? 'N/A' : eq.purchasedFrom,
                ),
                if (eq.purchaseDate != null)
                  _buildDetailRow(
                    Icons.calendar_today_outlined,
                    'Purchase Date',
                    DateFormat('d MMM yyyy').format(eq.purchaseDate!),
                  ),
                if (eq.place.isNotEmpty)
                  _buildDetailRow(
                    Icons.location_on_outlined,
                    'Vendor Location',
                    eq.place,
                  ),
                _buildDetailRow(
                  Icons.phone_outlined,
                  'Contact',
                  eq.phone.isEmpty ? 'N/A' : eq.phone,
                ),
                if (eq.createdBy != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      'Created by: ${eq.createdBy}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    if (context.read<AuthService>().canEdit) ...[
                      Expanded(
                        child: AppSecondaryButton(
                          label: 'Edit Details',
                          icon: Icons.edit_outlined,
                          fullWidth: true,
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    EquipmentFormPage(equipment: eq),
                              ),
                            ).then((result) {
                              if (result == true) {
                                _fetchAvailableEquipment(search: _searchQuery);
                              }
                            });
                          },
                        ),
                      ),
                    ],
                    if (context.read<AuthService>().canDelete) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppDangerButton(
                          label: 'Delete',
                          icon: Icons.delete_outline,
                          fullWidth: true,
                          onPressed: () async {
                            final deleted = await _deleteEquipment(eq);
                            if (deleted) {
                              if (!mounted) return;
                              Navigator.of(this.context).pop();
                            }
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = AppColors.success;
    final s = status.toLowerCase();
    if (s == 'distributed' || s == 'active') color = _equipmentStrong;
    if (s == 'maintenance' || s == 'lost') color = AppColors.danger;
    if (s == 'returned') color = AppColors.success;

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
              color: _equipmentIconSurface,
              borderRadius: AppRadius.sm,
            ),
            child: Icon(icon, size: AppIcons.normal, color: _equipmentStrong),
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

  Widget _errorState(String error, VoidCallback retry) {
    return AppEmptyState(
      icon: Icons.cloud_off_outlined,
      title: 'Could not load equipment',
      message: error.replaceFirst(RegExp(r'^Exception:\s*'), ''),
      action: AppPrimaryButton(
        label: 'Retry',
        icon: Icons.refresh,
        onPressed: retry,
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: AppEmptyState(icon: icon, title: title, message: message),
          ),
        );
      },
    );
  }

  Widget _equipmentAvatar(IconData icon, {double size = 44}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: _equipmentIconSurface,
        borderRadius: AppRadius.md,
      ),
      child: Icon(icon, color: _equipmentStrong, size: size * 0.52),
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
        color: _equipmentIconSurface,
        borderRadius: AppRadius.sm,
      ),
      child: Icon(icon, color: _equipmentStrong, size: AppIcons.normal),
    );
  }

  InputDecoration _searchDecoration(String hint) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textSecondary),
      prefixIcon: _compactPrefixIcon(Icons.search),
      prefixIconConstraints: const BoxConstraints(minWidth: 50, minHeight: 50),
      suffixIcon: _searchQuery.trim().isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () {
                _searchController.clear();
                FocusScope.of(context).unfocus();
              },
            )
          : null,
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
        borderSide: const BorderSide(color: _equipmentStrong, width: 1.5),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _returnSupply(EquipmentSupply supply) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        title: const _EquipmentDialogHeader(
          icon: Icons.assignment_return_outlined,
          title: 'Confirm return',
          color: _equipmentStrong,
        ),
        content: Text(
          'Mark ${supply.equipmentUniqueId} as returned from ${supply.patientName}?',
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
          AppPrimaryButton(
            label: 'Confirm',
            icon: Icons.assignment_return_outlined,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true && supply.id != null) {
      try {
        await EquipmentSupplyService.returnSupply(supply.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Equipment returned'),
              backgroundColor: AppColors.success,
            ),
          );
          _fetchDistributedEquipment();
          _fetchAvailableEquipment(search: _searchQuery);
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

  Future<bool> _deleteEquipment(Equipment eq) async {
    if (eq.id == null) return false;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        title: const _EquipmentDialogHeader(
          icon: Icons.delete_outline,
          title: 'Delete equipment?',
          color: AppColors.danger,
        ),
        content: Text(
          'Delete ${eq.uniqueId}? This action cannot be undone.',
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

    if (confirm != true) return false;

    try {
      await EquipmentService.deleteEquipment(eq.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Equipment deleted'),
            backgroundColor: AppColors.success,
          ),
        );
        _fetchAvailableEquipment(search: _searchQuery);
      }
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return false;
    }
  }
}

// ============================================
// EQUIPMENT DETAIL PAGE, FORM PAGE, EDIT PAGE
// ============================================

// (EquipmentDetailPage removed and replaced by _showEquipmentDetails bottom sheet)

// Form Page (Create Bulk) - Same as previous logic
// Form Page (Create Bulk) - Compact & Modern
class EquipmentFormPage extends StatefulWidget {
  final Equipment? equipment;
  const EquipmentFormPage({super.key, this.equipment});

  @override
  State<EquipmentFormPage> createState() => _EquipmentFormPageState();
}

class _EquipmentFormPageState extends State<EquipmentFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late TextEditingController _purchasedFromController;
  late TextEditingController _purchaseDateController;
  late TextEditingController _purchasePlaceController;
  late TextEditingController _phoneController;
  late TextEditingController _serialNoPrefixController;
  late TextEditingController _uniqueIdController;
  late DateTime _purchaseDate;
  String? _selectedStoragePlace;
  bool _isSubmitting = false;

  // ── Autocomplete state ──────────────────────────────────────────────────
  List<Equipment> _allEquipment = [];
  List<Equipment> _suggestions = [];
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final FocusNode _nameFocus = FocusNode();
  // ────────────────────────────────────────────────────────────────────────

  bool get _isEditing => widget.equipment != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.equipment?.name ?? '');
    _quantityController = TextEditingController(text: '1');
    _purchasedFromController = TextEditingController(
      text: widget.equipment?.purchasedFrom ?? '',
    );
    _purchaseDate = _normalizeDate(
      widget.equipment?.purchaseDate ?? DateTime.now(),
    );
    _purchaseDateController = TextEditingController(
      text: _formatPurchaseDate(_purchaseDate),
    );
    _purchasePlaceController = TextEditingController(
      text: widget.equipment?.place ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.equipment?.phone ?? '',
    );
    _serialNoPrefixController = TextEditingController(
      text: widget.equipment?.serialNo ?? '',
    );
    _uniqueIdController = TextEditingController(
      text: widget.equipment?.uniqueId ?? '',
    );
    _selectedStoragePlace = widget.equipment?.storagePlace ?? 'Store';

    // Load equipment list for autocomplete (uses AppCache — very fast)
    _loadEquipment();

    // Listen to name field changes to update suggestions
    _nameController.addListener(_onNameChanged);
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) {
        // Delay so the overlay item's onTap fires before the overlay is removed
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) _hideSuggestions();
        });
      }
    });
  }

  // ── Autocomplete helpers ────────────────────────────────────────────────

  Future<void> _loadEquipment() async {
    try {
      final list = await EquipmentService.getAllEquipment();
      if (mounted) {
        // Deduplicate by name so each equipment type appears only once
        final seen = <String>{};
        setState(() {
          _allEquipment = list
              .where((e) => seen.add(e.name.trim().toLowerCase()))
              .toList();
        });
      }
    } catch (_) {
      // Autocomplete is optional — silently ignore errors
    }
  }

  void _onNameChanged() {
    final query = _nameController.text.trim().toLowerCase();
    if (query.isEmpty) {
      _hideSuggestions();
      return;
    }
    final matches = _allEquipment
        .where((e) => e.name.trim().toLowerCase().contains(query))
        .toList();
    setState(() => _suggestions = matches);
    if (matches.isEmpty) {
      _hideSuggestions();
    } else {
      _showSuggestions();
    }
  }

  /// Extracts the base prefix from a uniqueId like "AMCR-001" → "AMCR".
  String _extractPrefix(Equipment eq) {
    // Prefer the serialNo field directly (it already stores the prefix)
    if (eq.serialNo.isNotEmpty) return eq.serialNo;
    // Fallback: strip the numeric suffix from uniqueId
    final dash = eq.uniqueId.lastIndexOf('-');
    if (dash > 0) return eq.uniqueId.substring(0, dash);
    return eq.uniqueId;
  }

  void _selectEquipment(Equipment eq) {
    _nameController.removeListener(_onNameChanged);
    _nameController.text = eq.name;
    _nameController.addListener(_onNameChanged);
    // Auto-fill Serial No Prefix
    _serialNoPrefixController.text = _extractPrefix(eq);
    _hideSuggestions();
    _nameFocus.unfocus();
  }

  void _showSuggestions() {
    _hideSuggestions();
    _overlayEntry = _buildOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideSuggestions() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _buildOverlayEntry() {
    const maxItems = 5;
    final itemH = 52.0;
    final height = (_suggestions.length.clamp(1, maxItems)) * itemH;

    return OverlayEntry(
      builder: (ctx) => Positioned(
        width: MediaQuery.of(context).size.width - 64, // match field width
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 52), // drop below the field
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: height + 2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (context, i) {
                    final eq = _suggestions[i];
                    final prefix = _extractPrefix(eq);
                    return InkWell(
                      onTap: () => _selectEquipment(eq),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _equipmentSurface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                prefix.isNotEmpty
                                    ? prefix.substring(
                                        0,
                                        prefix.length.clamp(0, 4),
                                      )
                                    : '??',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _equipmentPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    eq.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Prefix: $prefix',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.north_west,
                              size: 14,
                              color: Colors.grey[400],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Build the Equipment Name field with the autocomplete overlay ─────────
  Widget _buildNameFieldWithAutocomplete() {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: _nameController,
        focusNode: _nameFocus,
        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.text,
          fontWeight: FontWeight.w500,
        ),
        decoration:
            _formInputDecoration(
              'Equipment Name',
              Icons.medical_services_outlined,
            ).copyWith(
              suffixIcon: _suggestions.isNotEmpty
                  ? const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                    )
                  : null,
            ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day, 12, 0, 0);
  }

  String _formatPurchaseDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Future<void> _pickPurchaseDate() async {
    final today = _normalizeDate(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate.isAfter(today) ? today : _purchaseDate,
      firstDate: DateTime(2000),
      lastDate: today,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _equipmentPrimary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _purchaseDate = _normalizeDate(picked);
        _purchaseDateController.text = _formatPurchaseDate(_purchaseDate);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      if (_isEditing) {
        await EquipmentService.updateEquipment(
          widget.equipment!.id!,
          name: _nameController.text.trim(),
          serialNo: _serialNoPrefixController.text.trim().isNotEmpty
              ? _serialNoPrefixController.text.trim()
              : null,
          purchasedFrom: _purchasedFromController.text.trim(),
          purchaseDate: _purchaseDate,
          place: _purchasePlaceController.text.trim(),
          phone: _phoneController.text.trim(),
          storagePlace: _selectedStoragePlace,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Equipment updated successfully")),
          );
          Navigator.pop(context, true);
        }
      } else {
        final response = await EquipmentService.createEquipment(
          name: _nameController.text.trim(),
          quantity: int.parse(_quantityController.text.trim()),
          serialNo: _serialNoPrefixController.text.trim().isNotEmpty
              ? _serialNoPrefixController.text.trim()
              : null,
          purchasedFrom: _purchasedFromController.text.trim(),
          purchaseDate: _purchaseDate,
          place: _purchasePlaceController.text.trim(),
          phone: _phoneController.text.trim(),
          storagePlace: _selectedStoragePlace,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Created ${response.count} items")),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _hideSuggestions();
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _nameFocus.dispose();
    _quantityController.dispose();
    _purchasedFromController.dispose();
    _purchaseDateController.dispose();
    _purchasePlaceController.dispose();
    _phoneController.dispose();
    _serialNoPrefixController.dispose();
    _uniqueIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ModuleTheme(
      palette: ModulePalettes.equipmentSupply,
      child: AdaptiveAppScaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          toolbarHeight: 72,
          titleSpacing: AppSpacing.md,
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.text,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            _isEditing ? 'Edit Equipment' : 'Add Equipment',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        bottomSheet: Container(
          padding: EdgeInsets.fromLTRB(
            AppInsets.screenHorizontal(context),
            AppSpacing.sm,
            AppInsets.screenHorizontal(context),
            AppSpacing.md,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surfaceFloating,
            border: Border(top: BorderSide(color: AppColors.border)),
            boxShadow: AppShadow.medium,
          ),
          child: SafeArea(
            top: false,
            child: AppPrimaryButton(
              label: _isEditing ? 'Save Changes' : 'Create Equipment',
              icon: Icons.save_outlined,
              fullWidth: true,
              loading: _isSubmitting,
              onPressed: _isSubmitting ? null : _submit,
            ),
          ),
        ),
        contentMaxWidth: 900,
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppInsets.screenHorizontal(context),
            AppSpacing.md,
            AppInsets.screenHorizontal(context),
            112,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                AppCard(
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  padding: AppInsets.card,
                  surfaceLevel: AppSurfaceLevel.elevated,
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: _equipmentIconSurface,
                          borderRadius: AppRadius.md,
                        ),
                        child: Icon(
                          _isEditing
                              ? Icons.edit_outlined
                              : Icons.add_box_outlined,
                          color: _equipmentStrong,
                          size: AppIcons.large,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEditing ? 'Update Details' : 'New Equipment',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              _isEditing
                                  ? 'Modify the existing inventory record.'
                                  : 'Add clean inventory records with a reusable equipment profile.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Info Card
                _buildSection(
                  title: 'Basic Information',
                  children: [
                    _buildNameFieldWithAutocomplete(),
                    const SizedBox(height: 12),
                    if (_isEditing) ...[
                      _buildCompactField(
                        controller: _uniqueIdController,
                        label: 'Unique ID',
                        icon: Icons.qr_code,
                        readOnly: true,
                      ),
                      const SizedBox(height: 12),
                    ],
                    _buildCompactField(
                      controller: _serialNoPrefixController,
                      label: 'Serial No Prefix (Optional)',
                      icon: Icons.tag,
                      readOnly: _isEditing,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (!_isEditing) ...[
                          Expanded(
                            flex: 1,
                            child: _buildCompactField(
                              controller: _quantityController,
                              label: 'Qty',
                              icon: Icons.numbers,
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v!.isEmpty) return 'Req';
                                if (int.tryParse(v) == null) return 'Inv';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(flex: 2, child: _buildStoragePlaceDropdown()),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Purchase Info Card
                _buildSection(
                  title: 'Purchase & Contact',
                  children: [
                    _buildCompactField(
                      controller: _purchasedFromController,
                      label: 'Purchased From',
                      icon: Icons.store_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildDateField(),
                    const SizedBox(height: 12),
                    _buildCompactField(
                      controller: _purchasePlaceController,
                      label: 'Place',
                      icon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildCompactField(
                      controller: _phoneController,
                      label: 'Contact Phone',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
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

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return AppCard(
      padding: AppInsets.card,
      surfaceLevel: AppSurfaceLevel.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.lg),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDateField() {
    return TextFormField(
      controller: _purchaseDateController,
      readOnly: true,
      onTap: _isSubmitting ? null : _pickPurchaseDate,
      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: AppColors.text,
        fontWeight: FontWeight.w500,
      ),
      decoration:
          _formInputDecoration(
            'Purchase Date',
            Icons.calendar_today_outlined,
          ).copyWith(
            suffixIcon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary,
            ),
          ),
    );
  }

  Widget _buildCompactField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      style: TextStyle(
        fontWeight: FontWeight.w500,
        color: readOnly ? AppColors.textSecondary : AppColors.text,
      ),
      decoration: _formInputDecoration(label, icon, readOnly: readOnly),
    );
  }

  Widget _buildStoragePlaceDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedStoragePlace,
      style: AppTypography.dropdownTextStyle(context),
      decoration: _formInputDecoration(
        'Storage Place',
        Icons.warehouse_outlined,
      ),
      items: const [DropdownMenuItem(value: 'Store', child: Text('Store'))],
      onChanged: (value) {
        setState(() {
          _selectedStoragePlace = value;
        });
      },
      validator: (v) => v == null ? 'Required' : null,
    );
  }

  InputDecoration _formInputDecoration(
    String label,
    IconData icon, {
    bool readOnly = false,
  }) {
    return InputDecoration(
      isDense: true,
      hintText: label,
      hintStyle: const TextStyle(color: AppColors.textSecondary),
      prefixIcon: _compactFormPrefixIcon(icon),
      prefixIconConstraints: const BoxConstraints(minWidth: 50, minHeight: 50),
      floatingLabelBehavior: FloatingLabelBehavior.never,
      filled: true,
      fillColor: readOnly ? AppColors.surface2 : AppColors.surface1,
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
        borderSide: const BorderSide(color: _equipmentStrong, width: 1.5),
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

  Widget _compactFormPrefixIcon(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      margin: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: _equipmentIconSurface,
        borderRadius: AppRadius.sm,
      ),
      child: Icon(icon, color: _equipmentStrong, size: AppIcons.normal),
    );
  }
}

// (EquipmentEditPage removed and merged into EquipmentFormPage)

class _EquipmentIconButton extends StatelessWidget {
  const _EquipmentIconButton({required this.icon, required this.onPressed});

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

class _EquipmentDialogHeader extends StatelessWidget {
  const _EquipmentDialogHeader({
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
