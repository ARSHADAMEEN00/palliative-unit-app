import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/models/patient.dart';
import 'package:oruma_app/models/equipment.dart';
import 'package:oruma_app/models/ward.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/models/equipment_supply.dart';
import 'package:oruma_app/services/equipment_service.dart';
import 'package:oruma_app/services/equipment_supply_service.dart';
import 'package:oruma_app/services/patient_service.dart';
import 'package:oruma_app/services/ward_service.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';
import 'package:oruma_app/widgets/module_theme.dart';
import 'package:oruma_app/widgets/searchable_dropdown_field.dart';
import 'package:intl/intl.dart';

const _equipmentSupplyStrong = Color(0xFFB45309);
const _equipmentSupplyIconSurface = Color(0xFFFEF3C7);

class EqSupply extends StatefulWidget {
  const EqSupply({super.key});

  @override
  State<EqSupply> createState() => _EqSupplyState();
}

class _EqSupplyState extends State<EqSupply> {
  final _formKey = GlobalKey<FormState>();

  // Form fields
  final List<Equipment> _selectedEquipment = [];
  Patient? _selectedPatient;
  List<Ward> _wards = [];
  String? _selectedLocalBody;
  Ward? _selectedWard;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _careOfController = TextEditingController();
  final TextEditingController _supplyDateController = TextEditingController();
  final TextEditingController _receiverNameController = TextEditingController();
  final TextEditingController _receiverPhoneController =
      TextEditingController();
  final TextEditingController _receiverAddressController =
      TextEditingController();
  final TextEditingController _receiverPlaceController =
      TextEditingController();
  final TextEditingController _equipmentSearchController =
      TextEditingController();
  final FocusNode _equipmentSearchFocusNode = FocusNode();

  // Data
  List<Equipment> _availableEquipment = [];
  List<Patient> _patients = [];
  late DateTime _selectedSupplyDate;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedSupplyDate = _normalizeDate(DateTime.now());
    _supplyDateController.text = _formatSupplyDate(_selectedSupplyDate);
    _loadInitialData();
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day, 12, 0, 0);
  }

  String _formatSupplyDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  DateTime _minimumSupplyDate() {
    DateTime? latestPurchaseDate;
    for (final equipment in _selectedEquipment) {
      final purchaseDate = equipment.purchaseDate;
      if (purchaseDate != null &&
          (latestPurchaseDate == null ||
              purchaseDate.isAfter(latestPurchaseDate))) {
        latestPurchaseDate = purchaseDate;
      }
    }

    if (latestPurchaseDate != null) {
      return _normalizeDate(latestPurchaseDate);
    }

    return DateTime(2000);
  }

  bool _isEquipmentSelected(Equipment equipment) {
    return _selectedEquipment.any((selected) {
      if (equipment.id?.isNotEmpty == true) {
        return selected.id == equipment.id;
      }
      return selected.uniqueId == equipment.uniqueId;
    });
  }

  void _setSupplyDate(DateTime date) {
    _selectedSupplyDate = _normalizeDate(date);
    _supplyDateController.text = _formatSupplyDate(_selectedSupplyDate);
  }

  Future<void> _pickSupplyDate() async {
    final today = _normalizeDate(DateTime.now());
    final firstDate = _minimumSupplyDate();
    final initialDate = _selectedSupplyDate.isBefore(firstDate)
        ? firstDate
        : _selectedSupplyDate.isAfter(today)
        ? today
        : _selectedSupplyDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: today,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _equipmentSupplyStrong,
              onPrimary: AppColors.textInverse,
              onSurface: AppColors.text,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _setSupplyDate(picked);
      });
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    await Future.wait([
      _fetchAvailableEquipment(),
      _fetchPatients(),
      _fetchWards(),
    ]);
    setState(() => _loading = false);
  }

  Future<void> _fetchPatients() async {
    try {
      final list = await PatientService.getAllPatients(isDead: false);
      setState(() {
        _patients = list;
      });
    } catch (e) {
      debugPrint('Error fetching patients: $e');
    }
  }

  Future<void> _fetchWards() async {
    try {
      final wards = await WardService.getWards();
      if (mounted) setState(() => _wards = wards);
    } catch (e) {
      debugPrint('Error fetching wards: $e');
    }
  }

  List<String> get _localBodies =>
      _wards
          .map((ward) => ward.localBody?.trim() ?? '')
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

  List<Ward> get _wardsForLocalBody => _wards
      .where(
        (ward) =>
            (ward.localBody?.trim() ?? '') ==
            (_selectedLocalBody?.trim() ?? ''),
      )
      .toList();

  void _selectPatient(Patient? patient) {
    final ward =
        patient?.currentWard ??
        _wards.cast<Ward?>().firstWhere(
          (item) => item?.id == patient?.currentWardId,
          orElse: () => null,
        );
    setState(() {
      _selectedPatient = patient;
      _selectedWard = ward;
      _selectedLocalBody = ward?.localBody?.trim().isNotEmpty == true
          ? ward!.localBody!.trim()
          : patient?.village.trim().isNotEmpty == true
          ? patient!.village.trim()
          : null;
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _careOfController.dispose();
    _supplyDateController.dispose();
    _receiverNameController.dispose();
    _receiverPhoneController.dispose();
    _receiverAddressController.dispose();
    _receiverPlaceController.dispose();
    _equipmentSearchController.dispose();
    _equipmentSearchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchAvailableEquipment() async {
    try {
      final list = await EquipmentService.getInventoryEquipment();
      setState(() {
        _availableEquipment = list;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading equipment: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
        setState(() => {});
      }
    }
  }

  Future<void> _submit() async {
    if (_selectedEquipment.isEmpty ||
        _selectedEquipment.any((equipment) => equipment.isDamaged)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                _selectedEquipment.isEmpty
                    ? 'Please select at least one equipment item'
                    : 'Damaged equipment cannot be distributed',
              ),
            ],
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    if (_selectedEquipment.any(
      (equipment) => equipment.id == null || equipment.id!.isEmpty,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select the equipment again'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Validate that either patient or receiver is provided
    if (_selectedPatient == null &&
        _receiverNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Please select a patient or enter receiver details',
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    if (_selectedPatient == null &&
        (_selectedWard == null || _selectedLocalBody?.isNotEmpty != true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select the local body and ward for this handover'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_selectedPatient != null &&
        (_selectedPatient!.id == null || _selectedPatient!.id!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select the patient again'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final equipmentToDistribute = List<Equipment>.of(_selectedEquipment);
    final distributedEquipment = <Equipment>[];

    setState(() => _submitting = true);

    try {
      // Keep the existing API contract: submit one request at a time so every
      // selected item becomes its own equipment-supply record.
      for (final equipment in equipmentToDistribute) {
        final supply = EquipmentSupply(
          equipmentId: equipment.id!,
          equipmentUniqueId: equipment.uniqueId,
          equipmentName: equipment.name,
          patientId: _selectedPatient?.id,
          wardId: _selectedPatient == null ? _selectedWard?.id : null,
          localBody: _selectedPatient == null ? _selectedLocalBody : null,
          patientName: _selectedPatient?.name,
          patientPhone: _selectedPatient?.phone,
          patientAddress: _selectedPatient?.address,
          patientPlace: _selectedPatient?.place,
          careOf: _careOfController.text.trim(),
          receiverName: _receiverNameController.text.trim(),
          receiverPhone: _receiverPhoneController.text.trim(),
          receiverAddress: _receiverAddressController.text.trim(),
          receiverPlace: _receiverPlaceController.text.trim(),
          supplyDate: _selectedSupplyDate,
          notes: _notesController.text.trim(),
        );

        await EquipmentSupplyService.createSupply(supply);
        distributedEquipment.add(equipment);
      }

      if (mounted) {
        final itemCount = distributedEquipment.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    itemCount == 1
                        ? 'Equipment distributed successfully!'
                        : '$itemCount equipment items distributed successfully!',
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        if (distributedEquipment.isNotEmpty) {
          setState(() {
            _selectedEquipment.removeWhere(
              (equipment) => distributedEquipment.any(
                (distributed) => distributed.id == equipment.id,
              ),
            );
            _availableEquipment.removeWhere(
              (equipment) => distributedEquipment.any(
                (distributed) => distributed.id == equipment.id,
              ),
            );
          });
        }

        final completedCount = distributedEquipment.length;
        final errorMessage = completedCount == 0
            ? 'Error: $e'
            : '$completedCount of ${equipmentToDistribute.length} items were distributed. '
                  'The remaining items were not submitted: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
            'Distribute Equipment',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        body: _loading
            ? const AppListSkeleton(itemCount: 4)
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        AppInsets.screenHorizontal(context),
                        AppSpacing.md,
                        AppInsets.screenHorizontal(context),
                        AppSpacing.lg,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _buildSectionCard(
                              title: 'Distribution Details',
                              icon: Icons.assignment_outlined,
                              children: [
                                // Equipment Autocomplete Search
                                Autocomplete<Equipment>(
                                  textEditingController:
                                      _equipmentSearchController,
                                  focusNode: _equipmentSearchFocusNode,
                                  optionsBuilder:
                                      (
                                        TextEditingValue textEditingValue,
                                      ) async {
                                        if (textEditingValue.text.isEmpty) {
                                          return _availableEquipment.where(
                                            (equipment) =>
                                                !_isEquipmentSelected(
                                                  equipment,
                                                ),
                                          );
                                        }
                                        try {
                                          final searchResults =
                                              await EquipmentService.getInventoryEquipment(
                                                search: textEditingValue.text,
                                              );
                                          return searchResults.where(
                                            (equipment) =>
                                                !_isEquipmentSelected(
                                                  equipment,
                                                ),
                                          );
                                        } catch (e) {
                                          return _availableEquipment.where((
                                            equipment,
                                          ) {
                                            final searchText =
                                                '${equipment.uniqueId} ${equipment.name}'
                                                    .toLowerCase();
                                            return !_isEquipmentSelected(
                                                  equipment,
                                                ) &&
                                                searchText.contains(
                                                  textEditingValue.text
                                                      .toLowerCase(),
                                                );
                                          });
                                        }
                                      },
                                  displayStringForOption: (Equipment equipment) =>
                                      '${equipment.uniqueId} - ${equipment.name.toUpperCase()}',
                                  onSelected: (Equipment equipment) {
                                    if (equipment.isDamaged) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Cannot select damaged equipment for distribution',
                                          ),
                                          backgroundColor: AppColors.danger,
                                        ),
                                      );
                                      return;
                                    }
                                    if (_isEquipmentSelected(equipment)) {
                                      return;
                                    }
                                    setState(() {
                                      _selectedEquipment.add(equipment);
                                      final minimumSupplyDate =
                                          _minimumSupplyDate();
                                      if (_selectedSupplyDate.isBefore(
                                        minimumSupplyDate,
                                      )) {
                                        _setSupplyDate(minimumSupplyDate);
                                      }
                                    });
                                    _equipmentSearchController.clear();
                                    _equipmentSearchFocusNode.requestFocus();
                                  },
                                  fieldViewBuilder:
                                      (
                                        BuildContext context,
                                        TextEditingController
                                        textEditingController,
                                        FocusNode focusNode,
                                        VoidCallback onFieldSubmitted,
                                      ) {
                                        return TextFormField(
                                          controller: textEditingController,
                                          focusNode: focusNode,
                                          decoration:
                                              _inputDecoration(
                                                'Search Equipment',
                                                Icons.inventory_2_outlined,
                                              ).copyWith(
                                                hintText: 'Type to search...',
                                              ),
                                          onFieldSubmitted: (String value) {
                                            onFieldSubmitted();
                                          },
                                        );
                                      },
                                  optionsViewBuilder:
                                      (
                                        BuildContext context,
                                        AutocompleteOnSelected<Equipment>
                                        onSelected,
                                        Iterable<Equipment> options,
                                      ) {
                                        return Align(
                                          alignment: Alignment.topLeft,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8.0,
                                            ),
                                            child: Material(
                                              elevation: 4.0,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                      maxHeight: 200,
                                                      maxWidth: 400,
                                                    ),
                                                child: ListView.builder(
                                                  padding: EdgeInsets.zero,
                                                  shrinkWrap: true,
                                                  itemCount: options.length,
                                                  itemBuilder:
                                                      (
                                                        BuildContext context,
                                                        int index,
                                                      ) {
                                                        final Equipment
                                                        equipment = options
                                                            .elementAt(index);
                                                        final bool isDamaged =
                                                            equipment.isDamaged;
                                                        return InkWell(
                                                          onTap: isDamaged
                                                              ? null
                                                              : () {
                                                                  onSelected(
                                                                    equipment,
                                                                  );
                                                                },
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      16,
                                                                  vertical: 12,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: isDamaged
                                                                  ? AppColors
                                                                        .danger
                                                                        .withValues(
                                                                          alpha:
                                                                              0.04,
                                                                        )
                                                                  : null,
                                                              border: Border(
                                                                bottom: BorderSide(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade200,
                                                                ),
                                                              ),
                                                            ),
                                                            child: Row(
                                                              children: [
                                                                Icon(
                                                                  isDamaged
                                                                      ? Icons
                                                                            .build_circle_outlined
                                                                      : Icons
                                                                            .inventory_2,
                                                                  size: 18,
                                                                  color:
                                                                      isDamaged
                                                                      ? AppColors
                                                                            .danger
                                                                      : Colors
                                                                            .grey
                                                                            .shade600,
                                                                ),
                                                                const SizedBox(
                                                                  width: 12,
                                                                ),
                                                                Expanded(
                                                                  child: Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      Row(
                                                                        children: [
                                                                          Container(
                                                                            padding: const EdgeInsets.symmetric(
                                                                              horizontal: 8,
                                                                              vertical: 2,
                                                                            ),
                                                                            decoration: BoxDecoration(
                                                                              color: isDamaged
                                                                                  ? AppColors.danger.withValues(
                                                                                      alpha: 0.12,
                                                                                    )
                                                                                  : Colors.orange.withValues(
                                                                                      alpha: 0.15,
                                                                                    ),
                                                                              borderRadius: BorderRadius.circular(
                                                                                6,
                                                                              ),
                                                                            ),
                                                                            child: Text(
                                                                              equipment.uniqueId,
                                                                              style: TextStyle(
                                                                                fontSize: 11,
                                                                                fontWeight: FontWeight.w600,
                                                                                color: isDamaged
                                                                                    ? AppColors.danger
                                                                                    : Colors.orange,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          const SizedBox(
                                                                            width:
                                                                                8,
                                                                          ),
                                                                          Expanded(
                                                                            child: Text(
                                                                              equipment.name.toUpperCase(),
                                                                              style: TextStyle(
                                                                                fontSize: 14,
                                                                                fontWeight: FontWeight.w500,
                                                                                color: isDamaged
                                                                                    ? AppColors.textMuted
                                                                                    : AppColors.text,
                                                                              ),
                                                                              overflow: TextOverflow.ellipsis,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                      if (isDamaged) ...[
                                                                        const SizedBox(
                                                                          height:
                                                                              4,
                                                                        ),
                                                                        Row(
                                                                          children: [
                                                                            Container(
                                                                              padding: const EdgeInsets.symmetric(
                                                                                horizontal: 7,
                                                                                vertical: 2,
                                                                              ),
                                                                              decoration: BoxDecoration(
                                                                                color: AppColors.danger.withValues(
                                                                                  alpha: 0.09,
                                                                                ),
                                                                                borderRadius: BorderRadius.circular(
                                                                                  999,
                                                                                ),
                                                                                border: Border.all(
                                                                                  color: AppColors.danger.withValues(
                                                                                    alpha: 0.18,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              child: Row(
                                                                                mainAxisSize: MainAxisSize.min,
                                                                                children: [
                                                                                  const Icon(
                                                                                    Icons.block,
                                                                                    size: 10,
                                                                                    color: AppColors.danger,
                                                                                  ),
                                                                                  const SizedBox(
                                                                                    width: 3,
                                                                                  ),
                                                                                  Text(
                                                                                    equipment.damagedAt !=
                                                                                            null
                                                                                        ? 'DAMAGED (${DateFormat("d MMM yyyy").format(equipment.damagedAt!)}) – Cannot select'
                                                                                        : 'DAMAGED – Cannot select',
                                                                                    style: const TextStyle(
                                                                                      fontSize: 10,
                                                                                      fontWeight: FontWeight.w700,
                                                                                      color: AppColors.danger,
                                                                                      letterSpacing: 0.2,
                                                                                    ),
                                                                                  ),
                                                                                ],
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ],
                                                                    ],
                                                                  ),
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
                                        );
                                      },
                                ),
                                if (_selectedEquipment.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _equipmentSupplyIconSurface,
                                      borderRadius: AppRadius.sm,
                                      border: Border.all(
                                        color: _equipmentSupplyStrong
                                            .withValues(alpha: 0.16),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Selected equipment (${_selectedEquipment.length})',
                                          style: const TextStyle(
                                            color: _equipmentSupplyStrong,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        ..._selectedEquipment.asMap().entries.map((
                                          entry,
                                        ) {
                                          final index = entry.key;
                                          final equipment = entry.value;
                                          return Column(
                                            children: [
                                              if (index > 0)
                                                Divider(
                                                  height: 1,
                                                  color: _equipmentSupplyStrong
                                                      .withValues(alpha: 0.12),
                                                ),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.check_circle,
                                                    color:
                                                        _equipmentSupplyStrong,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 8,
                                                          ),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            '${equipment.uniqueId} - ${equipment.name.toUpperCase()}',
                                                            style: const TextStyle(
                                                              color:
                                                                  _equipmentSupplyStrong,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                          if (equipment
                                                              .place
                                                              .isNotEmpty)
                                                            Text(
                                                              equipment.place,
                                                              style:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .textTheme
                                                                      .bodySmall,
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    tooltip: 'Remove equipment',
                                                    onPressed: _submitting
                                                        ? null
                                                        : () {
                                                            setState(() {
                                                              _selectedEquipment
                                                                  .removeAt(
                                                                    index,
                                                                  );
                                                            });
                                                          },
                                                    icon: const Icon(
                                                      Icons.close,
                                                      size: 18,
                                                    ),
                                                    color:
                                                        _equipmentSupplyStrong,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),

                                TextFormField(
                                  controller: _supplyDateController,
                                  readOnly: true,
                                  onTap: _submitting ? null : _pickSupplyDate,
                                  validator: (value) =>
                                      value == null || value.isEmpty
                                      ? 'Please select a supply date'
                                      : null,
                                  decoration:
                                      _inputDecoration(
                                        'Supply Date',
                                        Icons.calendar_today_outlined,
                                      ).copyWith(
                                        hintText: 'Select supply date',
                                        suffixIcon: Icon(
                                          Icons.arrow_drop_down,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                ),
                                const SizedBox(height: 16),

                                // Searchable patient dropdown. The selected
                                // patient ID is persisted by the API; the
                                // visible details remain a historical snapshot.
                                Row(
                                  children: [
                                    Expanded(
                                      child: Autocomplete<Patient>(
                                        initialValue: _selectedPatient != null
                                            ? TextEditingValue(
                                                text: _selectedPatient!.name,
                                              )
                                            : null,
                                        optionsBuilder:
                                            (
                                              TextEditingValue textEditingValue,
                                            ) async {
                                              if (textEditingValue
                                                  .text
                                                  .isEmpty) {
                                                return _patients;
                                              }
                                              try {
                                                final searchResults =
                                                    await PatientService.searchPatients(
                                                      textEditingValue.text,
                                                      isDead: false,
                                                    );
                                                return searchResults;
                                              } catch (e) {
                                                return _patients.where((
                                                  patient,
                                                ) {
                                                  return patient.name
                                                      .toLowerCase()
                                                      .contains(
                                                        textEditingValue.text
                                                            .toLowerCase(),
                                                      );
                                                });
                                              }
                                            },
                                        displayStringForOption:
                                            (Patient patient) =>
                                                patient.name.toUpperCase(),
                                        onSelected: (Patient patient) {
                                          _selectPatient(patient);
                                        },
                                        fieldViewBuilder:
                                            (
                                              BuildContext context,
                                              TextEditingController
                                              textEditingController,
                                              FocusNode focusNode,
                                              VoidCallback onFieldSubmitted,
                                            ) {
                                              return TextFormField(
                                                controller:
                                                    textEditingController,
                                                focusNode: focusNode,
                                                decoration:
                                                    _inputDecoration(
                                                      'Select Registered Patient',
                                                      Icons.person_outline,
                                                    ).copyWith(
                                                      hintText:
                                                          'Tap or type to search patients',
                                                      suffixIcon:
                                                          _selectedPatient ==
                                                              null
                                                          ? const Icon(
                                                              Icons
                                                                  .arrow_drop_down,
                                                            )
                                                          : IconButton(
                                                              tooltip:
                                                                  'Clear patient',
                                                              onPressed: () {
                                                                textEditingController
                                                                    .clear();
                                                                _selectPatient(
                                                                  null,
                                                                );
                                                              },
                                                              icon: const Icon(
                                                                Icons.clear,
                                                              ),
                                                            ),
                                                    ),
                                                onChanged: (value) {
                                                  final selected =
                                                      _selectedPatient;
                                                  if (selected != null &&
                                                      value
                                                              .trim()
                                                              .toLowerCase() !=
                                                          selected.name
                                                              .trim()
                                                              .toLowerCase()) {
                                                    _selectPatient(null);
                                                  }
                                                },
                                                onFieldSubmitted:
                                                    (String value) {
                                                      onFieldSubmitted();
                                                    },
                                              );
                                            },
                                        optionsViewBuilder:
                                            (
                                              BuildContext context,
                                              AutocompleteOnSelected<Patient>
                                              onSelected,
                                              Iterable<Patient> options,
                                            ) {
                                              return Align(
                                                alignment: Alignment.topLeft,
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 8.0,
                                                      ),
                                                  child: Material(
                                                    elevation: 4.0,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    child: ConstrainedBox(
                                                      constraints:
                                                          const BoxConstraints(
                                                            maxHeight: 200,
                                                            maxWidth: 400,
                                                          ),
                                                      child: ListView.builder(
                                                        padding:
                                                            EdgeInsets.zero,
                                                        shrinkWrap: true,
                                                        itemCount:
                                                            options.length,
                                                        itemBuilder:
                                                            (
                                                              BuildContext
                                                              context,
                                                              int index,
                                                            ) {
                                                              final Patient
                                                              patient = options
                                                                  .elementAt(
                                                                    index,
                                                                  );
                                                              return InkWell(
                                                                onTap: () {
                                                                  onSelected(
                                                                    patient,
                                                                  );
                                                                },
                                                                child: Container(
                                                                  padding:
                                                                      const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            16,
                                                                        vertical:
                                                                            12,
                                                                      ),
                                                                  decoration: BoxDecoration(
                                                                    border: Border(
                                                                      bottom: BorderSide(
                                                                        color: Colors
                                                                            .grey
                                                                            .shade200,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  child: Row(
                                                                    children: [
                                                                      Icon(
                                                                        Icons
                                                                            .person,
                                                                        size:
                                                                            18,
                                                                        color: Colors
                                                                            .grey
                                                                            .shade600,
                                                                      ),
                                                                      const SizedBox(
                                                                        width:
                                                                            12,
                                                                      ),
                                                                      Expanded(
                                                                        child: Column(
                                                                          crossAxisAlignment:
                                                                              CrossAxisAlignment.start,
                                                                          children: [
                                                                            Row(
                                                                              children: [
                                                                                Expanded(
                                                                                  child: Text(
                                                                                    patient.name.toUpperCase(),
                                                                                    style: const TextStyle(
                                                                                      fontSize: 15,
                                                                                      fontWeight: FontWeight.w500,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                if (patient.registerId !=
                                                                                    null)
                                                                                  Container(
                                                                                    padding: const EdgeInsets.symmetric(
                                                                                      horizontal: 8,
                                                                                      vertical: 2,
                                                                                    ),
                                                                                    decoration: BoxDecoration(
                                                                                      color:
                                                                                          Theme.of(
                                                                                            context,
                                                                                          ).primaryColor.withValues(
                                                                                            alpha: 0.15,
                                                                                          ),
                                                                                      borderRadius: BorderRadius.circular(
                                                                                        6,
                                                                                      ),
                                                                                    ),
                                                                                    child: Text(
                                                                                      '#${patient.registerId}',
                                                                                      style: TextStyle(
                                                                                        fontSize: 11,
                                                                                        fontWeight: FontWeight.w600,
                                                                                        color: Theme.of(
                                                                                          context,
                                                                                        ).primaryColor,
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                              ],
                                                                            ),
                                                                            if (context
                                                                                    .read<
                                                                                      AuthService
                                                                                    >()
                                                                                    .canViewContactNumbers &&
                                                                                patient.phone.isNotEmpty)
                                                                              Text(
                                                                                patient.phone,
                                                                                style: TextStyle(
                                                                                  fontSize: 12,
                                                                                  color: Colors.grey.shade600,
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
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                      ),
                                    ),
                                  ],
                                ),
                                if (_selectedPatient != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _equipmentSupplyIconSurface,
                                      borderRadius: AppRadius.sm,
                                      border: Border.all(
                                        color: _equipmentSupplyStrong
                                            .withValues(alpha: 0.16),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.person,
                                          color: _equipmentSupplyStrong,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${_selectedPatient!.name.toUpperCase()}, ${_selectedPatient!.address}',
                                                style: const TextStyle(
                                                  color: _equipmentSupplyStrong,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                '${_selectedLocalBody ?? 'Unassigned local body'} • ${_selectedWard?.label ?? 'Unassigned ward'}',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  'Select a registered patient to link this supply to their patient record. For a non-patient handover, leave this empty and enter receiver details below.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                                const SizedBox(height: 16),

                                // Care Of
                                _buildTextField(
                                  controller: _careOfController,
                                  label: 'C/O (Care Of)',
                                  hint: 'Volunteer / Member Name',
                                  icon: Icons.supervised_user_circle_outlined,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            _buildSectionCard(
                              title: 'Handover & Notes',
                              icon: Icons.handshake_outlined,
                              children: [
                                if (_selectedPatient == null) ...[
                                  DropdownButtonFormField<String>(
                                    initialValue:
                                        _localBodies.contains(
                                          _selectedLocalBody,
                                        )
                                        ? _selectedLocalBody
                                        : null,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontSize: 14,
                                          fontWeight: FontWeight.normal,
                                          color: AppColors.text,
                                        ),
                                    decoration: _inputDecoration(
                                      'Local Body',
                                      Icons.location_city_outlined,
                                    ),
                                    hint: Text(
                                      'Select local body',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontSize: 14,
                                            fontWeight: FontWeight.normal,
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                    items: _localBodies
                                        .map(
                                          (value) => DropdownMenuItem(
                                            value: value,
                                            child: Text(
                                              value,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.normal,
                                                    color: AppColors.text,
                                                  ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) => setState(() {
                                      _selectedLocalBody = value;
                                      if (_selectedWard?.localBody != value) {
                                        _selectedWard = null;
                                      }
                                    }),
                                    validator: (value) => value == null
                                        ? 'Select a local body'
                                        : null,
                                  ),
                                  const SizedBox(height: 16),
                                  SearchableDropdownField<Ward>(
                                    key: ValueKey(
                                      'equipment-ward-${_selectedLocalBody ?? ''}',
                                    ),
                                    value:
                                        _wardsForLocalBody.any(
                                          (ward) =>
                                              ward.id == _selectedWard?.id,
                                        )
                                        ? _selectedWard
                                        : null,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontSize: 14,
                                          fontWeight: FontWeight.normal,
                                          color: AppColors.text,
                                        ),
                                    decoration: _inputDecoration(
                                      'Ward',
                                      Icons.map_outlined,
                                    ).copyWith(hintText: null),
                                    hintText: _selectedLocalBody == null
                                        ? 'Select local body first'
                                        : 'Select ward',
                                    dialogTitle: 'Select ward',
                                    searchHintText:
                                        'Search ward name or number',
                                    enabled: _selectedLocalBody != null,
                                    items: _wardsForLocalBody,
                                    itemLabel: (ward) => ward.label,
                                    itemSearchText: (ward) =>
                                        '${ward.label} ${ward.localBody ?? ''} ${ward.code ?? ''}',
                                    onChanged: _selectedLocalBody == null
                                        ? null
                                        : (value) => setState(
                                            () => _selectedWard = value,
                                          ),
                                    validator: (value) =>
                                        value == null ? 'Select a ward' : null,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextField(
                                        controller: _receiverNameController,
                                        label: 'Name',
                                        hint: 'Name',
                                        icon: Icons.person_pin_circle_outlined,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildTextField(
                                        controller: _receiverPhoneController,
                                        label: 'Phone',
                                        hint: 'Phone',
                                        icon: Icons.phone_outlined,
                                        keyboardType: TextInputType.phone,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextField(
                                        controller: _receiverAddressController,
                                        label: 'Address',
                                        hint: 'Address',
                                        icon: Icons.location_on_outlined,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildTextField(
                                        controller: _receiverPlaceController,
                                        label: 'Place',
                                        hint: 'Place',
                                        icon: Icons.map_outlined,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _notesController,
                                  label: 'Notes',
                                  hint: 'Any additional instructions...',
                                  icon: Icons.notes_rounded,
                                  maxLines: 2,
                                ),
                              ],
                            ),
                            const SizedBox(height: 100), // Space for bottom bar
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom Action Bar
                  Container(
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
                      child: Row(
                        children: [
                          Expanded(
                            child: AppSecondaryButton(
                              label: 'Cancel',
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            flex: 2,
                            child: AppPrimaryButton(
                              label: _selectedEquipment.length > 1
                                  ? 'Distribute ${_selectedEquipment.length} Items'
                                  : 'Confirm Distribution',
                              icon: Icons.check_circle_outline,
                              fullWidth: true,
                              loading: _submitting,
                              onPressed:
                                  _submitting ||
                                      !_availableEquipment.any(
                                        (e) => e.isAvailable,
                                      )
                                  ? null
                                  : _submit,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
        contentMaxWidth: 900,
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return AppCard(
      padding: AppInsets.card,
      surfaceLevel: AppSurfaceLevel.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: _equipmentSupplyIconSurface,
                  borderRadius: AppRadius.sm,
                ),
                child: Icon(icon, color: _equipmentSupplyStrong, size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      isDense: true,
      hintText: label,
      hintStyle: const TextStyle(color: AppColors.textSecondary),
      prefixIcon: _compactPrefixIcon(icon),
      prefixIconConstraints: const BoxConstraints(minWidth: 50, minHeight: 50),
      floatingLabelBehavior: FloatingLabelBehavior.never,
      filled: true,
      fillColor: AppColors.surface1,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      minLines: 1,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: _inputDecoration(label, icon).copyWith(hintText: hint),
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
}
