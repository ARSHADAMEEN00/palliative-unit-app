import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oruma_app/medicine_supply_page.dart';
import 'package:oruma_app/medicine_list_page.dart';
import 'package:oruma_app/models/medicine_supply.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/services/feature_permissions.dart';
import 'package:oruma_app/services/medicine_supply_service.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';
import 'package:oruma_app/widgets/compact_app_bottom_bar.dart';
import 'package:oruma_app/widgets/app_bottom_nav_router.dart';
import 'package:oruma_app/widgets/feature_permission_gate.dart';
import 'package:oruma_app/widgets/module_switch_tabs.dart';
import 'package:oruma_app/widgets/reveal_action_fab.dart';

const _medicineGreen = Color(0xFF0F766E);
const _successGreen = Color(0xFF16A34A);
const _warningAmber = Color(0xFFF59E0B);
const _dangerRed = Color(0xFFDC2626);
const _screenBg = Color(0xFFF8FAFC);
const _cardBg = Color(0xFFFFFFFF);
const _topBarBg = Color(0xFFE1F5EE);
const _iconBg = Color(0xFFE6F6F3);
const _primaryText = Color(0xFF111827);
const _secondaryText = Color(0xFF6B7280);

enum _ExpiryState { normal, warning, expired }

class MedicineSupplyListPage extends StatefulWidget {
  const MedicineSupplyListPage({super.key});

  @override
  State<MedicineSupplyListPage> createState() => _MedicineSupplyListPageState();
}

class _MedicineSupplyListPageState extends State<MedicineSupplyListPage> {
  List<MedicineSupply> _supplies = [];
  bool _loading = true;
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _loadData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final query = _searchController.text.trim();
    setState(() => _searchQuery = query);
  }

  Future<void> _loadData({
    bool showLoading = true,
    bool forceRefresh = false,
  }) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final list = await MedicineSupplyService.getAllMedicineSupplies(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _supplies = list;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _navigateToCreateSupply() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MedicineSupplyPage()),
    ).then((result) {
      if (result == true) _loadData();
    });
  }

  bool _matchesSearch(MedicineSupply supply) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    return supply.patientName.toLowerCase().contains(q) ||
        (supply.patientRegisterId?.toLowerCase().contains(q) ?? false) ||
        supply.medicineName.toLowerCase().contains(q) ||
        supply.medicineSummary.toLowerCase().contains(q) ||
        supply.items.any(
          (item) =>
              item.batchNumber.toLowerCase().contains(q) ||
              item.medicineCode.toLowerCase().contains(q),
        );
  }

  void _handleBottomNavigation(BuildContext context, AppBottomSection section) {
    AppBottomNavRouter.handle(
      context,
      current: AppBottomSection.medicine,
      target: section,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return AdaptiveAppScaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: _topBarBg,
        surfaceTintColor: _topBarBg,
        foregroundColor: _medicineGreen,
        elevation: 1,
        title: ModuleSwitchTabs(
          labels: const ['Supplies', 'Medicines'],
          icons: const [
            Icons.assignment_turned_in_outlined,
            Icons.medication_liquid_outlined,
          ],
          selectedIndex: 0,
          color: _medicineGreen,
          onSelected: (index) {
            if (index == 1) {
              if (!FeaturePermissionMiddleware.ensure(
                context,
                AppFeature.medicineMaster,
                moduleName: 'Medicine',
              )) {
                return;
              }
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const MedicineListPage(),
                ),
              );
            }
          },
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadData(forceRefresh: true),
          ),
        ],
      ),
      floatingActionButton: auth.canCreate && auth.canAccessMedicineSupply
          ? RevealActionFab(
              onPressed: _navigateToCreateSupply,
              backgroundColor: _medicineGreen,
              foregroundColor: Colors.white,
              icon: Icons.add,
              label: 'New Supply',
            )
          : null,
      currentSection: AppBottomSection.medicine,
      onNavigationSelected: (section) =>
          _handleBottomNavigation(context, section),
      contentMaxWidth: 820,
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search by patient or medicine',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    FocusScope.of(context).unfocus();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _medicineGreen, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _medicineGreen),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('Error: $_error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    final filteredList = _groupSuppliesByPatient(
      _supplies,
    ).where(_matchesSearch).toList();

    if (filteredList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty
                  ? Icons.search_off
                  : Icons.assignment_turned_in_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No results found'
                  : 'No Medicine Supplies',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(showLoading: false, forceRefresh: true),
      color: _medicineGreen,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: filteredList.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final supply = filteredList[index];
          return _buildSupplyCard(supply);
        },
      ),
    );
  }

  Future<MedicineSupply?> _returnSupplyItem(
    MedicineSupply supply,
    MedicineSupplyItem item,
  ) async {
    final sourceSupplyId = item.supplyId ?? supply.id;
    if (sourceSupplyId == null || item.id == null || !item.canReturn) {
      return null;
    }

    final qtyController = TextEditingController(
      text: item.remainingQty.toString(),
    );
    final noteController = TextEditingController();
    var returnDate = DateTime.now();
    var expiryDate = DateTime.now().add(const Duration(days: 365));

    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              Future<void> pickReturnDate() async {
                final picked = await showDatePicker(
                  context: dialogContext,
                  initialDate: returnDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setDialogState(() => returnDate = picked);
                }
              }

              Future<void> pickExpiryDate() async {
                final picked = await showDatePicker(
                  context: dialogContext,
                  initialDate: expiryDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(DateTime.now().year + 30),
                );
                if (picked != null) {
                  setDialogState(() => expiryDate = picked);
                }
              }

              return AlertDialog(
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 24,
                ),
                title: Text('Return ${item.medicineName}'),
                content: SizedBox(
                  width: 520,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Returned Quantity',
                            helperText: 'Max: ${item.remainingQty}',
                          ),
                        ),
                        const SizedBox(height: 12),
                        _dateTile(
                          title: 'Return Date',
                          date: returnDate,
                          onTap: pickReturnDate,
                        ),
                        const SizedBox(height: 8),
                        _dateTile(
                          title: 'Expiry Date',
                          date: expiryDate,
                          onTap: pickExpiryDate,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: noteController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Note',
                            hintText: 'Optional',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final qty = int.tryParse(qtyController.text.trim());
                      if (qty == null || qty <= 0 || qty > item.remainingQty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid quantity'),
                          ),
                        );
                        return;
                      }
                      Navigator.pop(dialogContext, true);
                    },
                    child: const Text('Confirm'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (confirm != true) return null;

      final updated = await MedicineSupplyService.returnMedicineSupplyItem(
        sourceSupplyId,
        item.id!,
        qtyReturned: int.parse(qtyController.text.trim()),
        returnedAt: returnDate,
        expiryDate: expiryDate,
        staffNote: noteController.text,
      );
      if (!mounted) return null;
      _replaceSupply(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medicine returned and batch created'),
          backgroundColor: Colors.green,
        ),
      );
      return updated;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error returning medicine: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      qtyController.dispose();
      noteController.dispose();
    }
    return null;
  }

  Future<MedicineSupply?> _cancelSupplyItem(
    MedicineSupply supply,
    MedicineSupplyItem item,
  ) async {
    final sourceSupplyId = item.supplyId ?? supply.id;
    if (sourceSupplyId == null || item.id == null || !item.canCancel) {
      return null;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel ${item.medicineName}?'),
        content: Text(
          'Cancel this medicine batch and restore ${_itemQuantity(item)} to its original stock?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Medicine'),
          ),
        ],
      ),
    );

    if (confirm != true) return null;

    try {
      final updated = await MedicineSupplyService.cancelMedicineSupplyItem(
        sourceSupplyId,
        item.id!,
      );
      if (!mounted) return null;
      _replaceSupply(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medicine batch cancelled'),
          backgroundColor: Colors.green,
        ),
      );
      return updated;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling supply: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return null;
  }

  void _replaceSupply(MedicineSupply updated) {
    if (!mounted) return;
    var replaced = false;
    setState(() {
      _supplies = _supplies.map((supply) {
        if (supply.id == updated.id) {
          replaced = true;
          return updated;
        }
        return supply;
      }).toList();
      if (!replaced) {
        _supplies = [updated, ..._supplies];
      }
    });
  }

  List<MedicineSupply> _groupSuppliesByPatient(List<MedicineSupply> supplies) {
    final baseByKey = <String, MedicineSupply>{};
    final itemsByKey = <String, List<MedicineSupplyItem>>{};
    final seenItemKeys = <String>{};

    for (final supply in supplies) {
      final key = _supplyPatientIdentityKey(supply) ?? supply.id;
      if (key == null) continue;

      final currentBase = baseByKey[key];
      if (currentBase == null || supply.givenAt.isAfter(currentBase.givenAt)) {
        baseByKey[key] = supply;
      }

      final groupedItems = itemsByKey.putIfAbsent(
        key,
        () => <MedicineSupplyItem>[],
      );
      for (var index = 0; index < supply.items.length; index += 1) {
        final item = supply.items[index];
        final sourceSupplyId = item.supplyId ?? supply.id;
        final itemKey = [
          sourceSupplyId ?? supply.id ?? key,
          item.id ??
              '${item.medicineName}:${item.batchNumber}:${item.qtyGiven}:$index',
        ].join(':');
        if (!seenItemKeys.add(itemKey)) continue;
        groupedItems.add(
          item.copyWith(
            supplyId: sourceSupplyId,
            givenAt: item.givenAt ?? supply.givenAt,
          ),
        );
      }
    }

    final histories = <MedicineSupply>[];
    for (final entry in baseByKey.entries) {
      final items = [...(itemsByKey[entry.key] ?? const <MedicineSupplyItem>[])]
        ..sort(
          (a, b) => (b.givenAt ?? entry.value.givenAt).compareTo(
            a.givenAt ?? entry.value.givenAt,
          ),
        );
      final latestGivenAt = _latestItemDate(items) ?? entry.value.givenAt;
      histories.add(
        entry.value.copyWith(
          givenAt: latestGivenAt,
          medicineId: items.isNotEmpty
              ? items.first.medicineId
              : entry.value.medicineId,
          qtyGiven: items.fold<int>(0, (sum, item) => sum + item.qtyGiven),
          items: items,
          status: _aggregateSupplyItemStatus(items),
        ),
      );
    }

    histories.sort((a, b) => b.givenAt.compareTo(a.givenAt));
    return histories;
  }

  DateTime? _latestItemDate(List<MedicineSupplyItem> items) {
    DateTime? latest;
    for (final item in items) {
      final givenAt = item.givenAt;
      if (givenAt == null) continue;
      if (latest == null || givenAt.isAfter(latest)) latest = givenAt;
    }
    return latest;
  }

  String _aggregateSupplyItemStatus(List<MedicineSupplyItem> items) {
    if (items.isEmpty) return 'given';
    final statuses = items.map((item) => item.status).toList();
    if (statuses.every((status) => status == 'cancelled')) return 'cancelled';
    if (statuses.every((status) => status == 'returned')) return 'returned';
    if (statuses.every((status) => status == 'given')) return 'given';
    return 'partially_given';
  }

  String? _supplyPatientIdentityKey(MedicineSupply supply) {
    final register = supply.patientRegisterId?.trim().toLowerCase();
    if (register != null && register.isNotEmpty) return 'reg:$register';

    final name = _normalizePatientName(supply.patientName);
    final phone = _digitsOnly(supply.patientPhone);
    if (name.isNotEmpty && phone.isNotEmpty) return 'name_phone:$name|$phone';
    if (name.isNotEmpty && name != 'unknown') return 'name:$name';

    final patient = supply.patientId;
    if (patient == null) return null;
    if (patient is String) return 'id:$patient';
    if (patient is Map && patient['_id'] != null) {
      return 'id:${patient['_id']}';
    }
    if (patient is Map && patient['id'] != null) {
      return 'id:${patient['id']}';
    }
    return 'id:$patient';
  }

  String _normalizePatientName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  void _showSupplyDetails(MedicineSupply supply) {
    var currentSupply = supply;
    final auth = context.read<AuthService>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: _screenBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _iconBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          color: _medicineGreen,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentSupply.patientName,
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.black,
                              ),
                            ),
                            if (currentSupply.patientRegisterId
                                    ?.trim()
                                    .isNotEmpty ==
                                true)
                              Text(
                                'Reg No: ${currentSupply.patientRegisterId}',
                                style: const TextStyle(color: _medicineGreen),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildPatientDetails(currentSupply),
                  const SizedBox(height: 20),
                  _buildMedicineListHeader(currentSupply),
                  const SizedBox(height: 12),
                  if (currentSupply.items.isEmpty)
                    Text(
                      currentSupply.medicineSummary,
                      style: TextStyle(color: Colors.grey.shade700),
                    )
                  else
                    ...currentSupply.items.map(
                      (item) => _buildSupplyItemRow(
                        currentSupply,
                        item,
                        auth,
                        (updated) =>
                            setModalState(() => currentSupply = updated),
                      ),
                    ),
                  if (currentSupply.supplyDays != null ||
                      currentSupply.prescribedBy?.trim().isNotEmpty == true ||
                      currentSupply.staffNote?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 12),
                    if (currentSupply.supplyDays != null)
                      _buildDetailRow(
                        'Supply Days',
                        '${currentSupply.supplyDays} Days',
                      ),
                    if (currentSupply.prescribedBy?.trim().isNotEmpty == true)
                      _buildDetailRow(
                        'Prescribed By',
                        currentSupply.prescribedBy!,
                      ),
                    if (currentSupply.staffNote?.trim().isNotEmpty == true)
                      _buildDetailRow('Staff Note', currentSupply.staffNote!),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _medicineGreen,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPatientDetails(MedicineSupply supply) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Patient Details',
            style: TextStyle(
              color: _medicineGreen,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _buildDetailRow('Name', supply.patientName),
          if (supply.patientRegisterId?.trim().isNotEmpty == true)
            _buildDetailRow('Register No', supply.patientRegisterId!),
          _buildDetailRow('Phone', supply.patientPhone),
          _buildDetailRow(
            'Age/Gender',
            [
              if (supply.patientAge > 0) '${supply.patientAge} yrs',
              if (supply.patientGender.trim().isNotEmpty) supply.patientGender,
            ].join(' / '),
          ),
          _buildDetailRow(
            'Address',
            [
              supply.patientAddress,
              supply.patientPlace,
            ].where((value) => value.trim().isNotEmpty).join(', '),
          ),
          _buildDetailRow('Diagnosis', supply.patientDiseases.join(', ')),
        ],
      ),
    );
  }

  Widget _buildMedicineListHeader(MedicineSupply supply) {
    final count = supply.items.length;
    final subtitle = '$count ${count == 1 ? 'Medicine' : 'Medicines'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Medicine List',
          style: TextStyle(
            color: _primaryText,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            color: _secondaryText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _itemStatusPill(MedicineSupplyItem item) {
    final color = _itemStatusColor(item);
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        _itemStatusLabel(item).toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _medicineInfoGrid(MedicineSupply supply, MedicineSupplyItem item) {
    final cells = <Widget>[
      _expiryInfoCell(item.expiryDate),
      _infoCell(
        icon: Icons.event_available_outlined,
        label: 'Supply',
        value: _formatDateShort(item.givenAt ?? supply.givenAt),
      ),
      _infoCell(
        icon: Icons.confirmation_number_outlined,
        label: 'Batch',
        value: item.batchNumber,
      ),
      _infoCell(
        icon: Icons.label_outline,
        label: 'Stock',
        value: _itemSourceText(item),
      ),
      if (item.returnedQty > 0)
        _infoCell(
          icon: Icons.assignment_return_outlined,
          label: 'Returned',
          value: _itemQuantity(item, quantity: item.returnedQty),
          valueColor: _warningAmber,
          emphasize: true,
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = (constraints.maxWidth - 6) / 2;
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final cell in cells)
              SizedBox(
                width: cellWidth.clamp(120, 420).toDouble(),
                child: cell,
              ),
          ],
        );
      },
    );
  }

  Widget _infoCell({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool emphasize = false,
    Color? background,
  }) {
    if (value.trim().isEmpty || value == 'null') return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? _screenBg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: valueColor ?? _secondaryText),
          const SizedBox(width: 5),
          Expanded(
            child: Row(
              children: [
                Text(
                  '$label ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _secondaryText,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: valueColor ?? _primaryText,
                      fontSize: 11.5,
                      fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _expiryInfoCell(DateTime? expiry) {
    final state = _expiryState(expiry);
    final color = switch (state) {
      _ExpiryState.expired => _dangerRed,
      _ExpiryState.warning => _warningAmber,
      _ => _primaryText,
    };
    final background = switch (state) {
      _ExpiryState.expired => _dangerRed.withValues(alpha: 0.08),
      _ExpiryState.warning => _warningAmber.withValues(alpha: 0.1),
      _ => null,
    };

    return _infoCell(
      icon: Icons.event_outlined,
      label: 'Expiry',
      value: expiry == null ? 'Not recorded' : _formatDateShort(expiry),
      valueColor: color,
      emphasize: state != _ExpiryState.normal,
      background: background,
    );
  }

  Widget _buildDetailRow(String label, String value) {
    if (value.trim().isEmpty || value == 'null') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplyItemRow(
    MedicineSupply supply,
    MedicineSupplyItem item,
    AuthService auth,
    ValueChanged<MedicineSupply> onUpdated,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.028),
            blurRadius: 9,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.medication_liquid_outlined,
                  color: _medicineGreen,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.medicineName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (item.medicineCode.trim().isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        item.medicineCode,
                        style: const TextStyle(
                          color: _secondaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.end,
                children: [
                  Text(
                    _itemQuantity(item),
                    style: const TextStyle(
                      color: _primaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  _itemStatusPill(item),
                  if (auth.canEdit && item.canReturn)
                    Tooltip(
                      message: 'Return',
                      child: SizedBox.square(
                        dimension: 30,
                        child: IconButton.filled(
                          onPressed: () async {
                            final updated = await _returnSupplyItem(
                              supply,
                              item,
                            );
                            if (updated != null) onUpdated(updated);
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: _medicineGreen,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.square(30),
                            fixedSize: const Size.square(30),
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(
                            Icons.assignment_return_outlined,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  if (auth.canEdit && item.canCancel)
                    Tooltip(
                      message: 'Cancel',
                      child: SizedBox.square(
                        dimension: 30,
                        child: IconButton(
                          onPressed: () async {
                            final updated = await _cancelSupplyItem(
                              supply,
                              item,
                            );
                            if (updated != null) onUpdated(updated);
                          },
                          style: IconButton.styleFrom(
                            foregroundColor: _dangerRed,
                            minimumSize: const Size.square(30),
                            fixedSize: const Size.square(30),
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.cancel_outlined, size: 19),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          _medicineInfoGrid(supply, item),
        ],
      ),
    );
  }

  String _itemQuantity(MedicineSupplyItem item, {int? quantity}) {
    final unit = item.qtyUnit.trim();
    final value = quantity ?? item.qtyGiven;
    return unit.isEmpty ? '$value' : '$value $unit';
  }

  String _formatDate(DateTime value) {
    return '${value.day}/${value.month}/${value.year}';
  }

  String _formatDateShort(DateTime value) {
    return '${value.day} ${_monthLabel(value.month)} ${value.year}';
  }

  String _monthLabel(int month) {
    return switch (month) {
      1 => 'Jan',
      2 => 'Feb',
      3 => 'Mar',
      4 => 'Apr',
      5 => 'May',
      6 => 'Jun',
      7 => 'Jul',
      8 => 'Aug',
      9 => 'Sep',
      10 => 'Oct',
      11 => 'Nov',
      12 => 'Dec',
      _ => '',
    };
  }

  _ExpiryState _expiryState(DateTime? expiry) {
    if (expiry == null) return _ExpiryState.normal;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDay = DateTime(expiry.year, expiry.month, expiry.day);
    if (expiryDay.isBefore(today)) return _ExpiryState.expired;
    if (!expiryDay.isAfter(today.add(const Duration(days: 30)))) {
      return _ExpiryState.warning;
    }
    return _ExpiryState.normal;
  }

  String _statusLabel(String status) {
    return switch (status.toLowerCase()) {
      'returned' => 'Returned',
      'cancelled' => 'Cancelled',
      'partially_given' => 'Partially Given',
      _ => 'Given',
    };
  }

  Color _statusColor(String status) {
    return switch (status.toLowerCase()) {
      'returned' => _warningAmber,
      'cancelled' => _dangerRed,
      'partially_given' => _warningAmber,
      _ => _successGreen,
    };
  }

  String _itemStatusLabel(MedicineSupplyItem item) {
    if (item.status == 'partially_given') return 'Partial';
    return _statusLabel(item.status);
  }

  Color _itemStatusColor(MedicineSupplyItem item) {
    return _statusColor(item.status);
  }

  String _itemSourceText(MedicineSupplyItem item) {
    final label = item.sourceLabel.trim().isEmpty
        ? 'Main Stock'
        : item.sourceLabel.trim();
    final patientName = item.sourcePatientName?.trim();
    final registerId = item.sourcePatientRegisterId?.trim();
    if (label.toLowerCase() == 'return' &&
        patientName != null &&
        patientName.isNotEmpty) {
      final patientText = registerId != null && registerId.isNotEmpty
          ? '$patientName ($registerId)'
          : patientName;
      return '$label • $patientText';
    }
    return label;
  }

  Widget _dateTile({
    required String title,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: Colors.grey.shade100,
      title: Text(title),
      subtitle: Text('${date.day}/${date.month}/${date.year}'),
      trailing: const Icon(Icons.calendar_today),
      onTap: onTap,
    );
  }

  Widget _buildSupplyCard(MedicineSupply supply) {
    Widget cardContent = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showSupplyDetails(supply),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Icon(
                              Icons.person_outline,
                              color: _medicineGreen,
                              size: 18,
                            ),
                            Text(
                              _formatDate(supply.givenAt),
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          supply.patientName.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF2D3142),
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (supply.patientRegisterId?.trim().isNotEmpty ==
                            true) ...[
                          const SizedBox(height: 3),
                          Text(
                            'Reg No: ${supply.patientRegisterId}',
                            style: const TextStyle(
                              color: _medicineGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          supply.medicineSummary,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 14,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Supplied: ${supply.qtyGiven}',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            if (supply.supplyDays != null) ...[
                              Icon(
                                Icons.calendar_month,
                                size: 14,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${supply.supplyDays} Days',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
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
      ),
    );

    return cardContent;
  }
}
