import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:oruma_app/models/medicine.dart';
import 'package:oruma_app/models/patient.dart';
import 'package:oruma_app/models/medicine_supply.dart';
import 'package:oruma_app/services/medicine_service.dart';
import 'package:oruma_app/services/patient_service.dart';
import 'package:oruma_app/services/medicine_supply_service.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';

const _medicineDarkGreen = Color(0xFF0A4A3A);
const _medicineGreen = Color(0xFF0F6E56);
const _medicineSurface = Color(0xFFEBF4F1);
const _cardBg = Color(0xFFE1F5EE);
const _iconBg = Color(0xFF9FE1CB);

class MedicineSupplyPage extends StatefulWidget {
  final MedicineSupply? supply;

  const MedicineSupplyPage({super.key, this.supply});

  @override
  State<MedicineSupplyPage> createState() => _MedicineSupplyPageState();
}

class _MedicineSupplyPageState extends State<MedicineSupplyPage> {
  final _formKey = GlobalKey<FormState>();

  List<Patient> _patients = [];
  List<Medicine> _medicines = [];
  final List<_SupplyItemRow> _rows = [];
  bool _loadingData = true;
  bool _saving = false;

  Patient? _selectedPatient;

  bool _showMore = false;
  final String _status = 'given';
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _prescribedByController = TextEditingController();
  final TextEditingController _supplyDaysController = TextEditingController();

  DateTime _givenAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _addRow(settle: false);
    _loadData();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    _noteController.dispose();
    _prescribedByController.dispose();
    _supplyDaysController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final pResult = await PatientService.getAllPatients();
      final mResult = await MedicineService.getMedicines();

      if (mounted) {
        setState(() {
          _patients = pResult;
          _medicines = mResult;
          _loadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingData = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load data: $e')));
      }
    }
  }

  void _addRow({bool settle = true}) {
    _rows.add(_SupplyItemRow());
    if (settle && mounted) setState(() {});
  }

  void _removeRow(_SupplyItemRow row) {
    if (_rows.length == 1) {
      row.clear();
      setState(() {});
      return;
    }

    setState(() => _rows.remove(row));
    row.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPatient == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a patient')));
      return;
    }

    final items = _collectSupplyItems();
    if (items == null) return;

    final supplyDays = int.tryParse(_supplyDaysController.text.trim());
    if (_supplyDaysController.text.trim().isNotEmpty &&
        (supplyDays == null || supplyDays < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid supply days')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final authService = context.read<AuthService>();
      final staffId = authService.user?['_id'] ?? authService.user?['id'];

      if (staffId == null) {
        throw Exception('You must be logged in to supply medicine.');
      }

      final totalQty = items.fold<int>(0, (sum, item) => sum + item.qtyGiven);
      final supply = MedicineSupply(
        patientId: _selectedPatient!.id,
        medicineId: items.first.medicineId,
        givenByStaff: staffId,
        givenAt: _givenAt,
        qtyGiven: totalQty,
        items: items,
        status: _status,
        staffNote: _noteController.text.isEmpty ? null : _noteController.text,
        prescribedBy: _prescribedByController.text.isEmpty
            ? null
            : _prescribedByController.text,
        supplyDays: supplyDays,
      );

      await MedicineSupplyService.createMedicineSupply(supply);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medicine supplied successfully'),
            backgroundColor: _medicineDarkGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyError(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<MedicineSupplyItem>? _collectSupplyItems() {
    final items = <MedicineSupplyItem>[];
    final usedByBatch = <String, int>{};
    String? firstError;

    setState(() {
      for (final row in _rows) {
        row.error = null;
      }
    });

    for (var index = 0; index < _rows.length; index += 1) {
      final row = _rows[index];
      if (row.isBlank) continue;

      final medicine = row.selectedMedicine;

      if (medicine?.id == null) {
        row.error = 'Select a medicine';
      } else {
        final medicineId = medicine!.id!;
        var addedFromRow = false;

        final availableBatches = _availableBatches(medicine);

        if (availableBatches.isEmpty) {
          row.error = 'No stock batches available';
        }

        for (final batch in availableBatches) {
          final rawQuantity = row.batchQtyController(batch).text.trim();
          if (rawQuantity.isEmpty) continue;

          final quantity = int.tryParse(rawQuantity);
          if (quantity == null || quantity <= 0) {
            row.error = 'Enter a quantity greater than zero';
            break;
          }

          final batchId = batch.id ?? 'legacy:$medicineId';
          final alreadyUsed = usedByBatch[batchId] ?? 0;
          final available = batch.quantity.floor();
          if (alreadyUsed + quantity > available) {
            row.error =
                'Only ${available - alreadyUsed} ${_unitLabel(batch.qtyUnit)} left in this batch';
            break;
          }

          usedByBatch[batchId] = alreadyUsed + quantity;
          addedFromRow = true;
          items.add(
            MedicineSupplyItem(
              medicineId: medicineId,
              stockEntryId: batch.id,
              qtyGiven: quantity,
            ),
          );
        }

        if (row.error == null && !addedFromRow) {
          row.error = 'Enter quantity for at least one batch';
        }
      }

      if (row.error != null) {
        firstError ??= 'Row ${index + 1}: ${row.error}';
      }
    }

    if (firstError != null) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(firstError), backgroundColor: Colors.red),
      );
      return null;
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one medicine batch'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }

    return items;
  }

  Future<void> _pickGivenDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _givenAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => _givenAt = date);
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
              Icons.medication_outlined,
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
                  'Medicine Supply',
                  style: TextStyle(color: Colors.white, fontSize: 17),
                ),
                SizedBox(height: 4),
                Text(
                  'Select one or more medicine batches and record the quantity supplied to the patient.',
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

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
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

  Widget _textField(
    TextEditingController controller,
    String label, {
    String? hint,
    required IconData icon,
    bool required = false,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      decoration: _inputDecoration(label, icon, hint: hint),
      validator: required
          ? (value) =>
                value?.trim().isEmpty == true ? '$label is required' : null
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingData) {
      return AdaptiveAppScaffold(
        backgroundColor: const Color(0xFFF5FAF8),
        appBar: AppBar(
          backgroundColor: _medicineDarkGreen,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
          title: const Text('New Supply'),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: _medicineGreen),
        ),
        contentMaxWidth: 900,
      );
    }

    return AdaptiveAppScaffold(
      backgroundColor: const Color(0xFFF5FAF8),
      appBar: AppBar(
        backgroundColor: _medicineDarkGreen,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
        title: const Text('New Supply'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
          children: [
            _formIntro(),
            const SizedBox(height: 16),
            _formCard(
              title: 'Supply details',
              subtitle: 'Patient and supply date.',
              icon: Icons.person_add_alt_1_outlined,
              children: [
                _patientField(),
                if (_selectedPatient != null) _selectedPatientCard(),
                InkWell(
                  onTap: _pickGivenDate,
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: _inputDecoration('Date', Icons.event_outlined),
                    child: Text(
                      DateFormat('dd MMM yyyy').format(_givenAt),
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _formCard(
              title: 'Medicine batches',
              subtitle: 'Add one or more batch quantities.',
              icon: Icons.inventory_2_outlined,
              children: [_supplyRows()],
            ),
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
                            'Prescribed by, supply days, and notes',
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
                  title: 'Optional details',
                  subtitle: 'Extra information for this supply.',
                  icon: Icons.fact_check_outlined,
                  children: [
                    _textField(
                      _prescribedByController,
                      'Prescribed By',
                      hint: 'Doctor name',
                      icon: Icons.medical_information_outlined,
                    ),
                    _textField(
                      _supplyDaysController,
                      'Supply Days',
                      hint: 'How many days this stock should last',
                      icon: Icons.calendar_month_outlined,
                      keyboardType: TextInputType.number,
                    ),
                    _textField(
                      _noteController,
                      'Staff Note',
                      hint: 'Internal remarks...',
                      icon: Icons.notes_outlined,
                      maxLines: 3,
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
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              _saving ? 'Saving' : 'Save Supply Record',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _patientField() {
    return Autocomplete<Patient>(
      displayStringForOption: _patientOptionLabel,
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<Patient>.empty();
        }
        final query = textEditingValue.text.toLowerCase();
        return _patients.where(
          (p) =>
              p.name.toLowerCase().contains(query) ||
              (p.registerId?.toLowerCase().contains(query) ?? false) ||
              p.place.toLowerCase().contains(query),
        );
      },
      onSelected: (selection) => setState(() => _selectedPatient = selection),
      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          onEditingComplete: onEditingComplete,
          decoration: _inputDecoration(
            'Patient',
            Icons.person_search_outlined,
            hint: 'Search patient...',
          ),
          validator: (value) =>
              _selectedPatient == null ? 'Please select a patient' : null,
        );
      },
    );
  }

  Widget _selectedPatientCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _iconBg),
      ),
      child: Row(
        children: [
          const Icon(Icons.person, color: _medicineGreen, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedPatient!.name,
                  style: const TextStyle(
                    color: _medicineDarkGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (_selectedPatient!.registerId?.isNotEmpty == true)
                      'Reg No: ${_selectedPatient!.registerId}',
                    if (_selectedPatient!.place.isNotEmpty)
                      'Place: ${_selectedPatient!.place}',
                    if (_selectedPatient!.phone.isNotEmpty)
                      'Ph: ${_selectedPatient!.phone}',
                  ].join(' • '),
                  style: const TextStyle(
                    color: _medicineDarkGreen,
                    fontSize: 12,
                  ),
                ),
                if (_selectedPatient!.address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _selectedPatient!.address,
                    style: const TextStyle(
                      color: _medicineDarkGreen,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Clear patient',
            onPressed: () => setState(() => _selectedPatient = null),
            icon: const Icon(Icons.close, color: _medicineGreen, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _supplyRows() {
    return Column(
      children: [
        for (var index = 0; index < _rows.length; index += 1) ...[
          _supplyRowCard(_rows[index], index),
          if (index != _rows.length - 1) const SizedBox(height: 12),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _addRow(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add medicine batch'),
          ),
        ),
      ],
    );
  }

  Widget _supplyRowCard(_SupplyItemRow row, int index) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: row.error == null ? Colors.grey.shade200 : Colors.red.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Medicine ${index + 1}',
                  style: const TextStyle(
                    color: _medicineDarkGreen,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove medicine',
                onPressed: () => _removeRow(row),
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _medicineField(row),
          if (row.selectedMedicine != null) ...[
            const SizedBox(height: 12),
            _selectedMedicineSummary(row),
            const SizedBox(height: 12),
            _batchPicker(row),
          ],
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

  Widget _medicineField(_SupplyItemRow row) {
    return RawAutocomplete<Medicine>(
      textEditingController: row.medicineController,
      focusNode: row.medicineFocusNode,
      displayStringForOption: _medicineOptionLabel,
      optionsBuilder: (value) => _medicineOptions(value.text),
      onSelected: (selection) {
        setState(() {
          row.selectedMedicine = selection;
          row.clearBatchQuantities();
          row.medicineController.text = _medicineOptionLabel(selection);
          row.error = null;
        });
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          onChanged: (value) {
            final selected = row.selectedMedicine;
            if (selected != null &&
                value.trim() != _medicineOptionLabel(selected)) {
              setState(() {
                row.selectedMedicine = null;
                row.clearBatchQuantities();
              });
            }
          },
          decoration: _inputDecoration(
            'Medicine',
            Icons.medication_outlined,
            hint: 'Search medicine...',
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
              constraints: const BoxConstraints(maxHeight: 280, maxWidth: 330),
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
                    leading: const Icon(
                      Icons.medication_liquid_outlined,
                      color: _medicineGreen,
                    ),
                    title: Text(
                      option.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${option.code} • Stock ${_stockText(option)}',
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

  Iterable<Medicine> _medicineOptions(String value) {
    final query = value.trim().toLowerCase();
    if (query.isEmpty) return _medicines.take(10);

    return _medicines
        .where((medicine) {
          final haystack = [
            medicine.name,
            medicine.code,
            medicine.barcode,
            ...medicine.brandNames,
          ].whereType<String>().join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .take(10);
  }

  Widget _selectedMedicineSummary(_SupplyItemRow row) {
    final medicine = row.selectedMedicine!;
    final batchCount = _availableBatches(medicine).length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _iconBg),
      ),
      child: Row(
        children: [
          const Icon(Icons.medication_liquid, color: _medicineGreen, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicine.name,
                  style: const TextStyle(color: _medicineDarkGreen),
                ),
                const SizedBox(height: 3),
                Text(
                  'Stock ${_stockText(medicine)} • $batchCount batches',
                  style: TextStyle(
                    color: _medicineDarkGreen.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Clear medicine',
            onPressed: () {
              setState(() {
                row.selectedMedicine = null;
                row.clearBatchQuantities();
                row.medicineController.clear();
              });
            },
            icon: const Icon(Icons.close, color: _medicineGreen, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _batchPicker(_SupplyItemRow row) {
    final batches = _availableBatches(row.selectedMedicine!);
    if (batches.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          'No stock batches available',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select batch',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        ...batches.map((batch) => _batchOption(row, batch)),
        const SizedBox(height: 4),
        _batchTotal(row),
      ],
    );
  }

  Widget _batchOption(_SupplyItemRow row, MedicineBatch batch) {
    final controller = row.batchQtyController(batch);
    final hasQuantity = (int.tryParse(controller.text.trim()) ?? 0) > 0;
    final isEmpty = batch.isEmpty;
    final warning = !isEmpty && batch.expiresWithin60Days;
    final color = isEmpty
        ? Colors.grey.shade600
        : warning
        ? Colors.red.shade700
        : _medicineGreen;
    final background = isEmpty
        ? Colors.grey.shade100
        : warning
        ? Colors.red.shade50
        : hasQuantity
        ? _cardBg
        : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasQuantity
                ? _medicineGreen
                : warning
                ? Colors.red.shade300
                : Colors.grey.shade200,
            width: hasQuantity ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasQuantity ? Icons.check_circle : Icons.inventory_2_outlined,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    batch.batchNumber?.trim().isNotEmpty == true
                        ? batch.batchNumber!.trim()
                        : 'No batch number',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Exp ${_formatDate(batch.expiryDate)}',
                    style: TextStyle(
                      color: color.withValues(alpha: 0.78),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _batchSourceText(batch),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.72),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_number(batch.quantity)} ${_unitLabel(batch.qtyUnit)}',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 56,
              child: TextFormField(
                controller: controller,
                enabled: !isEmpty,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                decoration: InputDecoration(
                  hintText: 'Qty',
                  isDense: true,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: isEmpty ? Colors.grey.shade100 : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: _medicineGreen,
                      width: 1.5,
                    ),
                  ),
                ),
                onChanged: (_) {
                  setState(() => row.error = null);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _batchTotal(_SupplyItemRow row) {
    final total = _batchTotalQuantity(row);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            color: _medicineGreen,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            'Total quantity: $total',
            style: const TextStyle(
              color: _medicineDarkGreen,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  int _batchTotalQuantity(_SupplyItemRow row) {
    final medicine = row.selectedMedicine;
    final batches = medicine == null
        ? const <MedicineBatch>[]
        : _availableBatches(medicine);
    return batches.fold<int>(
      0,
      (sum, batch) =>
          sum + (int.tryParse(row.batchQtyController(batch).text.trim()) ?? 0),
    );
  }

  List<MedicineBatch> _availableBatches(Medicine medicine) {
    return medicine.batches
        .where((batch) => !batch.isEmpty)
        .toList(growable: false);
  }

  String _patientOptionLabel(Patient patient) {
    final details = [
      if (patient.registerId?.isNotEmpty == true) patient.registerId,
      if (patient.place.isNotEmpty) patient.place,
    ].whereType<String>().join(' • ');
    return details.isEmpty ? patient.name : '${patient.name} - $details';
  }

  String _medicineOptionLabel(Medicine medicine) {
    final netContent = medicine.netContent?.trim();
    if (netContent == null || netContent.isEmpty) return medicine.name;
    return '${medicine.name} $netContent';
  }

  String _stockText(Medicine medicine) {
    return '${_number(medicine.qty)} ${_unitLabel(medicine.qtyUnit)}'.trim();
  }

  String _number(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  String _unitLabel(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'tab' => 'Tab',
      'bottle' => 'Bottle',
      'gel' => 'Gel',
      'piece' => 'Piece',
      null || '' => 'units',
      _ => value!.trim(),
    };
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not recorded';
    return DateFormat('dd MMM yyyy').format(date.toLocal());
  }

  String _friendlyError(Object error) {
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }
}

class _SupplyItemRow {
  final TextEditingController medicineController = TextEditingController();
  final Map<String, TextEditingController> batchQtyControllers = {};
  final FocusNode medicineFocusNode = FocusNode();

  Medicine? selectedMedicine;
  String? error;

  bool get isBlank =>
      selectedMedicine == null &&
      medicineController.text.trim().isEmpty &&
      batchQtyControllers.values.every(
        (controller) => controller.text.trim().isEmpty,
      );

  TextEditingController batchQtyController(MedicineBatch batch) {
    final key = [
      batch.id,
      batch.batchNumber,
      batch.expiryDate?.toIso8601String(),
      batch.quantity,
    ].whereType<Object>().join(':');
    return batchQtyControllers.putIfAbsent(key, TextEditingController.new);
  }

  void clearBatchQuantities() {
    for (final controller in batchQtyControllers.values) {
      controller.dispose();
    }
    batchQtyControllers.clear();
  }

  void clear() {
    medicineController.clear();
    clearBatchQuantities();
    selectedMedicine = null;
    error = null;
  }

  void dispose() {
    medicineController.dispose();
    clearBatchQuantities();
    medicineFocusNode.dispose();
  }
}
