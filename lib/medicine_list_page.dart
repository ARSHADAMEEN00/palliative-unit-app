import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:oruma_app/core/theme/app_typography.dart';
import 'package:oruma_app/medicine_stock_entry_page.dart';
import 'package:oruma_app/medicine_stock_history_page.dart';
import 'package:oruma_app/medicine_supply_list_page.dart';
import 'package:oruma_app/models/medicine.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/services/feature_permissions.dart';
import 'package:oruma_app/services/medicine_service.dart';
import 'package:oruma_app/services/medicine_stock_service.dart';
import 'package:provider/provider.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';
import 'package:oruma_app/widgets/compact_app_bottom_bar.dart';
import 'package:oruma_app/widgets/app_bottom_nav_router.dart';
import 'package:oruma_app/widgets/feature_permission_gate.dart';
import 'package:oruma_app/widgets/module_switch_tabs.dart';
import 'package:oruma_app/widgets/reveal_action_fab.dart';

const _medicineGreen = Color(0xFF0F6E56);
const _medicineDarkGreen = Color(0xFF0F6E56);
const _medicineSurface = Color(0xFFE1F5EE);
const _medicineIconBackground = Color(0xFF9FE1CB);

Uint8List? _photoDataBytes(String value) {
  if (!value.startsWith('data:image/')) return null;
  final commaIndex = value.indexOf(',');
  if (commaIndex == -1) return null;
  try {
    return base64Decode(value.substring(commaIndex + 1));
  } catch (_) {
    return null;
  }
}

bool _isRemotePhoto(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}

class MedicineListPage extends StatefulWidget {
  const MedicineListPage({super.key});

  @override
  State<MedicineListPage> createState() => _MedicineListPageState();
}

class _MedicineListPageState extends State<MedicineListPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<Medicine> _medicines = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearch);
    _loadMedicines();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _loadMedicines(showLoader: false),
    );
    setState(() {});
  }

  Future<void> _loadMedicines({bool showLoader = true}) async {
    final search = _searchController.text.trim();
    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final medicines = await MedicineService.getMedicines(
        search: search.isEmpty ? null : search,
      );
      if (!mounted || search != _searchController.text.trim()) return;
      setState(() {
        _medicines = medicines;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || search != _searchController.text.trim()) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  Future<void> _openForm([Medicine? medicine]) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => MedicineFormPage(medicine: medicine),
      ),
    );
    if (result == true) {
      await _loadMedicines();
    }
  }

  Future<void> _openStockEntry() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const MedicineStockEntryPage()),
    );
    if (result == true) {
      await _loadMedicines();
    }
  }

  Future<void> _openStockHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MedicineStockHistoryPage()),
    );
  }

  Future<void> _deleteMedicine(Medicine medicine) async {
    if (medicine.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete medicine?'),
        content: Text(
          'Delete ${medicine.name} (${medicine.code}) from inventory?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await MedicineService.deleteMedicine(medicine.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Medicine deleted')));
      await _loadMedicines();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    }
  }

  void _showDetails(Medicine medicine) {
    final availableBatches = _availableBatches(medicine);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        maxChildSize: 0.94,
        minChildSize: 0.5,
        builder: (context, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _medicineIcon(medicine, size: 58),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medicine.name,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          medicine.code,
                          style: const TextStyle(
                            color: _medicineDarkGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _stockPill(medicine),
                ],
              ),
              const SizedBox(height: 22),
              _detailCard([
                _detailRow(
                  Icons.science_outlined,
                  'Dosage',
                  _strengthText(medicine),
                ),
                _detailRow(
                  Icons.inventory_2_outlined,
                  'Stock',
                  _stockText(medicine),
                ),
                _detailRow(
                  Icons.local_drink_outlined,
                  'Net Content',
                  _displayValue(medicine.netContent),
                ),
                _detailRow(
                  Icons.category_outlined,
                  'Category',
                  _titleCase(medicine.category),
                ),
                _detailRow(
                  Icons.medication_outlined,
                  'Formulation',
                  _displayValue(medicine.formulation),
                ),
                _detailRow(
                  Icons.qr_code_2_outlined,
                  'Barcode',
                  _displayValue(medicine.barcode),
                ),
                _detailRow(
                  Icons.local_offer_outlined,
                  'Brand names',
                  medicine.brandNames.isEmpty
                      ? 'Not recorded'
                      : medicine.brandNames.join(', '),
                ),
                if (medicine.description?.trim().isNotEmpty == true)
                  _detailRow(
                    Icons.notes_outlined,
                    'Description',
                    medicine.description!,
                  ),
                _detailRow(
                  Icons.person_outline,
                  'Created by',
                  medicine.createdBy?.name ?? 'Not recorded',
                ),
              ]),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Batches',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${availableBatches.length}',
                    style: const TextStyle(
                      color: _medicineDarkGreen,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (availableBatches.isEmpty)
                _emptyBatchesCard()
              else
                ...availableBatches.map((b) => _batchCard(b, medicine)),
              if (medicine.photos.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text(
                  'Photo references',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                ...medicine.photos.asMap().entries.map(
                  (entry) => _photoReferenceTile(entry.value, entry.key),
                ),
              ],
              if (context.read<AuthService>().canEdit) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _openForm(medicine);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _medicineGreen,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit medicine'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoReferenceTile(String photo, int index) {
    final dataBytes = _photoDataBytes(photo);
    final isImage = dataBytes != null || _isRemotePhoto(photo);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _medicineSurface,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: SizedBox(
              width: 52,
              height: 52,
              child: dataBytes != null
                  ? Image.memory(dataBytes, fit: BoxFit.cover)
                  : _isRemotePhoto(photo)
                  ? Image.network(
                      photo,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image_outlined,
                        color: _medicineDarkGreen,
                      ),
                    )
                  : const Icon(Icons.image_outlined, color: _medicineDarkGreen),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isImage ? 'Photo ${index + 1}' : photo,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyBatchesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        'No stock batches added yet',
        style: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _batchCard(MedicineBatch batch, Medicine medicine) {
    final isEmpty = batch.isEmpty;
    final expiryWarning = !isEmpty && batch.expiresWithin60Days;
    final color = isEmpty
        ? Colors.grey.shade600
        : expiryWarning
        ? Colors.red.shade700
        : _medicineGreen;
    final background = isEmpty
        ? Colors.grey.shade100
        : expiryWarning
        ? Colors.red.shade50
        : _medicineSurface;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEmpty
              ? Colors.grey.shade300
              : expiryWarning
              ? Colors.red.shade300
              : _medicineIconBackground,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _displayValue(batch.batchNumber),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
              ),
              _batchQtyPill(batch, color),
              if (!isEmpty) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.assignment_return_outlined, size: 20),
                  color: color,
                  tooltip: 'Return to main stock',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _returnToMainStock(medicine, batch),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _batchChip(
                Icons.event_outlined,
                'Exp ${_formatDate(batch.expiryDate)}',
                color,
              ),
              _batchChip(
                Icons.playlist_add_check_outlined,
                'Received ${_number(batch.originalQuantity)} ${_stockUnitLabel(batch.qtyUnit)}',
                color,
              ),
              _batchChip(Icons.label_outline, _batchSourceText(batch), color),
              if (batch.entryDate != null)
                _batchChip(
                  Icons.login_outlined,
                  'Entry ${_formatDate(batch.entryDate)}',
                  color,
                ),
            ],
          ),
          if (batch.note?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              batch.note!.trim(),
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _batchQtyPill(MedicineBatch batch, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        '${_number(batch.quantity)} ${_stockUnitLabel(batch.qtyUnit)}',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _batchChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _returnToMainStock(Medicine medicine, MedicineBatch batch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Return to Main Stock?'),
        content: Text(
          'Return this batch to main stock?\n\n'
          'Batch: ${batch.batchNumber ?? 'N/A'}\n'
          'Quantity: ${_number(batch.quantity)} ${_stockUnitLabel(batch.qtyUnit)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Return'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      if (batch.id == null) {
        throw Exception('Batch ID is missing');
      }

      await MedicineStockService.returnBatchToMainStock(
        batch.id!,
        qtyReturned: batch.quantity,
        note: 'Returned due to expire or other reason',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Batch returned to main stock')),
      );

      Navigator.pop(context); // Close bottom sheet
      _loadMedicines();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    void handleBottomNavigation(AppBottomSection section) {
      AppBottomNavRouter.handle(
        context,
        current: AppBottomSection.medicine,
        target: section,
      );
    }

    return AdaptiveAppScaffold(
      backgroundColor: const Color(0xFFF5FAF8),
      appBar: AppBar(
        foregroundColor: _medicineDarkGreen,
        backgroundColor: _medicineSurface,
        surfaceTintColor: _medicineSurface,
        title: ModuleSwitchTabs(
          labels: const ['Supplies', 'Medicines'],
          icons: const [
            Icons.assignment_turned_in_outlined,
            Icons.medication_liquid_outlined,
          ],
          selectedIndex: 1,
          color: _medicineDarkGreen,
          onSelected: (index) {
            if (index == 0) {
              if (!FeaturePermissionMiddleware.ensure(
                context,
                AppFeature.medicineSupply,
                moduleName: 'Medicine Supply',
              )) {
                return;
              }
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const MedicineSupplyListPage(),
                ),
              );
            }
          },
        ),
        centerTitle: true,
        actions: [
          if (auth.canAccessMedicineStock)
            IconButton(
              tooltip: 'Stock history',
              onPressed: _openStockHistory,
              icon: const Icon(Icons.history_outlined),
            ),
          if (auth.canCreate && auth.canAccessMedicineMaster)
            IconButton(
              tooltip: 'Add medicine',
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_circle_outline),
            ),
        ],
      ),
      floatingActionButton: auth.canCreate && auth.canAccessMedicineStock
          ? RevealActionFab(
              onPressed: _openStockEntry,
              backgroundColor: _medicineGreen,
              foregroundColor: Colors.white,
              icon: Icons.add_box_outlined,
              label: 'Add Stock',
            )
          : null,
      currentSection: AppBottomSection.medicine,
      onNavigationSelected: handleBottomNavigation,
      contentMaxWidth: 820,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search code, barcode, name or brand',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.close),
                      ),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: _medicineGreen,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: _buildContent(auth)),
        ],
      ),
    );
  }

  Widget _buildContent(AuthService auth) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _medicineGreen),
      );
    }
    if (_error != null) {
      return _messageState(
        Icons.cloud_off_outlined,
        'Could not load medicines',
        _error!,
        action: OutlinedButton.icon(
          onPressed: _loadMedicines,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );
    }
    if (_medicines.isEmpty) {
      return _messageState(
        Icons.medication_outlined,
        _searchController.text.isEmpty
            ? 'No medicines added'
            : 'No medicines found',
        _searchController.text.isEmpty
            ? 'Create the first medicine inventory record.'
            : 'Try another code, name, brand or barcode.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMedicines,
      color: _medicineGreen,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
        itemCount: _medicines.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final medicine = _medicines[index];
          final expiryWarning = _hasExpiryWarning(medicine);
          return InkWell(
            onTap: () => _showDetails(medicine),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: expiryWarning ? Colors.red.shade400 : Colors.white,
                  width: expiryWarning ? 1.6 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (expiryWarning ? Colors.red : _medicineDarkGreen)
                        .withValues(alpha: 0.07),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _medicineIcon(medicine),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _medicineListTitle(medicine),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            medicine.code,
                            if (medicine.formulation?.isNotEmpty == true)
                              _titleCase(medicine.formulation!),
                          ].join(' • '),
                          style: const TextStyle(
                            color: _medicineDarkGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 10,
                          runSpacing: 5,
                          children: [
                            _inlineDetail(
                              Icons.science_outlined,
                              _strengthText(medicine),
                            ),
                            if (medicine.earliestExpiryDate != null)
                              _inlineDetail(
                                Icons.event_outlined,
                                DateFormat('MMM yyyy').format(
                                  medicine.earliestExpiryDate!.toLocal(),
                                ),
                                color: expiryWarning
                                    ? Colors.red.shade700
                                    : null,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 126,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _stockPill(medicine),
                            const SizedBox(width: 4),
                            _medicineMenu(auth, medicine),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: _stockHighlight(medicine),
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
  }

  Widget _medicineMenu(AuthService auth, Medicine medicine) {
    if (auth.canEdit || auth.canDelete) {
      return SizedBox(
        width: 34,
        height: 34,
        child: PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.more_horiz, size: 22),
          onSelected: (value) {
            if (value == 'edit') _openForm(medicine);
            if (value == 'delete') _deleteMedicine(medicine);
          },
          itemBuilder: (context) => [
            if (auth.canEdit)
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
            if (auth.canDelete)
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
          ],
        ),
      );
    }
    return const SizedBox(
      width: 34,
      height: 34,
      child: Icon(Icons.chevron_right, color: Colors.grey),
    );
  }

  Widget _medicineIcon(Medicine medicine, {double size = 52}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: medicine.isActive
            ? _medicineIconBackground
            : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(
        Icons.medication_liquid_outlined,
        color: medicine.isActive ? _medicineGreen : Colors.grey,
        size: size * 0.5,
      ),
    );
  }

  Widget _stockPill(Medicine medicine) {
    final noStock = medicine.qty <= 0;
    final lowStock = medicine.qty > 0 && medicine.qty <= 10;
    final expiryWarning = _hasExpiryWarning(medicine);
    final color = noStock
        ? Colors.grey
        : expiryWarning
        ? Colors.red
        : lowStock
        ? Colors.red
        : _medicineGreen;
    final label = noStock
        ? 'No stock'
        : expiryWarning
        ? 'Expiring'
        : lowStock
        ? 'Low stock'
        : 'In stock';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _inlineDetail(IconData icon, String text, {Color? color}) {
    final detailColor = color ?? Colors.grey.shade600;
    final iconColor = color ?? Colors.grey.shade500;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: detailColor, fontSize: 11)),
      ],
    );
  }

  Widget _stockHighlight(Medicine medicine) {
    final noStock = medicine.qty <= 0;
    final lowStock = medicine.qty > 0 && medicine.qty <= 10;
    final color = noStock
        ? Colors.grey.shade700
        : lowStock
        ? Colors.red.shade700
        : _medicineGreen;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            'Stock ${_stockText(medicine)}',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageState(
    IconData icon,
    String title,
    String message, {
    Widget? action,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(30),
      children: [
        const SizedBox(height: 80),
        Icon(icon, size: 52, color: _medicineGreen),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
        if (action != null) ...[
          const SizedBox(height: 16),
          Center(child: action),
        ],
      ],
    );
  }

  Widget _detailCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: children.expand((child) sync* {
          yield child;
          if (child != children.last) yield const SizedBox(height: 14);
        }).toList(),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _medicineGreen, size: 20),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _strengthText(Medicine medicine) {
    if (medicine.strength == null) return 'Strength not set';
    return '${_number(medicine.strength!)} ${medicine.strengthUnit ?? ''}'
        .trim();
  }

  String _stockText(Medicine medicine) {
    return '${_number(medicine.qty)} ${_stockUnitLabel(medicine.qtyUnit)}'
        .trim();
  }

  String _medicineListTitle(Medicine medicine) {
    final netContent = _netContentLabel(medicine.netContent);
    if (netContent == null) return medicine.name;
    return '${medicine.name} $netContent';
  }

  String? _netContentLabel(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.replaceFirstMapped(
      RegExp(r'^(\d+(?:\.\d+)?)([A-Za-z]+)$'),
      (match) => '${match[1]} ${match[2]}',
    );
  }

  String _stockUnitLabel(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'tab' => 'Tab',
      'bottle' => 'Bottle',
      'gel' => 'Gel',
      'piece' => 'Piece',
      null || '' => 'units',
      _ => value!.trim(),
    };
  }

  bool _hasExpiryWarning(Medicine medicine) {
    if (medicine.expiringBatchCount > 0) return true;
    return medicine.batches.any(
      (batch) => batch.quantity > 0 && batch.expiresWithin60Days,
    );
  }

  List<MedicineBatch> _availableBatches(Medicine medicine) {
    return medicine.batches
        .where((batch) => !batch.isEmpty)
        .toList(growable: false);
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Not recorded';
    return DateFormat('dd MMM yyyy').format(value.toLocal());
  }

  String _number(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  String _displayValue(String? value) {
    return value?.trim().isNotEmpty == true ? value!.trim() : 'Not recorded';
  }

  String _batchSourceText(MedicineBatch batch) {
    final label = batch.sourceLabel.trim().isEmpty
        ? 'Main Stock'
        : batch.sourceLabel.trim();
    final patientName = batch.sourcePatientName?.trim();
    final registerId = batch.sourcePatientRegisterId?.trim();
    if (batch.sourceType == 'return' &&
        patientName != null &&
        patientName.isNotEmpty) {
      final patientText = registerId != null && registerId.isNotEmpty
          ? '$patientName ($registerId)'
          : patientName;
      return '$label • $patientText';
    }
    return label;
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
  }

  String _friendlyError(Object error) {
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }
}

class MedicineFormPage extends StatefulWidget {
  final Medicine? medicine;

  const MedicineFormPage({super.key, this.medicine});

  @override
  State<MedicineFormPage> createState() => _MedicineFormPageState();
}

class _MedicineFormPageState extends State<MedicineFormPage> {
  static final RegExp _medicineCodePattern = RegExp(r'^MED-(\d+)$');
  static const categories = [
    'opioid',
    'nsaid',
    'antiemetic',
    'anxiolytic',
    'corticosteroid',
    'laxative',
    'other',
  ];
  static const formulations = [
    'tablet',
    'capsule',
    'syrup',
    'injection',
    'patch',
    'suppository',
    'drops',
  ];
  static const strengthUnits = ['mg', 'mcg', 'g', 'IU', 'mEq', '%'];
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _strengthController;
  late final TextEditingController _netContentController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _brandController;
  late final TextEditingController _descriptionController;

  String _category = 'other';
  String? _formulation;
  String? _strengthUnit = 'mg';
  bool _isActive = true;
  bool _showMore = false;
  bool _saving = false;
  bool _loadingCode = false;
  bool _batchesChanged = false;
  String? _savingBatchId;
  List<Medicine> _existingMedicines = [];
  List<MedicineBatch> _batches = [];
  List<String> _photos = [];

  bool get _editing => widget.medicine != null;
  bool get _hasDuplicateCode {
    if (!_editing) return false;
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return false;
    return _existingMedicines.any(
      (medicine) =>
          medicine.id != widget.medicine?.id &&
          medicine.code.trim().toUpperCase() == code,
    );
  }

  bool get _hasDuplicateName {
    final name = _nameController.text.trim().toLowerCase();
    if (name.isEmpty) return false;
    return _existingMedicines.any(
      (medicine) =>
          medicine.id != widget.medicine?.id &&
          medicine.name.trim().toLowerCase() == name,
    );
  }

  @override
  void initState() {
    super.initState();
    final medicine = widget.medicine;
    _codeController = TextEditingController(text: medicine?.code);
    _nameController = TextEditingController(text: medicine?.name);
    _strengthController = TextEditingController(
      text: medicine?.strength == null ? '' : _number(medicine!.strength!),
    );
    _netContentController = TextEditingController(text: medicine?.netContent);
    _barcodeController = TextEditingController(text: medicine?.barcode);
    _brandController = TextEditingController(
      text: medicine?.brandNames.join(', '),
    );
    _descriptionController = TextEditingController(text: medicine?.description);
    _photos = List<String>.from(medicine?.photos ?? const []);
    _batches = List<MedicineBatch>.from(medicine?.batches ?? const []);
    _category = medicine?.category ?? 'other';
    _formulation = medicine?.formulation;
    _strengthUnit = medicine?.strengthUnit ?? 'mg';
    _isActive = medicine?.isActive ?? true;
    _showMore = false;
    _codeController.addListener(_refreshDuplicateHints);
    _nameController.addListener(_refreshDuplicateHints);
    _loadExistingMedicines();
    if (!_editing) {
      _loadNextMedicineCode();
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _codeController,
      _nameController,
      _strengthController,
      _netContentController,
      _barcodeController,
      _brandController,
      _descriptionController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExistingMedicines() async {
    try {
      final medicines = await MedicineService.getMedicines();
      if (!mounted) return;
      if (!_editing && _codeController.text.trim().isEmpty) {
        _codeController.text = _nextMedicineCodeFrom(medicines);
      }
      setState(() => _existingMedicines = medicines);
    } catch (_) {
      // Duplicate checks still run on the server if this lookup is unavailable.
    }
  }

  Future<void> _loadNextMedicineCode() async {
    setState(() => _loadingCode = true);
    try {
      final code = await MedicineService.getNextMedicineCode();
      if (!mounted) return;
      _codeController.text = code;
      setState(() => _loadingCode = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCode = false);
    }
  }

  void _refreshDuplicateHints() {
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final medicine = Medicine(
      id: widget.medicine?.id,
      code: _codeController.text.trim(),
      name: _nameController.text.trim(),
      strength: double.tryParse(_strengthController.text.trim()),
      strengthUnit: _strengthController.text.trim().isEmpty
          ? null
          : _strengthUnit,
      netContent: _emptyToNull(_netContentController.text),
      barcode: _emptyToNull(_barcodeController.text),
      brandNames: _splitValues(_brandController.text, RegExp(r'[,;\n]')),
      category: _category,
      formulation: _formulation,
      description: _emptyToNull(_descriptionController.text),
      photos: _photos,
      isActive: _isActive,
    );

    try {
      if (_editing) {
        await MedicineService.updateMedicine(widget.medicine!.id!, medicine);
      } else {
        await MedicineService.createMedicine(medicine);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editing ? 'Medicine updated' : 'Medicine created'),
          backgroundColor: _medicineDarkGreen,
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickPhotoReference(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 72,
        maxWidth: 1200,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final mimeType = picked.mimeType?.trim().isNotEmpty == true
          ? picked.mimeType!
          : 'image/jpeg';
      final encoded = 'data:$mimeType;base64,${base64Encode(bytes)}';

      if (!mounted) return;
      setState(() => _photos = [..._photos, encoded]);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not add photo: ${error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '')}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _photoPickerField() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.photo_library_outlined,
                color: _medicineGreen,
                size: 20,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Photo references',
                  style: TextStyle(fontSize: 15, color: Colors.black87),
                ),
              ),
              Text(
                '${_photos.length}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickPhotoReference(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickPhotoReference(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
          if (_photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _photos.asMap().entries.map((entry) {
                return _photoPreview(entry.value, entry.key);
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _photoPreview(String photo, int index) {
    final dataBytes = _photoDataBytes(photo);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 84,
            height: 84,
            color: _medicineSurface,
            child: dataBytes != null
                ? Image.memory(dataBytes, fit: BoxFit.cover)
                : _isRemotePhoto(photo)
                ? Image.network(
                    photo,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined),
                  )
                : const Icon(Icons.image_outlined, color: _medicineGreen),
          ),
        ),
        Positioned(
          right: -8,
          top: -8,
          child: IconButton.filled(
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              minimumSize: const Size(28, 28),
            ),
            onPressed: () {
              setState(() {
                _photos = [..._photos.take(index), ..._photos.skip(index + 1)];
              });
            },
            icon: const Icon(Icons.close, size: 15),
          ),
        ),
      ],
    );
  }

  Widget _batchesSection() {
    return _formCard(
      title: 'Batches',
      subtitle: _batches.isEmpty
          ? 'No stock batches added yet.'
          : '${_batches.length} stock batches recorded.',
      icon: Icons.inventory_2_outlined,
      children: _batches.isEmpty
          ? [_emptyEditableBatchesCard()]
          : _batches.map(_editableBatchCard).toList(),
    );
  }

  Widget _emptyEditableBatchesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        'Add stock entries to create batches for this medicine.',
        style: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _editableBatchCard(MedicineBatch batch) {
    final batchId = batch.id;
    final isEmpty = batch.isEmpty;
    final expiryWarning = !isEmpty && batch.expiresWithin60Days;
    final color = isEmpty
        ? Colors.grey.shade600
        : expiryWarning
        ? Colors.red.shade700
        : _medicineGreen;
    final background = isEmpty
        ? Colors.grey.shade100
        : expiryWarning
        ? Colors.red.shade50
        : _medicineSurface;
    final saving = batchId != null && _savingBatchId == batchId;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEmpty
              ? Colors.grey.shade300
              : expiryWarning
              ? Colors.red.shade300
              : _medicineIconBackground,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _displayValue(batch.batchNumber),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
              ),
              _editableBatchQtyPill(batch, color),
              const SizedBox(width: 6),
              if (saving)
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  ),
                )
              else
                IconButton(
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    foregroundColor: Colors.grey.shade600,
                    disabledBackgroundColor: Colors.grey.shade50,
                    disabledForegroundColor: Colors.grey.shade400,
                    minimumSize: const Size(36, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: batchId == null
                      ? null
                      : () => _showBatchEditor(batch),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: batchId == null
                      ? 'Legacy batch cannot be edited'
                      : 'Edit batch',
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _editableBatchChip(
                Icons.event_outlined,
                'Exp ${_formatDate(batch.expiryDate)}',
                color,
              ),
              _editableBatchChip(
                Icons.playlist_add_check_outlined,
                'Received ${_number(batch.originalQuantity)} ${_stockUnitLabel(batch.qtyUnit)}',
                color,
              ),
              _editableBatchChip(
                Icons.label_outline,
                _batchSourceText(batch),
                color,
              ),
              if (batch.entryDate != null)
                _editableBatchChip(
                  Icons.login_outlined,
                  'Entry ${_formatDate(batch.entryDate)}',
                  color,
                ),
              if (batch.updatedAt != null)
                _editableBatchChip(
                  Icons.update_outlined,
                  'Updated ${_formatDate(batch.updatedAt)}',
                  color,
                ),
            ],
          ),
          if (batch.note?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              batch.note!.trim(),
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _editableBatchQtyPill(MedicineBatch batch, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        '${_number(batch.quantity)} ${_stockUnitLabel(batch.qtyUnit)}',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _editableBatchChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBatchEditor(MedicineBatch batch) async {
    final batchId = batch.id;
    if (batchId == null) return;

    final quantityController = TextEditingController(
      text: _number(batch.quantity),
    );
    DateTime? expiryDate = batch.expiryDate;
    var saving = false;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        showDragHandle: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (sheetContext, setModalState) {
              Future<void> pickExpiryDate() async {
                final today = DateTime.now();
                final picked = await showDatePicker(
                  context: sheetContext,
                  initialDate: expiryDate ?? today,
                  firstDate: DateTime(today.year - 10),
                  lastDate: DateTime(today.year + 30),
                );
                if (picked != null) {
                  setModalState(() => expiryDate = picked);
                }
              }

              Future<void> saveBatch() async {
                final quantity = double.tryParse(
                  quantityController.text.trim(),
                );
                final selectedExpiry = expiryDate;
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);

                if (quantity == null || quantity < 0) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid quantity'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (selectedExpiry == null) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Choose an expiry date'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setModalState(() => saving = true);
                setState(() => _savingBatchId = batchId);

                try {
                  await MedicineStockService.updateStockEntry(
                    batchId,
                    quantity: quantity,
                    expiryDate: selectedExpiry,
                  );
                  final medicineId = widget.medicine?.id;
                  if (medicineId != null) {
                    final refreshed = await MedicineService.getMedicineById(
                      medicineId,
                    );
                    if (!mounted) return;
                    setState(() {
                      _batches = refreshed.batches;
                      _batchesChanged = true;
                    });
                  }
                  if (!mounted) return;
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Batch updated'),
                      backgroundColor: _medicineDarkGreen,
                    ),
                  );
                } catch (error) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        error.toString().replaceFirst(
                          RegExp(r'^Exception:\s*'),
                          '',
                        ),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  setModalState(() => saving = false);
                } finally {
                  if (mounted) {
                    setState(() => _savingBatchId = null);
                  }
                }
              }

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Edit batch',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: saving
                              ? null
                              : () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _displayValue(batch.batchNumber),
                      style: const TextStyle(
                        color: _medicineDarkGreen,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: quantityController,
                      enabled: !saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _inputDecoration(
                        'Available quantity',
                        Icons.inventory_2_outlined,
                        hint: '0',
                      ).copyWith(suffixText: _stockUnitLabel(batch.qtyUnit)),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: saving ? null : pickExpiryDate,
                      borderRadius: BorderRadius.circular(14),
                      child: InputDecorator(
                        decoration: _inputDecoration(
                          'Expiry date',
                          Icons.event_outlined,
                        ),
                        child: Text(_formatDate(expiryDate)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: saving ? null : saveBatch,
                      style: FilledButton.styleFrom(
                        backgroundColor: _medicineGreen,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      icon: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(saving ? 'Saving' : 'Save batch'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } finally {
      quantityController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveAppScaffold(
      backgroundColor: const Color(0xFFF5FAF8),
      appBar: AppBar(
        backgroundColor: _medicineDarkGreen,
        foregroundColor: Colors.white,
        leading: BackButton(
          color: Colors.white,
          onPressed: () =>
              Navigator.pop(context, _batchesChanged ? true : null),
        ),
        title: Text(
          _editing ? 'Edit Medicine' : 'New Medicine',
          style: const TextStyle(fontSize: 18, color: Colors.white),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
          children: [
            _formIntro(),
            const SizedBox(height: 16),
            _formCard(
              title: 'Essential details',
              subtitle: 'Only the information needed to create a medicine.',
              icon: Icons.medication_outlined,
              children: [
                _textField(
                  _codeController,
                  'Medicine code',
                  hint: _loadingCode ? 'Loading code' : 'MED-001',
                  icon: Icons.tag_outlined,
                  required: _editing,
                  readOnly: true,
                  textCapitalization: TextCapitalization.characters,
                  supportingText: _editing && _hasDuplicateCode
                      ? 'This medicine code already exists'
                      : null,
                  supportingColor: Colors.red.shade700,
                  validator: (_) => _editing && _hasDuplicateCode
                      ? 'Medicine code already exists'
                      : null,
                ),
                _textField(
                  _nameController,
                  'Generic / scientific name',
                  hint: 'Morphine',
                  icon: Icons.medication_liquid_outlined,
                  required: true,
                  supportingText: _hasDuplicateName
                      ? 'This generic name already exists'
                      : null,
                  supportingColor: Colors.red.shade700,
                  validator: (_) =>
                      _hasDuplicateName ? 'Generic name already exists' : null,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _textField(
                        _strengthController,
                        'Dosage strength',
                        hint: '10',
                        icon: Icons.science_outlined,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: _dropdown(
                        label: 'Unit',
                        value: _strengthUnit,
                        values: strengthUnits,
                        onChanged: (value) =>
                            setState(() => _strengthUnit = value),
                      ),
                    ),
                  ],
                ),
                _textField(
                  _netContentController,
                  'Net Content',
                  hint: 'e.g. 250 ml or 250 g',
                  icon: Icons.local_drink_outlined,
                ),
              ],
            ),
            if (_editing) ...[const SizedBox(height: 14), _batchesSection()],
            const SizedBox(height: 14),
            InkWell(
              onTap: () => setState(() => _showMore = !_showMore),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _medicineSurface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tune_outlined, color: _medicineDarkGreen),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'More details',
                            style: TextStyle(
                              fontSize: 15,
                              color: _medicineDarkGreen,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Brand, category, photos, and status',
                            style: TextStyle(
                              color: Color(0xFF5F786F),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _showMore ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _medicineDarkGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: _formCard(
                  title: 'Additional details',
                  subtitle: 'Optional information for safer stock management.',
                  icon: Icons.fact_check_outlined,
                  children: [
                    _textField(
                      _barcodeController,
                      'Barcode',
                      hint: 'Scan or enter barcode number',
                      icon: Icons.qr_code_2_outlined,
                      keyboardType: TextInputType.number,
                    ),
                    _textField(
                      _brandController,
                      'Brand names',
                      hint: 'Separate multiple brands with commas',
                      icon: Icons.local_offer_outlined,
                    ),
                    _dropdown(
                      label: 'Category',
                      value: _category,
                      values: categories,
                      onChanged: (value) =>
                          setState(() => _category = value ?? 'other'),
                    ),
                    _dropdown(
                      label: 'Formulation',
                      value: _formulation,
                      values: formulations,
                      allowEmpty: true,
                      onChanged: (value) =>
                          setState(() => _formulation = value),
                    ),
                    _textField(
                      _descriptionController,
                      'Clinical description',
                      icon: Icons.notes_outlined,
                      maxLines: 3,
                    ),
                    _photoPickerField(),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _isActive,
                      activeThumbColor: _medicineGreen,
                      title: const Text('Active medicine'),
                      subtitle: const Text(
                        'Inactive medicines remain in history but are clearly marked.',
                      ),
                      onChanged: (value) => setState(() => _isActive = value),
                    ),
                  ],
                ),
              ),
              crossFadeState: _showMore
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 260),
            ),
          ],
        ),
      ),
      contentMaxWidth: 900,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          color: Colors.white,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: _medicineGreen,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_editing ? 'Save changes' : 'Create medicine'),
          ),
        ),
      ),
    );
  }

  Widget _formIntro() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_medicineDarkGreen, _medicineGreen],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.white24,
            child: Icon(
              Icons.medication_liquid_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Medicine inventory',
                  style: TextStyle(color: Colors.white, fontSize: 17),
                ),
                SizedBox(height: 4),
                Text(
                  'Start with the essentials. Add stock entries to create batches and quantities.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _formCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _medicineDarkGreen.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _medicineGreen),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children.expand(
            (child) => [
              child,
              if (child != children.last) const SizedBox(height: 13),
            ],
          ),
        ],
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    String? hint,
    required IconData icon,
    bool required = false,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
    int maxLines = 1,
    String? supportingText,
    Color? supportingColor,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      readOnly: readOnly,
      decoration: _inputDecoration(
        label,
        icon,
        hint: hint,
        supportingText: supportingText,
        supportingColor: supportingColor,
      ),
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty)) {
          return '$label is required';
        }
        return validator?.call(value);
      },
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> values,
    required ValueChanged<String?> onChanged,
    Map<String, String> labels = const {},
    bool allowEmpty = false,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      style: AppTypography.dropdownTextStyle(context),
      decoration: _inputDecoration(
        label,
        Icons.arrow_drop_down_circle_outlined,
      ),
      items: [
        if (allowEmpty)
          const DropdownMenuItem<String>(
            value: null,
            child: Text('Not selected'),
          ),
        ...values.map(
          (item) => DropdownMenuItem(
            value: item,
            child: Text(labels[item] ?? _titleCase(item)),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    String? hint,
    String? supportingText,
    Color? supportingColor,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: supportingText,
      helperStyle: supportingColor == null
          ? null
          : TextStyle(color: supportingColor, fontWeight: FontWeight.w600),
      errorMaxLines: 2,
      prefixIcon: Icon(icon, color: _medicineGreen, size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FBFA),
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
    );
  }

  List<String> _splitValues(String value, RegExp separator) {
    return value
        .split(separator)
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String? _emptyToNull(String value) {
    final clean = value.trim();
    return clean.isEmpty ? null : clean;
  }

  String _number(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Not recorded';
    return DateFormat('dd MMM yyyy').format(value.toLocal());
  }

  String _stockUnitLabel(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'tab' => 'Tab',
      'bottle' => 'Bottle',
      'gel' => 'Gel',
      'piece' => 'Piece',
      null || '' => 'units',
      _ => value!.trim(),
    };
  }

  String _displayValue(String? value) {
    return value?.trim().isNotEmpty == true ? value!.trim() : 'Not recorded';
  }

  String _batchSourceText(MedicineBatch batch) {
    final label = batch.sourceLabel.trim().isEmpty
        ? 'Main Stock'
        : batch.sourceLabel.trim();
    final patientName = batch.sourcePatientName?.trim();
    final registerId = batch.sourcePatientRegisterId?.trim();
    if (batch.sourceType == 'return' &&
        patientName != null &&
        patientName.isNotEmpty) {
      final patientText = registerId != null && registerId.isNotEmpty
          ? '$patientName ($registerId)'
          : patientName;
      return '$label • $patientText';
    }
    return label;
  }

  String _nextMedicineCodeFrom(List<Medicine> medicines) {
    var maxSequence = 0;
    for (final medicine in medicines) {
      final match = _medicineCodePattern.firstMatch(
        medicine.code.trim().toUpperCase(),
      );
      final sequence = int.tryParse(match?.group(1) ?? '');
      if (sequence != null && sequence > maxSequence) {
        maxSequence = sequence;
      }
    }
    return 'MED-${(maxSequence + 1).toString().padLeft(3, '0')}';
  }

  String _titleCase(String value) {
    return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
  }
}
