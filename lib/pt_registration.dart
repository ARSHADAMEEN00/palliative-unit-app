import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/models/patient.dart';
import 'package:oruma_app/services/patient_service.dart';
import 'package:oruma_app/services/config_service.dart';
import 'package:oruma_app/models/config.dart';
import 'package:oruma_app/models/volunteer.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/services/volunteer_service.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

const _patientCardBackground = AppColors.primarySoft;
const _patientIconBackground = AppColors.primaryLight;
const _patientPrimary = AppColors.primary;

// ignore: camel_case_types
class patientrigister extends StatefulWidget {
  final Patient? patient;
  const patientrigister({super.key, this.patient});

  @override
  State<patientrigister> createState() => _patientrigisterState();
}

// ignore: camel_case_types
class _patientrigisterState extends State<patientrigister> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoadingConfig = true;
  String? _configError;

  // Dropdown values
  String? _selectedVillage;
  List<String> _selectedDiseases = [];
  String? _selectedPlan;
  String? _gender;
  DateTime? _registrationDate;

  // Controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController relationController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController placeController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController phone2Controller = TextEditingController();
  final TextEditingController locationLinkController = TextEditingController();
  final TextEditingController volunteerNameController = TextEditingController();
  final TextEditingController volunteerContactController =
      TextEditingController();
  final TextEditingController wardController = TextEditingController();

  // Dropdown options (loaded from API)
  List<String> villages = [];
  List<String> diseases = [];
  List<String> plans = [];
  List<WardConfig> allWards = [];
  List<String> filteredWards = [];
  List<Volunteer> volunteers = [];
  Volunteer? _selectedVolunteer;
  String? _selectedWardTitle;
  int _volunteerFieldVersion = 0;

  @override
  void initState() {
    super.initState();
    // Set default registration date to today at noon
    final now = DateTime.now();
    _registrationDate = DateTime(now.year, now.month, now.day, 12, 0, 0);

    // Load configuration data
    _loadConfig();

    if (widget.patient != null) {
      nameController.text = CapitalizeWordsInputFormatter.capitalizeWords(
        widget.patient!.name,
      );
      relationController.text = widget.patient!.relation;
      addressController.text = widget.patient!.address;
      ageController.text = widget.patient!.age.toString();
      placeController.text = widget.patient!.place;
      phoneController.text = widget.patient!.phone;
      phone2Controller.text = widget.patient!.phone2 ?? '';
      locationLinkController.text = widget.patient!.locationLink ?? '';
      volunteerNameController.text = widget.patient!.volunteerName ?? '';
      volunteerContactController.text = widget.patient!.volunteerContact ?? '';
      _gender = widget.patient!.gender;
      _selectedVillage = widget.patient!.village;
      _selectedWardTitle = widget.patient!.ward;
      _selectedDiseases = List.from(widget.patient!.disease);
      _selectedPlan = widget.patient!.plan;

      // Normalize existing registration date to noon if it exists
      if (widget.patient!.registrationDate != null) {
        final regDate = widget.patient!.registrationDate!;
        _registrationDate = DateTime(
          regDate.year,
          regDate.month,
          regDate.day,
          12,
          0,
          0,
        );
      }
    }
  }

  Future<void> _loadConfig() async {
    try {
      final config = await ConfigService.getConfig();
      final loadedVolunteers = await _loadVolunteersSafely();
      final initialVolunteer = _findInitialVolunteer(loadedVolunteers);
      setState(() {
        villages = config.villages;
        diseases = config.diseases;
        plans = config.plans;
        allWards = sortWardConfigs(config.wards);
        volunteers = loadedVolunteers;
        _selectedVolunteer = initialVolunteer;
        if (initialVolunteer != null) {
          volunteerNameController.text = initialVolunteer.name;
          volunteerContactController.text = initialVolunteer.phone;
        }
        _updateFilteredWards();
        _isLoadingConfig = false;
      });
    } catch (e) {
      setState(() {
        _configError = e.toString();
        _isLoadingConfig = false;
      });
    }
  }

  Future<List<Volunteer>> _loadVolunteersSafely() async {
    try {
      return await VolunteerService.getVolunteers();
    } catch (_) {
      return const <Volunteer>[];
    }
  }

  Volunteer? _findInitialVolunteer(List<Volunteer> list) {
    final patient = widget.patient;
    if (patient == null) return null;

    final volunteerId = patient.volunteerId;
    if (volunteerId?.trim().isNotEmpty == true) {
      for (final volunteer in list) {
        if (volunteer.id == volunteerId) return volunteer;
      }
    }

    final name = patient.volunteerName?.trim().toLowerCase();
    final phone = patient.volunteerContact?.trim();
    if ((name == null || name.isEmpty) && (phone == null || phone.isEmpty)) {
      return null;
    }

    for (final volunteer in list) {
      final sameName =
          name == null ||
          name.isEmpty ||
          volunteer.name.trim().toLowerCase() == name;
      final samePhone =
          phone == null ||
          phone.isEmpty ||
          volunteer.phone.trim() == phone ||
          volunteer.phone2.trim() == phone;
      if (sameName && samePhone) return volunteer;
    }
    return null;
  }

  void _updateFilteredWards() {
    if (_selectedVillage == null) {
      filteredWards = [];
    } else {
      filteredWards =
          allWards
              .where((w) => w.village == _selectedVillage)
              .map((w) => w.number)
              .toList()
            ..sort(compareWardNumbers);
    }
    // If current selected ward is not in the filtered list, clear it
    if (_selectedWardTitle != null &&
        !filteredWards.contains(_selectedWardTitle)) {
      _selectedWardTitle = null;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    relationController.dispose();
    addressController.dispose();
    ageController.dispose();
    placeController.dispose();
    phoneController.dispose();
    phone2Controller.dispose();
    locationLinkController.dispose();
    volunteerNameController.dispose();
    volunteerContactController.dispose();
    wardController.dispose();
    super.dispose();
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      isDense: true,
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      prefixIcon: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _patientIconBackground,
          borderRadius: AppRadius.sm,
        ),
        child: Icon(icon, size: AppIcons.normal, color: _patientPrimary),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 50, minHeight: 50),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
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
        borderSide: const BorderSide(color: _patientPrimary, width: 1.4),
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
        vertical: AppSpacing.sm,
      ),
    );
  }

  Future<void> _pickRegistrationDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _registrationDate ?? now,
      firstDate: DateTime(2020), // Allow backdating to 2020
      lastDate: now, // Can't select future dates
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _patientPrimary,
              onPrimary: Colors.white,
              onSurface: AppColors.text,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      // Normalize to noon to avoid timezone conversion issues
      // This ensures the date doesn't shift when converting to UTC
      final normalizedDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        12, // Set to noon
        0,
        0,
      );
      setState(() => _registrationDate = normalizedDate);
    }
  }

  Future<void> _showAddWardDialog() async {
    final TextEditingController newWardController = TextEditingController();
    String? popupSelectedVillage = _selectedVillage;
    bool isSaving = false;

    try {
      await showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setStateBuilder) {
              return AlertDialog(
                backgroundColor: AppColors.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.dialog,
                ),
                title: _DialogTitle(
                  icon: Icons.map_outlined,
                  title: 'Add ward',
                  subtitle: 'Create a ward under the selected village.',
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: _buildInputDecoration(
                        "Village",
                        Icons.location_city,
                      ),
                      initialValue: popupSelectedVillage,
                      style: AppTypography.dropdownTextStyle(context),
                      items: villages
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: (v) {
                        setStateBuilder(() {
                          popupSelectedVillage = v;
                        });
                      },
                      hint: const Text("Select Village"),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: newWardController,
                      decoration: _buildInputDecoration(
                        'Ward Number',
                        Icons.tag_outlined,
                      ).copyWith(hintText: 'e.g. 1'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      autofocus: true,
                    ),
                  ],
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
                    label: 'Add',
                    icon: Icons.add,
                    loading: isSaving,
                    onPressed: (isSaving || popupSelectedVillage == null)
                        ? null
                        : () async {
                            final newWardNumber = normalizeWardNumberValue(
                              newWardController.text,
                            );
                            if (newWardNumber.isEmpty) return;

                            setStateBuilder(() => isSaving = true);

                            try {
                              final config = await ConfigService.getConfig();
                              final exists = config.wards.any(
                                (w) =>
                                    w.number == newWardNumber &&
                                    w.village == popupSelectedVillage,
                              );

                              if (!exists) {
                                config.wards.add(
                                  WardConfig(
                                    number: newWardNumber,
                                    village: popupSelectedVillage!,
                                  ),
                                );
                                await ConfigService.updateConfig(config);
                              }

                              setState(() {
                                if (!allWards.any(
                                  (w) =>
                                      w.number == newWardNumber &&
                                      w.village == popupSelectedVillage,
                                )) {
                                  allWards = sortWardConfigs([
                                    ...allWards,
                                    WardConfig(
                                      number: newWardNumber,
                                      village: popupSelectedVillage!,
                                    ),
                                  ]);
                                }
                                // If we added it for the currently selected village in the main form,
                                // update the filtered list and select it. Otherwise just refresh.
                                if (_selectedVillage == popupSelectedVillage) {
                                  _updateFilteredWards();
                                  _selectedWardTitle = newWardNumber;
                                }
                              });

                              if (context.mounted) Navigator.pop(context);
                            } catch (e) {
                              setStateBuilder(() => isSaving = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to add ward: $e'),
                                    backgroundColor: AppColors.danger,
                                  ),
                                );
                              }
                            }
                          },
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      newWardController.dispose();
    }
  }

  Future<void> _showAddDiseaseDialog() async {
    final TextEditingController newDiseaseController = TextEditingController();
    bool isSaving = false;

    try {
      await showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setStateBuilder) {
              return AlertDialog(
                backgroundColor: AppColors.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.dialog,
                ),
                title: _DialogTitle(
                  icon: Icons.medical_information_outlined,
                  title: 'Add disease',
                  subtitle: 'Add it once and reuse it across patient records.',
                ),
                content: TextField(
                  controller: newDiseaseController,
                  decoration: _buildInputDecoration(
                    'Disease Name',
                    Icons.medical_services_outlined,
                  ).copyWith(hintText: 'e.g. ASTHMA'),
                  textCapitalization: TextCapitalization.characters,
                  autofocus: true,
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
                    label: 'Add',
                    icon: Icons.add,
                    loading: isSaving,
                    onPressed: isSaving
                        ? null
                        : () async {
                            final newDisease = newDiseaseController.text
                                .trim()
                                .toUpperCase();
                            if (newDisease.isEmpty) return;

                            setStateBuilder(() => isSaving = true);

                            try {
                              // Fetch current config to update it
                              final config = await ConfigService.getConfig();
                              if (!config.diseases.contains(newDisease)) {
                                config.diseases.add(newDisease);
                                await ConfigService.updateConfig(config);
                              }

                              // Update the local state
                              setState(() {
                                if (!diseases.contains(newDisease)) {
                                  diseases.add(newDisease);
                                }
                                if (!_selectedDiseases.contains(newDisease)) {
                                  _selectedDiseases.add(newDisease);
                                }
                              });

                              if (context.mounted) Navigator.pop(context);
                            } catch (e) {
                              setStateBuilder(() => isSaving = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to add disease: $e'),
                                    backgroundColor: AppColors.danger,
                                  ),
                                );
                              }
                            }
                          },
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      newDiseaseController.dispose();
    }
  }

  PreferredSizeWidget _buildRegistrationAppBar(bool isEditing) {
    return AppBar(
      toolbarHeight: 72,
      titleSpacing: AppSpacing.md,
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(
        isEditing ? "Edit Patient" : "New Patient",
        style: Theme.of(context).textTheme.titleLarge,
      ),
      centerTitle: false,
    );
  }

  Widget _registrationDateCard() {
    return AppCard(
      padding: AppInsets.card,
      surfaceLevel: AppSurfaceLevel.elevated,
      onTap: _pickRegistrationDate,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: _patientIconBackground,
              borderRadius: AppRadius.md,
            ),
            child: const Icon(
              Icons.calendar_today_outlined,
              color: _patientPrimary,
              size: AppIcons.large,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registration Date',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  _registrationDate == null
                      ? 'Select date'
                      : DateFormat(
                          'EEEE, d MMMM yyyy',
                        ).format(_registrationDate!),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.patient != null;
    final canManageConfig = context.watch<AuthService>().isAdmin;

    // Show loading indicator while config is loading
    if (_isLoadingConfig) {
      return AdaptiveAppScaffold(
        backgroundColor: AppColors.background,
        appBar: _buildRegistrationAppBar(isEditing),
        body: const AppListSkeleton(itemCount: 4),
        contentMaxWidth: 900,
      );
    }

    // Show error if config failed to load
    if (_configError != null) {
      return AdaptiveAppScaffold(
        backgroundColor: AppColors.background,
        appBar: _buildRegistrationAppBar(isEditing),
        body: AppEmptyState(
          icon: Icons.error_outline,
          title: 'Failed to load configuration',
          message: _configError!,
          action: AppPrimaryButton(
            label: 'Retry',
            icon: Icons.refresh,
            onPressed: () {
              setState(() {
                _isLoadingConfig = true;
                _configError = null;
              });
              _loadConfig();
            },
          ),
        ),
        contentMaxWidth: 900,
      );
    }

    return AdaptiveAppScaffold(
      backgroundColor: AppColors.background,
      appBar: _buildRegistrationAppBar(isEditing),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _registrationDateCard(),
              const SizedBox(height: AppSpacing.lg),
              _buildSectionCard(
                title: "Basic Information",
                icon: Icons.person_outline,
                children: [
                  TextFormField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: const [
                      CapitalizeWordsInputFormatter(),
                    ],
                    decoration: _buildInputDecoration(
                      "Patient Name",
                      Icons.person,
                    ),
                    validator: (val) =>
                        val == null || val.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: 180,
                    child: TextFormField(
                      controller: ageController,
                      keyboardType: TextInputType.number,
                      decoration: _buildInputDecoration(
                        "Age",
                        Icons.calendar_today,
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return "Required";
                        if (int.tryParse(val) == null) return "Invalid";
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    "Gender",
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: ["Male", "Female", "Other"].map((g) {
                      final isSelected = _gender == g;
                      return ChoiceChip(
                        label: Text(g),
                        selected: isSelected,
                        showCheckmark: false,
                        selectedColor: _patientPrimary,
                        backgroundColor: AppColors.surface1,
                        side: BorderSide(
                          color: isSelected
                              ? _patientPrimary
                              : AppColors.border,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.button,
                        ),
                        labelStyle: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: isSelected
                                  ? AppColors.textInverse
                                  : AppColors.text,
                              fontWeight: FontWeight.w600,
                            ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        onSelected: (selected) {
                          setState(() {
                            _gender = selected ? g : null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  if (_gender == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        "Please select a gender",
                        style: TextStyle(color: AppColors.danger, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    "Diseases",
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      ...diseases.map((disease) {
                        final isSelected = _selectedDiseases.contains(disease);
                        return FilterChip(
                          label: Text(disease),
                          selected: isSelected,
                          selectedColor: _patientPrimary,
                          backgroundColor: AppColors.surface1,
                          checkmarkColor: AppColors.textInverse,
                          side: BorderSide(
                            color: isSelected
                                ? _patientPrimary
                                : AppColors.border,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.button,
                          ),
                          labelStyle: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: isSelected
                                    ? AppColors.textInverse
                                    : AppColors.text,
                                fontWeight: FontWeight.w600,
                              ),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedDiseases.add(disease);
                              } else {
                                _selectedDiseases.remove(disease);
                              }
                            });
                          },
                        );
                      }),
                      if (canManageConfig)
                        ActionChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.add,
                                size: AppIcons.small,
                                color: _patientPrimary,
                              ),
                              const SizedBox(width: AppSpacing.xxs),
                              Text(
                                'Other',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: _patientPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                          backgroundColor: _patientCardBackground,
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.button,
                            side: BorderSide(color: _patientIconBackground),
                          ),
                          onPressed: _showAddDiseaseDialog,
                        ),
                    ],
                  ),
                  if (_selectedDiseases.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        "Please select at least one disease",
                        style: TextStyle(color: AppColors.danger, fontSize: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildSectionCard(
                title: "Contact Details",
                icon: Icons.contact_phone_outlined,
                children: [
                  TextFormField(
                    controller: addressController,
                    minLines: 1,
                    maxLines: 3,
                    decoration: _buildInputDecoration(
                      "Full Address",
                      Icons.home_outlined,
                    ),
                    validator: (val) =>
                        val == null || val.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: _buildInputDecoration(
                      "Phone Number",
                      Icons.phone,
                    ),
                    validator: (val) =>
                        val == null || val.isEmpty ? "Required" : null,
                  ),

                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: relationController,
                    decoration: _buildInputDecoration(
                      "Caregiver/Relation",
                      Icons.people_outline,
                    ),
                    validator: (val) =>
                        val == null || val.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: phone2Controller,
                    keyboardType: TextInputType.phone,
                    decoration: _buildInputDecoration(
                      "Caregiver Phone Number",
                      Icons.phone_android,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildSectionCard(
                title: "Location & Care Plan",
                icon: Icons.map_outlined,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: _buildInputDecoration(
                      "Village",
                      Icons.location_city,
                    ),
                    key: ValueKey(_selectedVillage),
                    initialValue: _selectedVillage,
                    style: AppTypography.dropdownTextStyle(context),
                    items: villages
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedVillage = v;
                        _updateFilteredWards();
                      });
                    },
                    validator: (val) => val == null ? "Required" : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: _buildInputDecoration(
                            "Ward Number",
                            Icons.apartment,
                          ),
                          key: ValueKey(
                            '${_selectedVillage ?? ''}:${_selectedWardTitle ?? ''}:${filteredWards.length}',
                          ),
                          initialValue: _selectedWardTitle,
                          style: AppTypography.dropdownTextStyle(context),
                          hint: const Text("Select Ward Number"),
                          items: filteredWards
                              .map(
                                (w) => DropdownMenuItem(
                                  value: w,
                                  child: Text("Ward $w"),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedWardTitle = v),
                        ),
                      ),
                      if (canManageConfig) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Tooltip(
                          message: 'Add New Ward',
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Material(
                              color: AppColors.primaryLight,
                              borderRadius: AppRadius.md,
                              child: InkWell(
                                borderRadius: AppRadius.md,
                                onTap: _showAddWardDialog,
                                child: const SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Icon(
                                    Icons.add,
                                    color: _patientPrimary,
                                    size: AppIcons.large,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: placeController,
                    decoration: _buildInputDecoration("Place", Icons.place),
                    validator: (val) =>
                        val == null || val.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: locationLinkController,
                    decoration: _buildInputDecoration(
                      "Location Link (Google Maps)",
                      Icons.map,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _volunteerSelector(),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    decoration: _buildInputDecoration(
                      "Care Plan",
                      Icons.assignment_outlined,
                    ),
                    initialValue: _selectedPlan,
                    style: AppTypography.dropdownTextStyle(context),
                    items: plans
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedPlan = v),
                    validator: (val) => val == null ? "Required" : null,
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
        decoration: BoxDecoration(
          color: AppColors.surfaceFloating,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: AppShadow.medium,
        ),
        child: SafeArea(
          top: false,
          child: AppPrimaryButton(
            label: isEditing ? "Update Patient" : "Register Patient",
            icon: isEditing ? Icons.save_outlined : Icons.person_add_alt_1,
            fullWidth: true,
            loading: _isLoading,
            onPressed: _isLoading ? null : _handleSubmit,
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
                decoration: BoxDecoration(
                  color: _patientIconBackground,
                  borderRadius: AppRadius.sm,
                ),
                child: Icon(
                  icon,
                  color: _patientPrimary,
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

  Widget _volunteerSelector() {
    if (volunteers.isEmpty) {
      return Container(
        padding: AppInsets.md,
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: AppRadius.input,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.volunteer_activism_outlined,
              color: _patientPrimary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                "No volunteers added yet",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Autocomplete<Volunteer>(
          key: ValueKey(
            'patient-volunteer-autocomplete-$_volunteerFieldVersion',
          ),
          displayStringForOption: _volunteerLabel,
          optionsBuilder: (textEditingValue) {
            final query = textEditingValue.text.trim().toLowerCase();
            if (query.isEmpty) return volunteers;
            return volunteers.where((volunteer) => volunteer.matches(query));
          },
          onSelected: (volunteer) {
            setState(() {
              _selectedVolunteer = volunteer;
              volunteerNameController.text = volunteer.name;
              volunteerContactController.text = volunteer.phone;
            });
          },
          fieldViewBuilder:
              (context, controller, focusNode, onEditingComplete) {
                if (_selectedVolunteer != null) {
                  final selectedLabel = _volunteerLabel(_selectedVolunteer!);
                  if (controller.text != selectedLabel) {
                    controller.value = TextEditingValue(
                      text: selectedLabel,
                      selection: TextSelection.collapsed(
                        offset: selectedLabel.length,
                      ),
                    );
                  }
                }
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  onEditingComplete: onEditingComplete,
                  onChanged: (value) {
                    final selected = _selectedVolunteer;
                    setState(() {
                      if (selected != null &&
                          value.trim() != _volunteerLabel(selected)) {
                        _selectedVolunteer = null;
                        volunteerNameController.clear();
                        volunteerContactController.clear();
                      }
                    });
                  },
                  decoration: _buildInputDecoration(
                    "Volunteer",
                    Icons.volunteer_activism_outlined,
                  ).copyWith(hintText: "Search volunteer"),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) return null;
                    return _selectedVolunteer == null
                        ? 'Select an existing volunteer'
                        : null;
                  },
                );
              },
        ),
        if (_selectedVolunteer != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _selectedVolunteerCard(),
        ],
      ],
    );
  }

  Widget _selectedVolunteerCard() {
    final volunteer = _selectedVolunteer!;
    return Container(
      padding: AppInsets.md,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: AppRadius.md,
        border: Border.all(color: _patientIconBackground),
      ),
      child: Row(
        children: [
          const Icon(Icons.badge_outlined, color: _patientPrimary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  volunteer.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: _patientPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  [
                    volunteer.phone,
                    if (volunteer.phone2.trim().isNotEmpty) volunteer.phone2,
                    volunteer.locationLabel,
                  ].join(' - '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Clear volunteer',
            onPressed: () {
              setState(() {
                _selectedVolunteer = null;
                _volunteerFieldVersion++;
                volunteerNameController.clear();
                volunteerContactController.clear();
              });
            },
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  String _volunteerLabel(Volunteer volunteer) {
    final details = [
      if (volunteer.phone.isNotEmpty) volunteer.phone,
      if (volunteer.phone2.isNotEmpty) volunteer.phone2,
      if (volunteer.place.isNotEmpty) volunteer.place,
      if (volunteer.ward.isNotEmpty) 'Ward\u00A0${volunteer.ward}',
    ].join(' - ');
    return details.isEmpty ? volunteer.name : '${volunteer.name} - $details';
  }

  Future<void> _handleSubmit() async {
    final isValid = _formKey.currentState!.validate();
    final genderSelected = _gender != null;

    // Trigger rebuild to show gender error if needed
    if (!genderSelected) setState(() {});

    if (isValid && genderSelected && _selectedDiseases.isNotEmpty) {
      setState(() => _isLoading = true);

      try {
        final patientData = Patient(
          id: widget.patient?.id,
          name: CapitalizeWordsInputFormatter.capitalizeWords(
            nameController.text.trim(),
          ),
          relation: relationController.text,
          gender: _gender!,
          address: addressController.text,
          phone: phoneController.text,
          phone2: phone2Controller.text.trim().isEmpty
              ? null
              : phone2Controller.text.trim(),
          age: int.parse(ageController.text),
          place: placeController.text,
          village: _selectedVillage!,
          ward: _selectedWardTitle == null
              ? null
              : normalizeWardNumberValue(_selectedWardTitle),
          locationLink: locationLinkController.text.trim().isEmpty
              ? null
              : locationLinkController.text.trim(),
          volunteerName: _selectedVolunteer?.name,
          volunteerContact: _selectedVolunteer?.phone,
          volunteerId: _selectedVolunteer?.id,
          disease: _selectedDiseases,
          plan: _selectedPlan!,
          registerId: widget.patient?.registerId,
          registrationDate: _registrationDate,
        );

        if (widget.patient != null) {
          var updated = await PatientService.updatePatient(
            widget.patient!.id!,
            patientData,
          );

          // Optimistic update: If API response lacks locationLink but we sent it, preserve it
          if (updated.locationLink == null &&
              patientData.locationLink != null) {
            updated = updated.copyWith(locationLink: patientData.locationLink);
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Patient updated successfully"),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.pop(context, updated);
          }
        } else {
          await PatientService.createPatient(patientData);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Patient registered successfully"),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.pop(context, true);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed: ${e.toString()}"),
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
  }
}

class _DialogTitle extends StatelessWidget {
  const _DialogTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: AppRadius.md,
          ),
          child: Icon(icon, color: AppColors.primary, size: AppIcons.large),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CapitalizeWordsInputFormatter extends TextInputFormatter {
  const CapitalizeWordsInputFormatter();

  static String capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text.replaceAllMapped(
      RegExp(r'\b[a-z]'),
      (match) => match.group(0)!.toUpperCase(),
    );
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final formattedText = capitalizeWords(newValue.text);
    if (formattedText == newValue.text) {
      return newValue;
    }

    return newValue.copyWith(
      text: formattedText,
      selection: newValue.selection,
    );
  }
}
