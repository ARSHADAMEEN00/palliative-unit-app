import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/models/patient.dart';
import 'package:oruma_app/models/equipment.dart';
import 'package:oruma_app/models/equipment_supply.dart';
import 'package:oruma_app/services/equipment_service.dart';
import 'package:oruma_app/services/equipment_supply_service.dart';
import 'package:oruma_app/services/patient_service.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';
import 'package:oruma_app/widgets/module_theme.dart';
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
  Equipment? _selectedEquipment;
  Patient? _selectedPatient;
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
    final purchaseDate = _selectedEquipment?.purchaseDate;
    if (purchaseDate != null) {
      return _normalizeDate(purchaseDate);
    }

    return DateTime(2000);
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
    await Future.wait([_fetchAvailableEquipment(), _fetchPatients()]);
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

  @override
  void dispose() {
    _notesController.dispose();
    _careOfController.dispose();
    _supplyDateController.dispose();
    _receiverNameController.dispose();
    _receiverPhoneController.dispose();
    _receiverAddressController.dispose();
    _receiverPlaceController.dispose();
    super.dispose();
  }

  Future<void> _fetchAvailableEquipment() async {
    try {
      final list = await EquipmentService.getAvailableEquipment();
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
    if (_selectedEquipment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 8),
              const Text('Please select a equipment'),
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

    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final supply = EquipmentSupply(
        equipmentId: _selectedEquipment!.id!,
        equipmentUniqueId: _selectedEquipment!.uniqueId,
        equipmentName: _selectedEquipment!.name,
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Equipment distributed successfully!'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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
                                  initialValue: _selectedEquipment != null
                                      ? TextEditingValue(
                                          text:
                                              '${_selectedEquipment!.uniqueId} - ${_selectedEquipment!.name}',
                                        )
                                      : null,
                                  optionsBuilder:
                                      (
                                        TextEditingValue textEditingValue,
                                      ) async {
                                        if (textEditingValue.text.isEmpty) {
                                          return _availableEquipment;
                                        }
                                        try {
                                          final searchResults =
                                              await EquipmentService.searchEquipment(
                                                textEditingValue.text,
                                                status: 'available',
                                              );
                                          return searchResults;
                                        } catch (e) {
                                          return _availableEquipment.where((
                                            equipment,
                                          ) {
                                            final searchText =
                                                '${equipment.uniqueId} ${equipment.name}'
                                                    .toLowerCase();
                                            return searchText.contains(
                                              textEditingValue.text
                                                  .toLowerCase(),
                                            );
                                          });
                                        }
                                      },
                                  displayStringForOption: (Equipment equipment) =>
                                      '${equipment.uniqueId} - ${equipment.name.toUpperCase()}',
                                  onSelected: (Equipment equipment) {
                                    setState(() {
                                      _selectedEquipment = equipment;
                                      final minimumSupplyDate =
                                          _minimumSupplyDate();
                                      if (_selectedSupplyDate.isBefore(
                                        minimumSupplyDate,
                                      )) {
                                        _setSupplyDate(minimumSupplyDate);
                                      }
                                    });
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
                                                  itemBuilder: (BuildContext context, int index) {
                                                    final Equipment equipment =
                                                        options.elementAt(
                                                          index,
                                                        );
                                                    return InkWell(
                                                      onTap: () {
                                                        onSelected(equipment);
                                                      },
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 16,
                                                              vertical: 12,
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
                                                              Icons.inventory_2,
                                                              size: 18,
                                                              color: Colors
                                                                  .grey
                                                                  .shade600,
                                                            ),
                                                            const SizedBox(
                                                              width: 12,
                                                            ),
                                                            Expanded(
                                                              child: Row(
                                                                children: [
                                                                  Container(
                                                                    padding: const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          8,
                                                                      vertical:
                                                                          2,
                                                                    ),
                                                                    decoration: BoxDecoration(
                                                                      color: Colors
                                                                          .orange
                                                                          .withValues(
                                                                            alpha:
                                                                                0.15,
                                                                          ),
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            6,
                                                                          ),
                                                                    ),
                                                                    child: Text(
                                                                      equipment
                                                                          .uniqueId,
                                                                      style: const TextStyle(
                                                                        fontSize:
                                                                            11,
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                        color: Colors
                                                                            .orange,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 8,
                                                                  ),
                                                                  Expanded(
                                                                    child: Text(
                                                                      equipment
                                                                          .name
                                                                          .toUpperCase(),
                                                                      style: const TextStyle(
                                                                        fontSize:
                                                                            14,
                                                                        fontWeight:
                                                                            FontWeight.w500,
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
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                ),
                                if (_selectedEquipment != null) ...[
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
                                          Icons.check_circle,
                                          color: _equipmentSupplyStrong,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${_selectedEquipment!.name.toUpperCase()} (${_selectedEquipment!.place})',
                                            style: const TextStyle(
                                              color: _equipmentSupplyStrong,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
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

                                // Patient Autocomplete Search
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
                                          setState(() {
                                            _selectedPatient = patient;
                                          });
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
                                                      'Search Patient',
                                                      Icons.person_outline,
                                                    ).copyWith(
                                                      hintText:
                                                          'Type to search...',
                                                    ),
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
                                                                            if (patient.phone.isNotEmpty)
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
                                          child: Text(
                                            '${_selectedPatient!.name.toUpperCase()}, ${_selectedPatient!.address}',
                                            style: const TextStyle(
                                              color: _equipmentSupplyStrong,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
                              label: 'Confirm Distribution',
                              icon: Icons.check_circle_outline,
                              fullWidth: true,
                              loading: _submitting,
                              onPressed:
                                  _submitting || _availableEquipment.isEmpty
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
