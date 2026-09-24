import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/features/visit_assessment/domain/visit_assessment.dart';
import 'package:oruma_app/features/visit_assessment/presentation/screens/visit_assessment_list_screen.dart';
import 'package:oruma_app/models/equipment_supply.dart';
import 'package:oruma_app/models/home_visit.dart';
import 'package:oruma_app/models/medicine_supply_activity.dart';
import 'package:oruma_app/models/patient.dart';
import 'package:oruma_app/models/patient_details.dart';
import 'package:oruma_app/models/social_support.dart';
import 'package:oruma_app/pt_registration.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/services/patient_details_service.dart';
import 'package:oruma_app/services/patient_service.dart';
import 'package:oruma_app/services/patient_pdf_generator.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:oruma_app/widgets/deceased_icon.dart';
import 'package:oruma_app/features/visit_assessment/data/visit_assessment_pdf_generator.dart';
import 'package:oruma_app/widgets/module_theme.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:printing/printing.dart';

enum _PatientAction { markDeceased, delete }

enum _PatientDetailsTab {
  overview,
  medical,
  homeVisits,
  equipment,
  assessments,
  medicines,
  socialSupport,
}

const _patientCardBackground = AppColors.surface;
const _patientIconBackground = AppColors.primaryLight;
const _patientPrimary = AppColors.primary;

class PatientDetailsPage extends StatefulWidget {
  final Patient patient;

  const PatientDetailsPage({super.key, required this.patient});

  @override
  State<PatientDetailsPage> createState() => _PatientDetailsPageState();
}

class _PatientDetailsPageState extends State<PatientDetailsPage> {
  late Patient _currentPatient;
  late PatientDetails _details;

  bool _detailsLoading = true;
  bool _isMutating = false;
  bool _isPdfGenerating = false;
  String? _detailsError;

  @override
  void initState() {
    super.initState();
    _currentPatient = widget.patient;
    _details = PatientDetails(patient: widget.patient);
    _loadDetails();
  }

  Future<void> _loadDetails({bool showLoader = true}) async {
    final patientId = _currentPatient.id;
    if (patientId == null || patientId.isEmpty) {
      if (mounted) {
        setState(() {
          _detailsLoading = false;
          _detailsError = 'Patient ID is not available';
        });
      }
      return;
    }

    if (showLoader && mounted) {
      setState(() {
        _detailsLoading = true;
        _detailsError = null;
      });
    }

    try {
      final details = await PatientDetailsService.getPatientDetails(patientId);
      if (!mounted) return;
      setState(() {
        _details = details;
        _currentPatient = details.patient;
        _detailsLoading = false;
        _detailsError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _detailsLoading = false;
        _detailsError = _friendlyError(error);
      });
    }
  }

  Future<void> _editPatient() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ModuleTheme(
          palette: ModulePalettes.patients,
          child: patientrigister(patient: _currentPatient),
        ),
      ),
    );

    if (!mounted) return;
    if (result is Patient) {
      setState(() => _currentPatient = result);
      await _loadDetails();
    } else if (result == true) {
      await _loadDetails();
    }
  }

  Future<void> _deletePatient() async {
    final patientId = _currentPatient.id;
    if (patientId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        title: _PatientDialogHeader(
          icon: Icons.delete_outline,
          title: 'Delete patient?',
          color: AppColors.danger,
        ),
        content: Text(
          'Delete ${_displayName(_currentPatient.name)} permanently? '
          'This action cannot be undone.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        actions: [
          AppSecondaryButton(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context, false),
          ),
          AppDangerButton(
            label: 'Delete',
            icon: Icons.delete_outline,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isMutating = true);
    try {
      await PatientService.deletePatient(patientId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient deleted successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
      setState(() => _isMutating = false);
    }
  }

  Future<void> _markAsDeceased() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Select date of death',
    );
    if (selectedDate == null || !mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        title: _PatientDialogHeader(
          icon: Icons.person_off_outlined,
          title: 'Mark as passed away?',
          color: AppColors.danger,
        ),
        content: Text(
          '${_displayName(_currentPatient.name)} will be marked as passed '
          'away on ${DateFormat('dd MMM yyyy').format(selectedDate)}.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        actions: [
          AppSecondaryButton(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context, false),
          ),
          AppDangerButton(
            label: 'Confirm',
            icon: Icons.check,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted || _currentPatient.id == null) return;

    setState(() => _isMutating = true);
    try {
      final updatedPatient = await PatientService.updatePatient(
        _currentPatient.id!,
        _currentPatient.copyWith(isDead: true, dateOfDeath: selectedDate),
      );
      if (!mounted) return;
      setState(() {
        _currentPatient = updatedPatient;
        _isMutating = false;
      });
      await _loadDetails(showLoader: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient marked as passed away'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isMutating = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    }
  }

  Future<void> _launchMap(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not open map');
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    }
  }

  Future<void> _callPhone(String phone) async {
    try {
      final uri = Uri(scheme: 'tel', path: phone);
      if (!await launchUrl(uri)) {
        throw Exception('Calling is not available on this device');
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    }
  }

  Future<void> _openVisitAssessments() async {
    if (!context.read<AuthService>().canAccessNHC) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('NHC Visit Assessment is not enabled for this unit.'),
        ),
      );
      return;
    }

    final patientId = _currentPatient.id;
    if (patientId == null || patientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This patient record is missing an ID.')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VisitAssessmentModuleScreen(patient: _currentPatient),
      ),
    );
    if (mounted) {
      await _loadDetails(showLoader: false);
    }
  }

  void _handlePatientAction(_PatientAction action) {
    switch (action) {
      case _PatientAction.markDeceased:
        _markAsDeceased();
        return;
      case _PatientAction.delete:
        _deletePatient();
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final canShowMenu =
        auth.canDelete || (auth.canEdit && !_currentPatient.isDead);
    final visibleTabs = _visiblePatientTabs(auth);

    return DefaultTabController(
      length: visibleTabs.length,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                _buildCollapsibleAppBar(auth, canShowMenu),
                if (_detailsLoading)
                  const SliverToBoxAdapter(
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      color: AppColors.primary,
                      backgroundColor: AppColors.primaryLight,
                    ),
                  ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PatientTabsHeaderDelegate(
                    child: _buildTabs(visibleTabs),
                  ),
                ),
              ],
              body: TabBarView(
                children: visibleTabs.map(_buildTabView).toList(),
              ),
            ),
            if (_isMutating)
              Positioned.fill(
                child: ColoredBox(
                  color: AppColors.surface.withValues(alpha: 0.72),
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<_PatientDetailsTab> _visiblePatientTabs(AuthService auth) {
    return [
      if (auth.canAccessPatients) _PatientDetailsTab.overview,
      if (auth.canAccessPatients) _PatientDetailsTab.medical,
      if (auth.canAccessHomeVisits) _PatientDetailsTab.homeVisits,
      if (auth.canAccessEquipment || auth.canAccessEquipmentDistribution)
        _PatientDetailsTab.equipment,
      if (auth.canAccessNHC) _PatientDetailsTab.assessments,
      if (auth.canAccessMedicineSupply) _PatientDetailsTab.medicines,
      if (auth.canAccessSocialSupport) _PatientDetailsTab.socialSupport,
    ];
  }

  Widget _buildTabView(_PatientDetailsTab tab) {
    return switch (tab) {
      _PatientDetailsTab.overview => _buildOverviewTab(),
      _PatientDetailsTab.medical => _buildMedicalTab(),
      _PatientDetailsTab.homeVisits => _buildHomeVisitsTab(),
      _PatientDetailsTab.equipment => _buildEquipmentTab(),
      _PatientDetailsTab.assessments => _buildAssessmentsTab(),
      _PatientDetailsTab.medicines => _buildMedicineSuppliesTab(),
      _PatientDetailsTab.socialSupport => _buildSocialSupportTab(),
    };
  }

  SliverAppBar _buildCollapsibleAppBar(AuthService auth, bool canShowMenu) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final collapsedHeight = topPadding + kToolbarHeight;
    const expandedHeight = 300.0;

    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: expandedHeight,
      collapsedHeight: collapsedHeight,
      toolbarHeight: kToolbarHeight,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      leading: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.xs),
        child: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.maybePop(context),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface1,
            foregroundColor: AppColors.text,
          ),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      actions: _buildHeaderActions(auth, canShowMenu),
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final availableRange = expandedHeight - collapsedHeight;
          final expandedProgress =
              ((constraints.maxHeight - collapsedHeight) / availableRange)
                  .clamp(0.0, 1.0);
          final compactProgress = (1 - expandedProgress * 1.8).clamp(0.0, 1.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(color: AppColors.background),
              ),
              Positioned(
                top: topPadding + 17,
                left: 110,
                right: 110,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: expandedProgress,
                    child: Text(
                      'Patient Details',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: collapsedHeight + 12,
                left: AppSpacing.md,
                right: AppSpacing.md,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: expandedProgress,
                    child: _buildPatientSummary(),
                  ),
                ),
              ),
              Positioned(
                top: topPadding + 7,
                left: 56,
                right: _headerActionWidth(auth, canShowMenu),
                height: 46,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: compactProgress,
                    child: _buildCompactPatientSummary(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildHeaderActions(AuthService auth, bool canShowMenu) {
    return [
      if (auth.canAccessPatientPdf)
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.xs),
          child: _isPdfGenerating
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              : IconButton(
                  tooltip: 'Download patient report (PDF)',
                  onPressed: _isMutating ? null : _downloadPatientPdf,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surface1,
                    foregroundColor: AppColors.primary,
                  ),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                ),
        ),
      if (auth.canEdit)
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.xs),
          child: IconButton(
            tooltip: 'Edit patient',
            onPressed: _isMutating ? null : _editPatient,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface1,
              foregroundColor: AppColors.primary,
            ),
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
        ),
      if (canShowMenu)
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.md),
          child: PopupMenuButton<_PatientAction>(
            tooltip: 'More actions',
            enabled: !_isMutating,
            icon: const Icon(Icons.more_horiz, color: AppColors.text),
            color: AppColors.surface,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
            onSelected: _handlePatientAction,
            itemBuilder: (context) => [
              if (auth.canEdit && !_currentPatient.isDead)
                const PopupMenuItem(
                  value: _PatientAction.markDeceased,
                  child: Row(
                    children: [
                      DeceasedIcon(size: 20, color: AppColors.danger),
                      SizedBox(width: 12),
                      Text('Mark as passed away'),
                    ],
                  ),
                ),
              if (auth.canDelete)
                const PopupMenuItem(
                  value: _PatientAction.delete,
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: AppColors.danger),
                      SizedBox(width: 12),
                      Text(
                        'Delete patient',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
    ];
  }

  double _headerActionWidth(AuthService auth, bool canShowMenu) {
    var width = 16.0;
    if (auth.canAccessPatientPdf) width += 52;
    if (auth.canEdit) width += 52;
    if (canShowMenu) width += 48;
    return width;
  }

  Widget _buildPatientSummary() {
    final name = _displayName(_currentPatient.name);
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    final visibleConditions = _currentPatient.disease.take(3).toList();
    final hiddenConditionCount =
        _currentPatient.disease.length - visibleConditions.length;
    final secondary = <String>[
      if (_currentPatient.registerId?.isNotEmpty == true)
        'ID ${_currentPatient.registerId}',
      if (_currentPatient.gender.isNotEmpty) _currentPatient.gender,
      '${_currentPatient.age} years',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.medium,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: _currentPatient.isDead
                  ? AppColors.surface2
                  : _patientIconBackground,
              borderRadius: AppRadius.card,
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadow.small,
            ),
            alignment: Alignment.center,
            child: _currentPatient.isDead
                ? const Icon(
                    Icons.person_off_outlined,
                    color: AppColors.textMuted,
                    size: 32,
                  )
                : Text(
                    initial,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: _patientPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(height: 13),
          Text(
            name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              height: 1.15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            secondary.join('  •  '),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_currentPatient.isDead) ...[
            const SizedBox(height: 10),
            _lightHeaderPill('Passed away', icon: Icons.favorite_border),
          ] else if (_currentPatient.disease.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 7,
              runSpacing: 7,
              children: visibleConditions
                  .map((disease) => _lightHeaderPill(disease))
                  .followedBy([
                    if (hiddenConditionCount > 0)
                      _lightHeaderPill('+$hiddenConditionCount'),
                  ])
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactPatientSummary() {
    final name = _displayName(_currentPatient.name);
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    final registerId = _currentPatient.registerId?.trim();

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _currentPatient.isDead
                ? AppColors.surface2
                : AppColors.primaryLight,
            borderRadius: AppRadius.sm,
          ),
          child: _currentPatient.isDead
              ? const Icon(
                  Icons.person_off_outlined,
                  color: AppColors.textMuted,
                  size: 18,
                )
              : Text(
                  initial,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (registerId?.isNotEmpty == true)
                Text(
                  'ID $registerId',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabs(List<_PatientDetailsTab> visibleTabs) {
    final visitCount = _details.homeVisits.length;
    final equipmentCount = _details.equipmentSupplies.length;
    final assessmentCount = _details.visitAssessments.length;
    final medicineSupplyCount = _medicineActivityEntries().length;
    final socialSupportCount = _details.socialSupports.length;

    return Container(
      height: 52,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.button,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.small,
      ),
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: _patientPrimary,
          borderRadius: AppRadius.md,
        ),
        labelColor: AppColors.textInverse,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 14),
        tabs: visibleTabs.map((tab) {
          final label = switch (tab) {
            _PatientDetailsTab.overview => 'Overview',
            _PatientDetailsTab.medical => 'Medical',
            _PatientDetailsTab.homeVisits => 'Home Visits ($visitCount)',
            _PatientDetailsTab.equipment => 'Equipment ($equipmentCount)',
            _PatientDetailsTab.assessments => 'Assessment ($assessmentCount)',
            _PatientDetailsTab.medicines => 'Medicines ($medicineSupplyCount)',
            _PatientDetailsTab.socialSupport =>
              'Social Support ($socialSupportCount)',
          };
          return Tab(text: label);
        }).toList(),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: () => _loadDetails(showLoader: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppInsets.page,
        children: [
          if (_detailsError != null) ...[
            _buildSyncError(),
            const SizedBox(height: AppSpacing.sm),
          ],
          _sectionCard(
            icon: Icons.person_outline,
            title: 'Personal information',
            children: _withSpacing([
              _infoRow(
                Icons.badge_outlined,
                'Register ID',
                _value(_currentPatient.registerId),
              ),
              _infoRow(
                Icons.person_outline,
                'Full name',
                _displayName(_currentPatient.name),
              ),
              _infoRow(
                Icons.call_outlined,
                'Phone',
                _value(_currentPatient.phone),
                trailing: _phoneButton(_currentPatient.phone),
              ),
              _infoRow(
                Icons.family_restroom_outlined,
                'Caregiver / relation',
                _value(_currentPatient.relation),
              ),
              _infoRow(
                Icons.phone_android_outlined,
                'Caregiver phone',
                _value(_currentPatient.phone2),
                trailing: _phoneButton(_currentPatient.phone2),
              ),
              if (_currentPatient.volunteerName?.trim().isNotEmpty == true)
                _infoRow(
                  Icons.volunteer_activism_outlined,
                  'Volunteer name',
                  _value(_currentPatient.volunteerName),
                ),
              if (_currentPatient.volunteerContact?.trim().isNotEmpty == true)
                _infoRow(
                  Icons.call_outlined,
                  'Volunteer contact',
                  _value(_currentPatient.volunteerContact),
                  trailing: _phoneButton(_currentPatient.volunteerContact),
                ),
              _infoRow(
                Icons.wc_outlined,
                'Gender',
                _value(_currentPatient.gender),
              ),
              _infoRow(
                Icons.cake_outlined,
                'Age',
                '${_currentPatient.age} years',
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.md),
          _sectionCard(
            icon: Icons.location_on_outlined,
            title: 'Location & address',
            children: _withSpacing([
              _infoRow(
                Icons.home_outlined,
                'Address',
                _value(_currentPatient.address),
              ),
              _infoRow(
                Icons.place_outlined,
                'Place',
                _value(_currentPatient.place),
              ),
              _infoRow(
                Icons.holiday_village_outlined,
                'Village',
                _value(_currentPatient.village),
              ),
              _infoRow(
                Icons.apartment_outlined,
                'Ward number',
                _value(_currentPatient.ward),
              ),
              if (_currentPatient.locationLink?.trim().isNotEmpty == true)
                _mapButton(_currentPatient.locationLink!),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalTab() {
    return RefreshIndicator(
      onRefresh: () => _loadDetails(showLoader: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppInsets.page,
        children: [
          if (_detailsError != null) ...[
            _buildSyncError(),
            const SizedBox(height: AppSpacing.sm),
          ],
          _sectionCard(
            icon: Icons.medical_services_outlined,
            title: 'Medical details',
            children: [
              const Text(
                'Conditions',
                style: TextStyle(
                  color: Color(0xFF74798B),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 9),
              if (_currentPatient.disease.isEmpty)
                const Text(
                  'No conditions recorded',
                  style: TextStyle(
                    color: Color(0xFF202333),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _currentPatient.disease
                      .map((disease) => _statusPill(disease, _patientPrimary))
                      .toList(),
                ),
              const SizedBox(height: 22),
              _infoRow(
                Icons.assignment_outlined,
                'Care plan',
                _value(_currentPatient.plan),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _sectionCard(
            icon: Icons.event_note_outlined,
            title: 'Record information',
            children: _withSpacing([
              _infoRow(
                Icons.event_available_outlined,
                'Registration date',
                _formatDate(_currentPatient.registrationDate),
              ),
              if (_currentPatient.isDead)
                _infoRow(
                  Icons.event_busy_outlined,
                  'Date of death',
                  _formatDate(_currentPatient.dateOfDeath),
                ),
              _infoRow(
                Icons.person_outline,
                _creatorSubtitle(),
                _creatorName(),
              ),
              _infoRow(
                Icons.update_outlined,
                'Last updated',
                _formatDateTime(_currentPatient.updatedAt),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeVisitsTab() {
    if (_detailsLoading && _details.homeVisits.isEmpty) {
      return const AppListSkeleton(itemCount: 4);
    }
    if (_detailsError != null && _details.homeVisits.isEmpty) {
      return _recordsError('Could not load home visits');
    }
    if (_details.homeVisits.isEmpty) {
      return _emptyState(
        icon: Icons.home_outlined,
        title: 'No home visits yet',
        message: 'Home visit history for this patient will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadDetails(showLoader: false),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppInsets.page,
        itemCount: _details.homeVisits.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          return _homeVisitCard(_details.homeVisits[index], index);
        },
      ),
    );
  }

  Widget _buildEquipmentTab() {
    if (_detailsLoading && _details.equipmentSupplies.isEmpty) {
      return const AppListSkeleton(itemCount: 4);
    }
    if (_detailsError != null && _details.equipmentSupplies.isEmpty) {
      return _recordsError('Could not load equipment history');
    }
    if (_details.equipmentSupplies.isEmpty) {
      return _emptyState(
        icon: Icons.medical_information_outlined,
        title: 'No equipment distributed',
        message: 'Equipment issued to this patient will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadDetails(showLoader: false),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppInsets.page,
        itemCount: _details.equipmentSupplies.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          return _equipmentCard(_details.equipmentSupplies[index]);
        },
      ),
    );
  }

  Widget _buildAssessmentsTab() {
    if (_detailsLoading && _details.visitAssessments.isEmpty) {
      return const AppListSkeleton(itemCount: 4);
    }
    if (_detailsError != null && _details.visitAssessments.isEmpty) {
      return _recordsError('Could not load assessment history');
    }
    if (_details.visitAssessments.isEmpty) {
      return _emptyState(
        icon: Icons.assignment_turned_in_outlined,
        title: 'No assessments yet',
        message:
            'Submitted visit assessments for this patient will appear here.',
        action: _assessmentActionButton(),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadDetails(showLoader: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppInsets.page,
        children: [
          _assessmentActionButton(),
          const SizedBox(height: AppSpacing.md),
          ..._details.visitAssessments.map(
            (assessment) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _assessmentCard(assessment),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineSuppliesTab() {
    final activities = _medicineActivityEntries();

    if (_detailsLoading && _details.medicineSupplies.isEmpty) {
      return const AppListSkeleton(itemCount: 4);
    }
    if (_detailsError != null && _details.medicineSupplies.isEmpty) {
      return _recordsError('Could not load medicine supply history');
    }
    if (activities.isEmpty) {
      return _emptyState(
        icon: Icons.medication_outlined,
        title: 'No medicine supplies yet',
        message: 'Medicine supplies issued to this patient will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadDetails(showLoader: false),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppInsets.page,
        itemCount: activities.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          return _medicineActivityCard(activities[index]);
        },
      ),
    );
  }

  Widget _buildSocialSupportTab() {
    if (_detailsLoading && _details.socialSupports.isEmpty) {
      return const AppListSkeleton(itemCount: 4);
    }
    if (_detailsError != null && _details.socialSupports.isEmpty) {
      return _recordsError('Could not load social support history');
    }
    if (_details.socialSupports.isEmpty) {
      return _emptyState(
        icon: Icons.volunteer_activism_outlined,
        title: 'No social support yet',
        message: 'Ration kits, vegetables, and medicines will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadDetails(showLoader: false),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppInsets.page,
        itemCount: _details.socialSupports.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          return _socialSupportCard(_details.socialSupports[index]);
        },
      ),
    );
  }

  Widget _homeVisitCard(HomeVisit visit, int index) {
    final modeColor = _visitModeColor(visit.visitMode);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: modeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.home_outlined, color: modeColor, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatVisitDate(visit.visitDate),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF202333),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Visit ${_details.homeVisits.length - index}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _statusPill(_visitModeLabel(visit.visitMode), modeColor),
            ],
          ),
          const SizedBox(height: 15),
          _detailLine(Icons.groups_outlined, 'Team', _value(visit.team)),
          const SizedBox(height: 10),
          _detailLine(
            Icons.location_on_outlined,
            'Address',
            _value(visit.address),
          ),
          if (visit.notes?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            _detailLine(Icons.notes_outlined, 'Notes', visit.notes!),
          ],
          if (visit.createdBy?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            _detailLine(Icons.person_outline, 'Recorded by', visit.createdBy!),
          ],
        ],
      ),
    );
  }

  Widget _equipmentCard(EquipmentSupply supply) {
    final statusColor = _equipmentStatusColor(supply.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.medical_information_outlined,
                  color: statusColor,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _value(supply.equipmentName),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF202333),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _value(supply.equipmentUniqueId),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _statusPill(_equipmentStatusLabel(supply.status), statusColor),
            ],
          ),
          const SizedBox(height: 15),
          _detailLine(
            Icons.calendar_today_outlined,
            'Distributed',
            _formatDate(supply.supplyDate),
          ),
          if (supply.returnDate != null) ...[
            const SizedBox(height: 10),
            _detailLine(
              Icons.event_outlined,
              'Expected return',
              _formatDate(supply.returnDate),
            ),
          ],
          if (supply.actualReturnDate != null) ...[
            const SizedBox(height: 10),
            _detailLine(
              Icons.assignment_turned_in_outlined,
              'Returned',
              _formatDate(supply.actualReturnDate),
            ),
          ],
          if (supply.careOf?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            _detailLine(Icons.people_outline, 'Care of', supply.careOf!),
          ],
          if (supply.receiverName?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            _detailLine(
              Icons.person_outline,
              'Receiver',
              [
                supply.receiverName,
                supply.receiverPhone,
              ].where((value) => value?.trim().isNotEmpty == true).join(' • '),
            ),
          ],
          if (supply.notes?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            _detailLine(Icons.notes_outlined, 'Notes', supply.notes!),
          ],
          if (supply.returnNote?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            _detailLine(
              Icons.assignment_return_outlined,
              'Return note',
              supply.returnNote!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _assessmentCard(VisitAssessment assessment) {
    final statusColor = assessment.status == 'submitted'
        ? AppColors.success
        : AppColors.warning;
    final vitalSummary = [
      if (assessment.vitals.pulse != null) 'P ${assessment.vitals.pulse}',
      if (assessment.vitals.bpSystolic != null &&
          assessment.vitals.bpDiastolic != null)
        'BP ${assessment.vitals.bpSystolic}/${assessment.vitals.bpDiastolic}',
      if (assessment.vitals.respiratoryRate != null)
        'RR ${assessment.vitals.respiratoryRate}',
      if (assessment.vitals.spo2 != null) 'SpO₂ ${assessment.vitals.spo2}%',
    ].join(' • ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.assignment_turned_in_outlined,
                  color: statusColor,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(assessment.visitDate),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF202333),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${assessment.visitType} assessment',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _statusPill(
                _assessmentStatusLabel(assessment.status),
                statusColor,
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _createAssessmentPdf(context, assessment),
                icon: const Icon(Icons.download_rounded),
                color: _patientPrimary,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (vitalSummary.isNotEmpty)
            _detailLine(Icons.monitor_heart_outlined, 'Vitals', vitalSummary),
          if (assessment.medicines.isNotEmpty) ...[
            if (vitalSummary.isNotEmpty) const SizedBox(height: 10),
            _detailLine(
              Icons.medication_outlined,
              'Medicines noted',
              '${assessment.medicines.length}',
            ),
          ],
          if (assessment.nurseName.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _detailLine(Icons.person_outline, 'Nurse', assessment.nurseName),
          ],
          if (assessment.team.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _detailLine(Icons.groups_outlined, 'Team', assessment.team),
          ],
        ],
      ),
    );
  }

  Widget _assessmentActionButton() {
    if (!context.watch<AuthService>().canAccessNHC) {
      return const SizedBox.shrink();
    }

    return AppPrimaryButton(
      label: 'New Assessment',
      icon: Icons.add,
      fullWidth: true,
      onPressed: _detailsLoading ? null : _openVisitAssessments,
    );
  }

  Widget _medicineActivityCard(MedicineSupplyActivity activity) {
    final statusColor = _medicineActivityColor(activity.type);
    final title = _formatDate(activity.date);
    final subtitle = switch (activity.type) {
      MedicineSupplyActivityType.supplied => 'Medicine supplied',
      MedicineSupplyActivityType.returned => 'Medicine returned',
      MedicineSupplyActivityType.cancelled => 'Medicine cancelled',
    };
    final medicineParts = [
      activity.medicineName,
      if (activity.medicineCode.trim().isNotEmpty) activity.medicineCode.trim(),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  _medicineActivityIcon(activity.type),
                  color: statusColor,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF202333),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _statusPill(activity.eventLabel, statusColor),
            ],
          ),
          const SizedBox(height: 15),
          _detailLine(
            Icons.medication_outlined,
            'Medicine',
            medicineParts.join(' • '),
          ),
          const SizedBox(height: 10),
          _detailLine(
            Icons.inventory_2_outlined,
            'Quantity',
            activity.quantityLabel,
          ),
          const SizedBox(height: 10),
          _detailLine(
            Icons.confirmation_number_outlined,
            'Batch',
            _value(activity.batchNumber),
          ),
          const SizedBox(height: 10),
          _detailLine(
            Icons.calendar_today_outlined,
            'Supply date',
            _formatDate(activity.supplyDate),
          ),
          const SizedBox(height: 10),
          _detailLine(
            Icons.event_outlined,
            'Expiry date',
            _formatDate(activity.expiryDate),
          ),
          const SizedBox(height: 10),
          _detailLine(
            Icons.local_pharmacy_outlined,
            'Stock',
            _value(activity.stockLabel),
          ),
          if (activity.supply.staffName.trim().isNotEmpty &&
              activity.supply.staffName != 'Unknown') ...[
            const SizedBox(height: 10),
            _detailLine(
              Icons.person_outline,
              activity.type == MedicineSupplyActivityType.returned
                  ? 'Original supply by'
                  : 'Given by',
              activity.supply.staffName,
            ),
          ],
          if (activity.supply.supplyDays != null &&
              activity.type == MedicineSupplyActivityType.supplied) ...[
            const SizedBox(height: 10),
            _detailLine(
              Icons.calendar_month_outlined,
              'Supply days',
              '${activity.supply.supplyDays}',
            ),
          ],
          if (activity.supply.prescribedBy?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            _detailLine(
              Icons.badge_outlined,
              'Prescribed by',
              activity.supply.prescribedBy!,
            ),
          ],
          if (activity.supply.doctorPrescription?.trim().isNotEmpty ==
              true) ...[
            const SizedBox(height: 10),
            _detailLine(
              Icons.description_outlined,
              'Prescription',
              activity.supply.doctorPrescription!,
            ),
          ],
          if (activity.note?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            _detailLine(Icons.notes_outlined, 'Notes', activity.note!),
          ],
        ],
      ),
    );
  }

  Widget _socialSupportCard(SocialSupport support) {
    final supportColor = Colors.pink.shade700;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: supportColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.volunteer_activism_outlined,
                  color: supportColor,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(support.givenAt),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF202333),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      support.supportTypesLabel,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: support.supportTypes
                .map(
                  (type) => _statusPill(
                    socialSupportTypeLabels[type] ?? type,
                    supportColor,
                    icon: _socialSupportTypeIcon(type),
                    compact: true,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 15),
          _detailLine(
            Icons.person_outline,
            'Volunteer',
            _value(support.volunteerName),
          ),
          const SizedBox(height: 10),
          _detailLine(
            Icons.call_outlined,
            'Contact',
            _value(support.volunteerContact),
          ),
          if (support.note?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            _detailLine(Icons.notes_outlined, 'Note', support.note!),
          ],
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: AppInsets.card,
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: AppRadius.md,
                ),
                child: Icon(
                  icon,
                  color: _patientPrimary,
                  size: AppIcons.normal,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...children,
        ],
      ),
    );
  }

  Future<void> _downloadPatientPdf() async {
    if (_isPdfGenerating) return;
    final auth = context.read<AuthService>();
    if (!auth.canAccessPatientPdf) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient PDF Reports is not enabled for this unit.'),
        ),
      );
      return;
    }
    setState(() => _isPdfGenerating = true);
    try {
      final bytes = await PatientPdfGenerator.generate(
        _details,
        brand: PatientReportBrand(
          name: auth.unitName,
          subtitle: auth.unitLocation,
          supportPhone: auth.unitSupportPhone,
          contactPhones: auth.unitContactPhones,
          logoSource: auth.unitLogo ?? auth.unitAppIcon,
        ),
      );
      if (!mounted) return;
      await Printing.sharePdf(
        bytes: bytes,
        filename: PatientPdfGenerator.fileName(_currentPatient),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not create PDF: $error')));
    } finally {
      if (mounted) setState(() => _isPdfGenerating = false);
    }
  }

  Future<void> _createAssessmentPdf(
    BuildContext context,
    VisitAssessment assessment,
  ) async {
    await VisitAssessmentPdfGenerator.downloadWithLanguagePicker(
      context,
      assessment,
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: _patientIconBackground,
            borderRadius: AppRadius.md,
          ),
          child: Icon(icon, color: _patientPrimary, size: AppIcons.normal),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.text,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          trailing,
        ],
      ],
    );
  }

  Widget _detailLine(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: _patientIconBackground,
            borderRadius: AppRadius.sm,
          ),
          child: Icon(icon, size: AppIcons.small, color: _patientPrimary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.text,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mapButton(String url) {
    return InkWell(
      onTap: () => _launchMap(url),
      borderRadius: AppRadius.input,
      child: Container(
        padding: AppInsets.md,
        decoration: const BoxDecoration(
          color: _patientIconBackground,
          borderRadius: AppRadius.input,
        ),
        child: Row(
          children: [
            const Icon(Icons.map_outlined, size: 20, color: _patientPrimary),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Text(
                'View location on map',
                style: TextStyle(
                  color: _patientPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: _patientPrimary,
            ),
          ],
        ),
      ),
    );
  }

  Widget? _phoneButton(String? phone) {
    if (phone == null || phone.trim().isEmpty) return null;

    return IconButton(
      tooltip: 'Call $phone',
      onPressed: () => _callPhone(phone),
      style: IconButton.styleFrom(
        backgroundColor: _patientPrimary,
        foregroundColor: AppColors.textInverse,
      ),
      icon: const Icon(Icons.call_outlined, size: 17),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _lightHeaderPill(String label, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: AppColors.primary),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(
    String label,
    Color color, {
    IconData? icon,
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 9,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _assessmentStatusLabel(String status) {
    return status == 'submitted' ? 'Submitted' : 'Draft';
  }

  List<MedicineSupplyActivity> _medicineActivityEntries() {
    return MedicineSupplyActivity.fromSupplies(_details.medicineSupplies);
  }

  IconData _medicineActivityIcon(MedicineSupplyActivityType type) {
    return switch (type) {
      MedicineSupplyActivityType.supplied => Icons.medication_outlined,
      MedicineSupplyActivityType.returned => Icons.assignment_return_outlined,
      MedicineSupplyActivityType.cancelled => Icons.cancel_outlined,
    };
  }

  IconData _socialSupportTypeIcon(String type) {
    return switch (type) {
      'vegetables' => Icons.eco_outlined,
      'medicine' => Icons.medication_outlined,
      _ => Icons.inventory_2_outlined,
    };
  }

  Color _medicineActivityColor(MedicineSupplyActivityType type) {
    return switch (type) {
      MedicineSupplyActivityType.supplied => AppColors.success,
      MedicineSupplyActivityType.returned => AppColors.warning,
      MedicineSupplyActivityType.cancelled => AppColors.danger,
    };
  }

  Widget _buildSyncError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Text(
              'Extra history could not be refreshed. Patient information is '
              'still available.',
              style: TextStyle(fontSize: 12, height: 1.35),
            ),
          ),
          TextButton(
            onPressed: _detailsLoading ? null : () => _loadDetails(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _recordsError(String title) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppInsets.page,
      children: [
        SizedBox(
          height: 360,
          child: AppEmptyState(
            icon: Icons.cloud_off_outlined,
            title: title,
            message: _detailsError ?? 'Please try again.',
            action: AppPrimaryButton(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: () => _loadDetails(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return RefreshIndicator(
      onRefresh: () => _loadDetails(showLoader: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 360,
            child: AppEmptyState(
              icon: icon,
              title: title,
              message: message,
              action: action,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: _patientCardBackground,
      borderRadius: AppRadius.card,
      border: Border.all(color: AppColors.border),
      boxShadow: AppShadow.medium,
    );
  }

  List<Widget> _withSpacing(List<Widget> children) {
    final result = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      result.add(children[index]);
      if (index < children.length - 1) {
        result.add(const SizedBox(height: 18));
      }
    }
    return result;
  }

  String _value(String? value) {
    if (value == null || value.trim().isEmpty) return 'Not recorded';
    return value.trim();
  }

  String _creatorName() {
    final creatorName = _details.creator?.name.trim();
    if (creatorName?.isNotEmpty == true) {
      return _displayName(creatorName!);
    }

    final fallback = _currentPatient.createdBy?.trim();
    if (fallback == null ||
        fallback.isEmpty ||
        RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(fallback)) {
      return 'Not recorded';
    }
    return _displayName(fallback);
  }

  String _creatorSubtitle() {
    final details = <String>['Created by'];
    final role = _details.creator?.role?.trim();
    final email = _details.creator?.email?.trim();

    if (role?.isNotEmpty == true) {
      details.add(_displayName(role!));
    }
    if (email?.isNotEmpty == true) {
      details.add(email!);
    }

    return details.join(' • ');
  }

  String _displayName(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s*,\s*'), ', ');
    return normalized
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
        })
        .join(' ');
  }

  String _friendlyError(Object error) {
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not recorded';
    return DateFormat('dd MMM yyyy').format(date.toLocal());
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return 'Not recorded';
    return DateFormat('dd MMM yyyy, h:mm a').format(date.toLocal());
  }

  String _formatVisitDate(String value) {
    final date = DateTime.tryParse(value);
    return date == null ? _value(value) : _formatDate(date);
  }

  String _visitModeLabel(String mode) {
    switch (mode) {
      case 'new':
        return 'New';
      case 'monthly':
        return 'Planned NHC';
      case 'emergency':
        return 'Emergency';
      case 'dhc_visit':
        return 'DHC';
      case 'vhc_visit':
        return 'VHC';
      default:
        return mode.replaceAll('_', ' ').toUpperCase();
    }
  }

  Color _visitModeColor(String mode) {
    switch (mode) {
      case 'emergency':
        return AppColors.danger;
      case 'monthly':
        return AppColors.primary;
      case 'dhc_visit':
        return AppColors.warning;
      case 'vhc_visit':
        return AppColors.scheduled;
      default:
        return AppColors.success;
    }
  }

  String _equipmentStatusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Active';
      case 'returned':
        return 'Returned';
      case 'lost':
        return 'Lost';
      default:
        return status;
    }
  }

  Color _equipmentStatusColor(String status) {
    switch (status) {
      case 'active':
        return AppColors.success;
      case 'returned':
        return AppColors.offline;
      case 'lost':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }
}

class _PatientTabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  const _PatientTabsHeaderDelegate({required this.child});

  @override
  double get minExtent => 70;

  @override
  double get maxExtent => 70;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: shrinkOffset == 0
            ? const BorderRadius.vertical(top: Radius.circular(30))
            : BorderRadius.zero,
        boxShadow: overlapsContent ? AppShadow.small : null,
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _PatientTabsHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}

class _PatientDialogHeader extends StatelessWidget {
  const _PatientDialogHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: AppRadius.md,
          ),
          child: Icon(icon, color: color, size: AppIcons.large),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
      ],
    );
  }
}
