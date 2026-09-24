import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oruma_app/core/theme/app_typography.dart';
import 'package:oruma_app/medicine_stock_history_page.dart';
import 'package:oruma_app/models/medicine.dart';
import 'package:oruma_app/models/medicine_stock_entry.dart';
import 'package:oruma_app/services/medicine_service.dart';
import 'package:oruma_app/services/medicine_stock_service.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';

const _medicineGreen = Color(0xFF0F6E56);
const _medicineDarkGreen = Color(0xFF0A4A3A);
const _medicineSurface = Color(0xFFE1F5EE);

class MedicineStockEntryPage extends StatefulWidget {
  const MedicineStockEntryPage({super.key});

  @override
  State<MedicineStockEntryPage> createState() => _MedicineStockEntryPageState();
}

class _MedicineStockEntryPageState extends State<MedicineStockEntryPage> {
  static const _stockUnits = ['tab', 'bottle', 'gel', 'piece'];
  static const _tableHorizontalPadding = 12.0;
  static const _tableGap = 10.0;
  static const _numberWidth = 42.0;
  static const _medicineWidth = 270.0;
  static const _quantityWidth = 102.0;
  static const _unitWidth = 112.0;
  static const _expiryWidth = 144.0;
  static const _batchWidth = 140.0;
  static const _sourceWidth = 140.0;
  static const _noteWidth = 210.0;
  static const _actionWidth = 38.0;
  static const _tableContentWidth =
      _numberWidth +
      _medicineWidth +
      _quantityWidth +
      _unitWidth +
      _expiryWidth +
      _batchWidth +
      _sourceWidth +
      _noteWidth +
      _actionWidth +
      (_tableGap * 7);
  static const _tableWidth =
      (_tableHorizontalPadding * 2) + _tableContentWidth + 4;

  final List<_StockEntryRow> _rows = [];
  List<Medicine> _medicines = [];
  bool _loadingMedicines = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 3; i += 1) {
      _addRow(settle: false);
    }
    _loadMedicines();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMedicines() async {
    try {
      final medicines = await MedicineService.getMedicines();
      if (!mounted) return;
      setState(() {
        _medicines = medicines;
        _loadingMedicines = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingMedicines = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load medicines: ${_friendlyError(error)}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addRow({bool settle = true}) {
    final row = _StockEntryRow();
    _rows.add(row);
    if (settle && mounted) setState(() {});
  }

  void _removeRow(_StockEntryRow row) {
    if (_rows.length == 1) {
      row.clear();
      setState(() {});
      return;
    }

    setState(() => _rows.remove(row));
    row.dispose();
  }

  Future<void> _openHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MedicineStockHistoryPage()),
    );
  }

  Future<void> _pickExpiryDate(_StockEntryRow row) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: row.expiryDate ?? now.add(const Duration(days: 365)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (date != null) {
      setState(() {
        row.expiryDate = date;
        row.error = null;
      });
    }
  }

  Future<void> _save() async {
    final drafts = _collectDrafts();
    if (drafts == null) return;

    setState(() => _saving = true);
    try {
      final saved = await MedicineStockService.createBulkStockEntries(drafts);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${saved.length} stock entries added'),
          backgroundColor: _medicineDarkGreen,
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(error)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<MedicineStockEntryDraft>? _collectDrafts() {
    final drafts = <MedicineStockEntryDraft>[];
    String? firstError;

    setState(() {
      for (final row in _rows) {
        row.error = null;
      }
    });

    for (var index = 0; index < _rows.length; index += 1) {
      final row = _rows[index];
      if (row.isBlank) continue;

      final medicineName = row.medicineController.text.trim();
      if (medicineName.isEmpty) {
        row.error = 'Select or type a medicine name';
      }

      final quantity = double.tryParse(
        row.qtyController.text.trim().replaceAll(',', ''),
      );
      if (quantity == null || quantity <= 0) {
        row.error = 'Enter a quantity greater than zero';
      }

      if (row.expiryDate == null) {
        row.error = 'Choose an expiry date';
      }

      if (row.error != null) {
        firstError ??= 'Row ${index + 1}: ${row.error}';
        continue;
      }

      final exactMedicine = _findExactMedicine(medicineName);
      final selectedMedicine = row.selectedMedicine ?? exactMedicine;

      drafts.add(
        MedicineStockEntryDraft(
          medicineId: selectedMedicine?.id,
          medicineName: selectedMedicine?.name ?? medicineName,
          quantity: quantity!,
          qtyUnit: row.qtyUnit,
          expiryDate: row.expiryDate!,
          batchNumber: _emptyToNull(row.batchController.text),
          sourceLabel: row.sourceController.text.trim().isEmpty
              ? 'Main Stock'
              : row.sourceController.text.trim(),
          sourceType: row.sourceController.text.trim().toLowerCase() == 'main stock'
              ? 'main_stock'
              : row.sourceController.text.trim().toLowerCase(),
          note: _emptyToNull(row.noteController.text),
        ),
      );
    }

    if (firstError != null) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(firstError), backgroundColor: Colors.red),
      );
      return null;
    }

    if (drafts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one stock row'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }

    return drafts;
  }

  Medicine? _findExactMedicine(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final medicine in _medicines) {
      if (medicine.name.trim().toLowerCase() == normalized ||
          medicine.code.trim().toLowerCase() == normalized) {
        return medicine;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveAppScaffold(
      backgroundColor: const Color(0xFFF5FAF8),
      appBar: AppBar(
        backgroundColor: _medicineDarkGreen,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Add Stock',
          style: TextStyle(fontSize: 18, color: Colors.white),
        ),
        actions: [
          IconButton(
            tooltip: 'Stock history',
            onPressed: _openHistory,
            icon: const Icon(Icons.history_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 108),
        children: [_topBar(), const SizedBox(height: 14), _stockTable()],
      ),
      contentMaxWidth: 980,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          color: Colors.white,
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _saving ? null : () => _addRow(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _medicineDarkGreen,
                  side: const BorderSide(color: Color(0xFFBBDDCF), width: 1.2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  'Add Row',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: _medicineGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _saving ? 'Saving' : 'Save Stock Entries',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusPill(Icons.table_rows_outlined, '${_rows.length} rows'),
              if (_loadingMedicines)
                _statusPill(Icons.sync_outlined, 'Loading medicines'),
            ],
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: () => _addRow(),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Row'),
        ),
      ],
    );
  }

  Widget _statusPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _medicineSurface,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _medicineGreen),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: _medicineDarkGreen,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stockTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return _stockCards();
        }

        final width = constraints.maxWidth > _tableWidth
            ? constraints.maxWidth
            : _tableWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: _medicineDarkGreen.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _tableHeader(),
                  for (var index = 0; index < _rows.length; index += 1)
                    _tableRow(_rows[index], index),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _stockCards() {
    return Column(
      children: [
        for (var index = 0; index < _rows.length; index += 1) ...[
          _stockCard(_rows[index], index),
          if (index != _rows.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _stockCard(_StockEntryRow row, int index) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: _medicineDarkGreen.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Row ${index + 1}',
                  style: const TextStyle(
                    color: _medicineDarkGreen,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(
                width: 36,
                height: 36,
                child: IconButton(
                  tooltip: 'Remove row',
                  onPressed: () => _removeRow(row),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _fieldLabel('Medicine'),
          const SizedBox(height: 6),
          _medicineField(row),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Quantity'),
                    const SizedBox(height: 6),
                    _quantityField(row),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Unit'),
                    const SizedBox(height: 6),
                    _unitDropdown(row),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Expiry'),
                    const SizedBox(height: 6),
                    _expiryField(row),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Batch'),
                    const SizedBox(height: 6),
                    _simpleField(row.batchController),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Source'),
                    const SizedBox(height: 6),
                    _simpleField(row.sourceController),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Note'),
                    const SizedBox(height: 6),
                    _simpleField(row.noteController),
                  ],
                ),
              ),
            ],
          ),
          if (row.error != null) ...[
            const SizedBox(height: 10),
            Text(
              row.error!,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Colors.grey.shade700,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      color: _medicineSurface,
      padding: const EdgeInsets.symmetric(
        horizontal: _tableHorizontalPadding,
        vertical: 11,
      ),
      child: const SizedBox(
        width: _tableContentWidth,
        child: Row(
          children: [
            SizedBox(width: _numberWidth, child: _HeaderCell('#')),
            SizedBox(width: _medicineWidth, child: _HeaderCell('Medicine')),
            SizedBox(width: _tableGap),
            SizedBox(width: _quantityWidth, child: _HeaderCell('Qty')),
            SizedBox(width: _tableGap),
            SizedBox(width: _unitWidth, child: _HeaderCell('Unit')),
            SizedBox(width: _tableGap),
            SizedBox(width: _expiryWidth, child: _HeaderCell('Expiry')),
            SizedBox(width: _tableGap),
            SizedBox(width: _batchWidth, child: _HeaderCell('Batch')),
            SizedBox(width: _tableGap),
            SizedBox(width: _sourceWidth, child: _HeaderCell('Source')),
            SizedBox(width: _tableGap),
            SizedBox(width: _noteWidth, child: _HeaderCell('Note')),
            SizedBox(width: _tableGap),
            SizedBox(width: _actionWidth),
          ],
        ),
      ),
    );
  }

  Widget _tableRow(_StockEntryRow row, int index) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _tableHorizontalPadding,
              vertical: 10,
            ),
            child: SizedBox(
              width: _tableContentWidth,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _numberWidth,
                    height: 48,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: _medicineWidth, child: _medicineField(row)),
                  const SizedBox(width: _tableGap),
                  SizedBox(width: _quantityWidth, child: _quantityField(row)),
                  const SizedBox(width: _tableGap),
                  SizedBox(width: _unitWidth, child: _unitDropdown(row)),
                  const SizedBox(width: _tableGap),
                  SizedBox(width: _expiryWidth, child: _expiryField(row)),
                  const SizedBox(width: _tableGap),
                  SizedBox(
                    width: _batchWidth,
                    child: _simpleField(row.batchController),
                  ),
                  const SizedBox(width: _tableGap),
                  SizedBox(
                    width: _sourceWidth,
                    child: _simpleField(row.sourceController),
                  ),
                  const SizedBox(width: _tableGap),
                  SizedBox(
                    width: _noteWidth,
                    child: _simpleField(row.noteController),
                  ),
                  const SizedBox(width: _tableGap),
                  SizedBox(
                    width: _actionWidth,
                    height: 48,
                    child: IconButton(
                      tooltip: 'Remove row',
                      onPressed: () => _removeRow(row),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (row.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(54, 0, 12, 10),
              alignment: Alignment.centerLeft,
              child: Text(
                row.error!,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _medicineField(_StockEntryRow row) {
    return RawAutocomplete<_MedicineOption>(
      textEditingController: row.medicineController,
      focusNode: row.medicineFocusNode,
      displayStringForOption: (option) => option.label,
      optionsBuilder: (textEditingValue) => _medicineOptions(textEditingValue),
      onSelected: (option) {
        setState(() {
          row.selectedMedicine = option.medicine;
          row.medicineController.text = option.label;
          row.error = null;
        });
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          onChanged: (value) {
            final selected = row.selectedMedicine;
            if (selected != null && value.trim() != selected.name) {
              setState(() => row.selectedMedicine = null);
            }
          },
          decoration: _cellDecoration(
            hint: 'Search or type',
            icon: Icons.medication_liquid_outlined,
            suffixIcon:
                row.selectedMedicine == null &&
                    controller.text.trim().isNotEmpty
                ? const Icon(Icons.add_circle_outline, size: 18)
                : null,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final optionList = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280, maxWidth: 300),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: optionList.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (context, index) {
                  final option = optionList[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      option.createsNew
                          ? Icons.add_circle_outline
                          : Icons.medication_liquid_outlined,
                      color: _medicineGreen,
                    ),
                    title: Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      option.createsNew
                          ? 'Create new medicine'
                          : [
                              option.medicine?.code,
                              if (option.medicine != null)
                                'Stock ${_number(option.medicine!.qty)}',
                            ].whereType<String>().join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Iterable<_MedicineOption> _medicineOptions(TextEditingValue value) {
    final query = value.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _medicines.take(8).map(_MedicineOption.existing);
    }

    final matches = _medicines
        .where((medicine) {
          final haystack = [
            medicine.name,
            medicine.code,
            medicine.barcode,
            ...medicine.brandNames,
          ].whereType<String>().join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .take(8)
        .map(_MedicineOption.existing)
        .toList();

    final exact = _medicines.any(
      (medicine) =>
          medicine.name.trim().toLowerCase() == query ||
          medicine.code.trim().toLowerCase() == query,
    );
    if (!exact) {
      matches.add(_MedicineOption.create(value.text.trim()));
    }
    return matches;
  }

  Widget _quantityField(_StockEntryRow row) {
    return TextField(
      controller: row.qtyController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      decoration: _cellDecoration(hint: '0'),
      onChanged: (_) {
        if (row.error != null) setState(() => row.error = null);
      },
    );
  }

  Widget _unitDropdown(_StockEntryRow row) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: _cellBoxDecoration(),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: row.qtyUnit,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          style: AppTypography.dropdownTextStyle(context),
          items: _stockUnits
              .map(
                (unit) => DropdownMenuItem(
                  value: unit,
                  child: Text(
                    _unitLabel(unit),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => row.qtyUnit = value);
          },
        ),
      ),
    );
  }

  Widget _expiryField(_StockEntryRow row) {
    return InkWell(
      onTap: () => _pickExpiryDate(row),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: _cellBoxDecoration(),
        child: Row(
          children: [
            const Icon(Icons.event_outlined, size: 18, color: _medicineGreen),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                row.expiryDate == null
                    ? 'Date'
                    : DateFormat('dd MMM yyyy').format(row.expiryDate!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: row.expiryDate == null
                      ? Colors.grey.shade600
                      : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _simpleField(TextEditingController controller) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.next,
      decoration: _cellDecoration(),
    );
  }

  InputDecoration _cellDecoration({
    String? hint,
    IconData? icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon == null
          ? null
          : Icon(icon, color: _medicineGreen, size: 18),
      suffixIcon: suffixIcon,
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF8FBFA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _medicineGreen, width: 1.5),
      ),
    );
  }

  BoxDecoration _cellBoxDecoration() {
    return BoxDecoration(
      color: const Color(0xFFF8FBFA),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    );
  }

  String _number(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  String _unitLabel(String value) {
    return switch (value.trim().toLowerCase()) {
      'tab' => 'Tab',
      'bottle' => 'Bottle',
      'gel' => 'Gel',
      'piece' => 'Piece',
      '' => 'units',
      _ => value.trim(),
    };
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _friendlyError(Object error) {
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;

  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: _medicineDarkGreen,
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _MedicineOption {
  final Medicine? medicine;
  final String label;

  const _MedicineOption._({this.medicine, required this.label});

  factory _MedicineOption.existing(Medicine medicine) {
    return _MedicineOption._(medicine: medicine, label: medicine.name);
  }

  factory _MedicineOption.create(String label) {
    return _MedicineOption._(label: label);
  }

  bool get createsNew => medicine == null;
}

class _StockEntryRow {
  final TextEditingController medicineController = TextEditingController();
  final TextEditingController qtyController = TextEditingController();
  final TextEditingController batchController = TextEditingController();
  final TextEditingController sourceController = TextEditingController(text: 'Main Stock');
  final TextEditingController noteController = TextEditingController();
  final FocusNode medicineFocusNode = FocusNode();

  Medicine? selectedMedicine;
  String qtyUnit = 'tab';
  DateTime? expiryDate;
  String? error;

  bool get isBlank {
    return medicineController.text.trim().isEmpty &&
        qtyController.text.trim().isEmpty &&
        batchController.text.trim().isEmpty &&
        sourceController.text.trim() == 'Main Stock' &&
        noteController.text.trim().isEmpty &&
        expiryDate == null;
  }

  void clear() {
    medicineController.clear();
    qtyController.clear();
    batchController.clear();
    sourceController.text = 'Main Stock';
    noteController.clear();
    selectedMedicine = null;
    qtyUnit = 'tab';
    expiryDate = null;
    error = null;
  }

  void dispose() {
    medicineController.dispose();
    qtyController.dispose();
    batchController.dispose();
    sourceController.dispose();
    noteController.dispose();
    medicineFocusNode.dispose();
  }
}
