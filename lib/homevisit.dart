import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/models/home_visit.dart';
import 'package:oruma_app/models/patient.dart';
import 'package:oruma_app/services/home_visit_service.dart';
import 'package:oruma_app/services/patient_service.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';
import 'package:intl/intl.dart';

const _homeVisitIconBackground = Color(0xFFDCFCE7);
const _homeVisitPrimary = AppColors.success;

class Homevisit extends StatefulWidget {
  final HomeVisit? visit;
  final DateTime? initialDate;

  const Homevisit({super.key, this.visit, this.initialDate});

  @override
  State<Homevisit> createState() => _HomevisitState();
}

class _HomevisitState extends State<Homevisit> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController addressController;
  late TextEditingController teamController;
  late TextEditingController notesController;
  DateTime? visitDate;
  bool _isLoading = false;

  // Patient selection fields
  List<Patient> _patients = [];
  Patient? _selectedPatient;
  bool _isLoadingPatients = true;

  // Visit mode options
  String _selectedVisitMode = 'new';
  final List<Map<String, String>> _visitModeOptions = [
    {'value': 'new', 'label': 'New'},
    {'value': 'monthly', 'label': 'Planned NHC'},
    {'value': 'emergency', 'label': 'Emergency'},
    {'value': 'dhc_visit', 'label': 'DHC'},
    {'value': 'vhc_visit', 'label': 'VHC'},
  ];

  bool get isEditing => widget.visit != null;

  @override
  void initState() {
    super.initState();
    addressController = TextEditingController(
      text: widget.visit?.address ?? '',
    );
    teamController = TextEditingController(text: widget.visit?.team ?? '');
    notesController = TextEditingController(text: widget.visit?.notes ?? '');
    if (widget.visit?.visitDate != null) {
      visitDate = DateTime.tryParse(widget.visit!.visitDate);
    } else if (widget.initialDate != null) {
      visitDate = widget.initialDate;
    }
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingPatients = true);
    try {
      final patients = await PatientService.getAllPatients(isDead: false);
      setState(() {
        _patients = patients;
        _isLoadingPatients = false;

        // If editing, try to find the matching patient and visit mode
        if (isEditing) {
          try {
            _selectedPatient = _patients.firstWhere(
              (p) => p.name == widget.visit!.patientName,
            );
          } catch (_) {
            // If not found (maybe name changed or deleted), we'll handle it
            _selectedPatient = null;
          }
          // Set visit mode from existing visit
          if (widget.visit!.visitMode.isNotEmpty) {
            _selectedVisitMode = widget.visit!.visitMode;
          }
        }
      });
    } catch (e) {
      setState(() => _isLoadingPatients = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load patients: $e')));
      }
    }
  }

  @override
  void dispose() {
    addressController.dispose();
    teamController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: visitDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _homeVisitPrimary,
              onPrimary: Colors.white,
              onSurface: AppColors.text,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => visitDate = picked);
    }
  }

  Future<void> _saveVisit() async {
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or create a patient'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (visitDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a visit date'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final homeVisit = HomeVisit(
        id: widget.visit?.id,
        patientId: _selectedPatient!.id,
        patientName: _selectedPatient!.name,
        address: addressController.text.trim(),
        visitDate: visitDate!.toIso8601String(),
        visitMode: _selectedVisitMode,
        team: teamController.text.trim().isNotEmpty
            ? teamController.text.trim()
            : null,
        notes: notesController.text.trim().isNotEmpty
            ? notesController.text.trim()
            : null,
      );

      if (isEditing) {
        await HomeVisitService.updateHomeVisit(widget.visit!.id!, homeVisit);
      } else {
        await HomeVisitService.createHomeVisit(homeVisit);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? 'Visit updated successfully'
                  : 'Visit scheduled successfully',
            ),
            backgroundColor: _homeVisitPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveAppScaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: AppSpacing.md,
        title: Text(
          isEditing ? 'Edit Home Visit' : 'Schedule Visit',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
      ),
      body: _isLoadingPatients
          ? const AppListSkeleton(itemCount: 4)
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppInsets.screenHorizontal(context),
                AppSpacing.md,
                AppInsets.screenHorizontal(context),
                112,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionCard(
                      title: 'Patient Information',
                      icon: Icons.person_search_outlined,
                      children: [
                        _buildPatientAutocomplete(),
                        const SizedBox(height: AppSpacing.md),
                        _buildTextField(
                          controller: addressController,
                          label: 'Address',
                          icon: Icons.location_on_outlined,
                          minLines: 1,
                          maxLines: 3,
                          validator: (val) => val == null || val.isEmpty
                              ? 'Please enter address'
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _buildSectionCard(
                      title: 'Visit Details',
                      icon: Icons.home_work_outlined,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _selectedVisitMode,
                          style: Theme.of(context).textTheme.bodyMedium,
                          decoration: _buildInputDecoration(
                            'Visit Mode',
                            Icons.medical_services_outlined,
                          ),
                          items: _visitModeOptions
                              .map(
                                (option) => DropdownMenuItem(
                                  value: option['value'],
                                  child: Row(
                                    children: [
                                      Icon(
                                        _visitModeIcon(option['value']!),
                                        size: AppIcons.normal,
                                        color: _visitModeColor(
                                          option['value']!,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      Text(option['label']!),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedVisitMode = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildVisitDateField(),
                        const SizedBox(height: AppSpacing.md),
                        _buildTextField(
                          controller: teamController,
                          label: 'Team',
                          icon: Icons.group_outlined,
                          required: false,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildTextField(
                          controller: notesController,
                          label: 'Notes / Special Requests',
                          icon: Icons.notes_outlined,
                          minLines: 1,
                          maxLines: 3,
                          required: false,
                        ),
                      ],
                    ),
                  ],
                ),
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
            label: isEditing ? 'Update Visit' : 'Schedule Visit',
            icon: isEditing ? Icons.save_outlined : Icons.add_home_outlined,
            fullWidth: true,
            loading: _isLoading,
            onPressed: _isLoading ? null : _saveVisit,
          ),
        ),
      ),
      contentMaxWidth: 900,
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
                  color: _homeVisitIconBackground,
                  borderRadius: AppRadius.sm,
                ),
                child: Icon(
                  icon,
                  color: _homeVisitPrimary,
                  size: AppIcons.normal,
                ),
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

  Widget _buildPatientAutocomplete() {
    return Autocomplete<Patient>(
      initialValue: _selectedPatient != null
          ? TextEditingValue(text: _selectedPatient!.name)
          : null,
      optionsBuilder: (TextEditingValue textEditingValue) async {
        if (textEditingValue.text.isEmpty) {
          return _patients;
        }
        try {
          return PatientService.searchPatients(
            textEditingValue.text,
            isDead: false,
          );
        } catch (e) {
          return _patients.where((patient) {
            return patient.name.toLowerCase().contains(
              textEditingValue.text.toLowerCase(),
            );
          });
        }
      },
      displayStringForOption: (Patient patient) => patient.name,
      onSelected: (Patient patient) {
        setState(() {
          _selectedPatient = patient;
          addressController.text = patient.address;
        });
      },
      fieldViewBuilder:
          (
            BuildContext context,
            TextEditingController textEditingController,
            FocusNode focusNode,
            VoidCallback onFieldSubmitted,
          ) {
            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: _buildInputDecoration(
                'Search Patient',
                Icons.person_search_outlined,
              ),
              onFieldSubmitted: (String value) {
                onFieldSubmitted();
              },
            );
          },
      optionsViewBuilder:
          (
            BuildContext context,
            AutocompleteOnSelected<Patient> onSelected,
            Iterable<Patient> options,
          ) {
            return Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Material(
                  color: AppColors.surface,
                  elevation: 0,
                  borderRadius: AppRadius.card,
                  child: Container(
                    constraints: const BoxConstraints(
                      maxHeight: 240,
                      maxWidth: 420,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.card,
                      border: Border.all(color: AppColors.border),
                      boxShadow: AppShadow.medium,
                    ),
                    child: ListView.separated(
                      padding: AppInsets.xs,
                      shrinkWrap: true,
                      itemCount: options.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: AppColors.borderSoft),
                      itemBuilder: (BuildContext context, int index) {
                        final Patient patient = options.elementAt(index);
                        return InkWell(
                          onTap: () => onSelected(patient),
                          borderRadius: AppRadius.md,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: const BoxDecoration(
                                    color: _homeVisitIconBackground,
                                    borderRadius: AppRadius.sm,
                                  ),
                                  child: const Icon(
                                    Icons.person_outline,
                                    size: AppIcons.small,
                                    color: _homeVisitPrimary,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              patient.name,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleSmall,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (patient.registerId != null)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryLight,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                '#${patient.registerId}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: AppColors.primary,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (patient.phone.isNotEmpty)
                                        Text(
                                          patient.phone,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors.textSecondary,
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
    );
  }

  Widget _buildVisitDateField() {
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.input,
      child: InkWell(
        borderRadius: AppRadius.input,
        onTap: _pickDate,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: AppRadius.input,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _themedPrefixIcon(Icons.calendar_today_outlined),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  visitDate == null
                      ? 'Select Visit Date'
                      : DateFormat('EEEE, d MMMM yyyy').format(visitDate!),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: visitDate == null
                        ? AppColors.textSecondary
                        : AppColors.text,
                  ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      isDense: true,
      hintText: label,
      hintStyle: const TextStyle(color: AppColors.textSecondary),
      prefixIcon: _themedPrefixIcon(icon),
      prefixIconConstraints: const BoxConstraints(minWidth: 50, minHeight: 50),
      floatingLabelBehavior: FloatingLabelBehavior.never,
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
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
    );
  }

  IconData _visitModeIcon(String value) {
    return switch (value) {
      'emergency' => Icons.emergency_outlined,
      'monthly' => Icons.calendar_month_outlined,
      'dhc_visit' => Icons.home_work_outlined,
      'vhc_visit' => Icons.local_hospital_outlined,
      _ => Icons.add_circle_outline,
    };
  }

  Color _visitModeColor(String value) {
    return switch (value) {
      'emergency' => AppColors.danger,
      'monthly' => AppColors.primary,
      'dhc_visit' => AppColors.warning,
      'vhc_visit' => AppColors.scheduled,
      _ => AppColors.success,
    };
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int minLines = 1,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      validator: validator,
      decoration: _buildInputDecoration(label, icon),
    );
  }

  Widget _themedPrefixIcon(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      margin: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: _homeVisitIconBackground,
        borderRadius: AppRadius.sm,
      ),
      child: Icon(icon, size: AppIcons.normal, color: _homeVisitPrimary),
    );
  }
}
