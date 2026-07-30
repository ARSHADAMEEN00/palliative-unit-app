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

const _medicineGreen = Color(0xFF0F6E56);
const _cardBg = Color(0xFFE1F5EE);
const _iconBg = Color(0xFF9FE1CB);

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

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final list = await MedicineSupplyService.getAllMedicineSupplies();
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
        backgroundColor: _cardBg,
        surfaceTintColor: _cardBg,
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
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
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

    final filteredList = _supplies.where(_matchesSearch).toList();

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
      onRefresh: () => _loadData(showLoading: false),
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
    if (supply.id == null || item.id == null || !item.canReturn) return null;

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
        supply.id!,
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
    if (supply.id == null || item.id == null || !item.canCancel) return null;

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
        supply.id!,
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
    setState(() {
      _supplies = _supplies
          .map((supply) => supply.id == updated.id ? updated : supply)
          .toList();
    });
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
              color: Colors.white,
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
                  const Text(
                    'Medicine List',
                    style: TextStyle(fontSize: 16, color: _medicineGreen),
                  ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
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

  Widget _itemStatusPill(MedicineSupplyItem item) {
    final color = _itemStatusColor(item);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        _itemStatusLabel(item),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    if (label.trim().isEmpty || label == 'null') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(99),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: _medicineGreen),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _medicineGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
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
    final expiry = item.expiryDate;
    final statusColor = _itemStatusColor(item);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: statusColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.medicineName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (item.medicineCode.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.medicineCode,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _itemStatusPill(item),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _infoChip(Icons.confirmation_number_outlined, item.batchNumber),
              _infoChip(
                Icons.event_available_outlined,
                'Supply ${_formatDate(supply.givenAt)}',
              ),
              _infoChip(Icons.label_outline, _itemSourceText(item)),
              _infoChip(
                Icons.event_outlined,
                'Exp ${expiry == null ? 'Not recorded' : _formatDate(expiry)}',
              ),
              _infoChip(
                Icons.inventory_2_outlined,
                'Supplied ${_itemQuantity(item)}',
              ),
              if (item.returnedQty > 0)
                _infoChip(
                  Icons.assignment_return_outlined,
                  'Returned ${_itemQuantity(item, quantity: item.returnedQty)}',
                ),
            ],
          ),
          if (auth.canEdit && (item.canReturn || item.canCancel)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (item.canReturn)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final updated = await _returnSupplyItem(supply, item);
                      if (updated != null) onUpdated(updated);
                    },
                    icon: const Icon(
                      Icons.assignment_return_outlined,
                      size: 17,
                    ),
                    label: const Text('Return'),
                  ),
                if (item.canReturn && item.canCancel) const SizedBox(width: 8),
                if (item.canCancel)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final updated = await _cancelSupplyItem(supply, item);
                      if (updated != null) onUpdated(updated);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 17),
                    label: const Text('Cancel'),
                  ),
              ],
            ),
          ],
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
      'returned' => Colors.orange.shade800,
      'cancelled' => Colors.red.shade700,
      'partially_given' => Colors.blueGrey.shade700,
      _ => _medicineGreen,
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
