import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/models/patient.dart';
import 'package:oruma_app/models/social_support.dart';
import 'package:oruma_app/models/volunteer.dart';
import 'package:oruma_app/services/patient_service.dart';
import 'package:oruma_app/services/social_support_service.dart';
import 'package:oruma_app/services/volunteer_service.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';

const _supportPrimary = Color(0xFFBE185D);
const _supportCard = Color(0xFFFDF2F8);
const _supportIcon = Color(0xFFFCE7F3);

class SocialSupportPage extends StatefulWidget {
  final Patient? initialPatient;

  const SocialSupportPage({super.key, this.initialPatient});

  @override
  State<SocialSupportPage> createState() => _SocialSupportPageState();
}

class _SocialSupportPageState extends State<SocialSupportPage> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();

  List<Patient> _patients = [];
  List<Volunteer> _volunteers = [];
  Patient? _selectedPatient;
  Volunteer? _selectedVolunteer;
  DateTime _givenAt = DateTime.now();
  bool _loading = true;
  bool _saving = false;

  final Set<String> _selectedTypes = {'ration_kit'};
  final List<String> _supportTypes = const [
    'ration_kit',
    'vegetables',
    'medicine',
  ];

  @override
  void initState() {
    super.initState();
    _selectedPatient = widget.initialPatient;
    _loadPatients();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    try {
      final patients = await PatientService.getAllPatients(isDead: false);
      final volunteers = await _loadVolunteersSafely();
      final initialVolunteer = _findPatientVolunteer(
        widget.initialPatient,
        volunteers,
      );
      if (!mounted) return;
      setState(() {
        _patients = patients;
        _volunteers = volunteers;
        _selectedVolunteer = initialVolunteer;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(error)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<List<Volunteer>> _loadVolunteersSafely() async {
    try {
      return await VolunteerService.getVolunteers();
    } catch (_) {
      return const <Volunteer>[];
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _givenAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _supportPrimary,
              onPrimary: AppColors.textInverse,
              onSurface: AppColors.text,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(
        () => _givenAt = DateTime(picked.year, picked.month, picked.day),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPatient?.id == null || _selectedPatient!.id!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a patient'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_selectedVolunteer?.id == null || _selectedVolunteer!.id!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a volunteer'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_selectedTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one support type'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await SocialSupportService.createSocialSupport(
        SocialSupport(
          patientId: _selectedPatient!.id,
          supportTypes: _selectedTypes.toList(),
          givenAt: _givenAt,
          note: _blankToNull(_noteController.text),
          volunteerId: _selectedVolunteer!.id,
          volunteerName: _selectedVolunteer!.name,
          volunteerContact: _selectedVolunteer!.phone,
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Social support recorded successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(error)),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return AdaptiveAppScaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          toolbarHeight: 72,
          titleSpacing: AppSpacing.md,
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.text,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            'New Social Support',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        body: const AppListSkeleton(itemCount: 4),
        contentMaxWidth: 900,
      );
    }

    return AdaptiveAppScaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: AppSpacing.md,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'New Social Support',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppInsets.screenHorizontal(context),
            AppSpacing.md,
            AppInsets.screenHorizontal(context),
            112,
          ),
          children: [
            _formCard(
              title: 'Patient and date',
              icon: Icons.person_search_outlined,
              children: [
                _patientAutocomplete(),
                if (_selectedPatient != null) _selectedPatientCard(),
                _dateField(),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _formCard(
              title: 'Support type',
              icon: Icons.volunteer_activism_outlined,
              children: [_supportTypeSelector()],
            ),
            const SizedBox(height: AppSpacing.lg),
            _formCard(
              title: 'Volunteer details',
              icon: Icons.badge_outlined,
              children: [
                _volunteerAutocomplete(),
                if (_selectedVolunteer != null) _selectedVolunteerCard(),
                _textField(
                  _noteController,
                  'Note',
                  hint: 'Optional remarks',
                  icon: Icons.notes_outlined,
                  maxLines: 3,
                ),
              ],
            ),
          ],
        ),
      ),
      contentMaxWidth: 900,
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
            label: 'Save Social Support',
            icon: Icons.save_outlined,
            fullWidth: true,
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ),
      ),
    );
  }

  Widget _formCard({
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
                  color: _supportIcon,
                  borderRadius: AppRadius.sm,
                ),
                child: Icon(
                  icon,
                  color: _supportPrimary,
                  size: AppIcons.normal,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...children.expand(
            (child) => [
              child,
              if (child != children.last) const SizedBox(height: AppSpacing.md),
            ],
          ),
        ],
      ),
    );
  }

  Widget _patientAutocomplete() {
    return Autocomplete<Patient>(
      displayStringForOption: _patientLabel,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return const Iterable<Patient>.empty();
        return _patients.where(
          (patient) =>
              patient.name.toLowerCase().contains(query) ||
              (patient.registerId?.toLowerCase().contains(query) ?? false) ||
              patient.place.toLowerCase().contains(query),
        );
      },
      onSelected: _selectPatient,
      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
        if (_selectedPatient != null && controller.text.isEmpty) {
          controller.text = _patientLabel(_selectedPatient!);
        }
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          onEditingComplete: onEditingComplete,
          decoration: _inputDecoration(
            'Patient',
            Icons.person_search_outlined,
            hint: 'Search patient',
          ),
          validator: (_) =>
              _selectedPatient == null ? 'Please select a patient' : null,
        );
      },
    );
  }

  Widget _selectedPatientCard() {
    final patient = _selectedPatient!;
    return Container(
      padding: AppInsets.sm,
      decoration: const BoxDecoration(
        color: _supportCard,
        borderRadius: AppRadius.md,
        border: Border.fromBorderSide(BorderSide(color: _supportIcon)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline, color: _supportPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  [
                    if (patient.registerId?.isNotEmpty == true)
                      'Reg No: ${patient.registerId}',
                    if (patient.place.isNotEmpty) 'Place: ${patient.place}',
                    if (patient.phone.isNotEmpty) 'Ph: ${patient.phone}',
                  ].whereType<String>().join(' • '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Clear patient',
            onPressed: () => setState(() => _selectedPatient = null),
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  void _selectPatient(Patient patient) {
    final volunteer = _findPatientVolunteer(patient, _volunteers);
    setState(() {
      _selectedPatient = patient;
      if (volunteer != null) {
        _selectedVolunteer = volunteer;
      }
    });
  }

  Volunteer? _findPatientVolunteer(
    Patient? patient,
    List<Volunteer> volunteers,
  ) {
    if (patient == null) return null;

    final volunteerId = patient.volunteerId;
    if (volunteerId?.trim().isNotEmpty == true) {
      for (final volunteer in volunteers) {
        if (volunteer.id == volunteerId) return volunteer;
      }
    }

    final name = patient.volunteerName?.trim().toLowerCase();
    final phone = patient.volunteerContact?.trim();
    if ((name == null || name.isEmpty) && (phone == null || phone.isEmpty)) {
      return null;
    }

    for (final volunteer in volunteers) {
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

  Widget _volunteerAutocomplete() {
    if (_volunteers.isEmpty) {
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
              color: _supportPrimary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No volunteers added yet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Autocomplete<Volunteer>(
      key: ValueKey(_selectedVolunteer?.id ?? 'none'),
      displayStringForOption: _volunteerLabel,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return _volunteers;
        return _volunteers.where((volunteer) => volunteer.matches(query));
      },
      onSelected: (volunteer) => setState(() => _selectedVolunteer = volunteer),
      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
        if (_selectedVolunteer != null && controller.text.isEmpty) {
          controller.text = _volunteerLabel(_selectedVolunteer!);
        }
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          onEditingComplete: onEditingComplete,
          decoration: _inputDecoration(
            'Volunteer',
            Icons.volunteer_activism_outlined,
            hint: 'Search volunteer',
          ),
          validator: (_) =>
              _selectedVolunteer == null ? 'Please select a volunteer' : null,
        );
      },
    );
  }

  Widget _selectedVolunteerCard() {
    final volunteer = _selectedVolunteer!;
    return Container(
      padding: AppInsets.sm,
      decoration: const BoxDecoration(
        color: _supportCard,
        borderRadius: AppRadius.md,
        border: Border.fromBorderSide(BorderSide(color: _supportIcon)),
      ),
      child: Row(
        children: [
          const Icon(Icons.badge_outlined, color: _supportPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  volunteer.name,
                  style: Theme.of(context).textTheme.titleSmall,
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
            onPressed: () => setState(() => _selectedVolunteer = null),
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _supportTypeSelector() {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: _supportTypes.map((type) {
        final selected = _selectedTypes.contains(type);
        return FilterChip(
          selected: selected,
          label: Text(socialSupportTypeLabels[type] ?? type),
          avatar: Icon(
            _supportTypeIcon(type),
            size: AppIcons.small,
            color: selected ? AppColors.textInverse : _supportPrimary,
          ),
          selectedColor: _supportPrimary,
          backgroundColor: AppColors.surface1,
          checkmarkColor: AppColors.textInverse,
          side: BorderSide(
            color: selected ? _supportPrimary : AppColors.border,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: selected ? AppColors.textInverse : AppColors.text,
            fontWeight: FontWeight.w600,
          ),
          onSelected: (value) {
            setState(() {
              if (value) {
                _selectedTypes.add(type);
              } else {
                _selectedTypes.remove(type);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    String? hint,
    required IconData icon,
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      minLines: 1,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      decoration: _inputDecoration(label, icon, hint: hint),
      validator: required
          ? (value) =>
                value?.trim().isEmpty == true ? '$label is required' : null
          : null,
    );
  }

  Widget _dateField() {
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.input,
      child: InkWell(
        onTap: _pickDate,
        borderRadius: AppRadius.input,
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.only(left: 6, right: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: AppRadius.input,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _compactPrefixIcon(Icons.event_outlined),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  DateFormat('dd MMM yyyy').format(_givenAt),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: AppColors.text),
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

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    String? hint,
  }) {
    return InputDecoration(
      isDense: true,
      hintText: hint ?? label,
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
        borderSide: const BorderSide(color: _supportPrimary, width: 1.5),
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

  Widget _compactPrefixIcon(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      margin: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: _supportIcon,
        borderRadius: AppRadius.sm,
      ),
      child: Icon(icon, color: _supportPrimary, size: AppIcons.normal),
    );
  }

  IconData _supportTypeIcon(String type) {
    return switch (type) {
      'vegetables' => Icons.eco_outlined,
      'medicine' => Icons.medication_outlined,
      _ => Icons.inventory_2_outlined,
    };
  }

  String _patientLabel(Patient patient) {
    final details = [
      if (patient.registerId?.isNotEmpty == true) patient.registerId,
      if (patient.place.isNotEmpty) patient.place,
    ].whereType<String>().join(' • ');
    return details.isEmpty ? patient.name : '${patient.name} - $details';
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

  String? _blankToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _friendlyError(Object error) {
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }
}
