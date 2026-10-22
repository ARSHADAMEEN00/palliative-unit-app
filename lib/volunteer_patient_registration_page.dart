import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/models/config.dart';
import 'package:oruma_app/models/patient_enquiry.dart';
import 'package:oruma_app/pt_registration.dart'
    show CapitalizeWordsInputFormatter;
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/services/config_service.dart';
import 'package:oruma_app/services/patient_enquiry_service.dart';
import 'package:oruma_app/services/volunteer_application_service.dart';
import 'package:oruma_app/email_verification_page.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';
import 'package:provider/provider.dart';

class VolunteerPatientRegistrationPage extends StatefulWidget {
  final String? initialUnitId;
  final String? initialUnitName;
  final bool showRegistrationHistory;
  final int initialTabIndex;
  final Future<List<PatientEnquiry>> Function()? enquiriesLoader;
  final Future<Config> Function()? configLoader;

  const VolunteerPatientRegistrationPage({
    super.key,
    this.initialUnitId,
    this.initialUnitName,
    this.showRegistrationHistory = true,
    this.initialTabIndex = 0,
    this.enquiriesLoader,
    this.configLoader,
  });

  @override
  State<VolunteerPatientRegistrationPage> createState() =>
      _VolunteerPatientRegistrationPageState();
}

class _VolunteerPatientRegistrationPageState
    extends State<VolunteerPatientRegistrationPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  // Controllers strictly matching user's 7 inputs:
  // 1. Name : required
  // 2. Age
  // 3. Address
  // 4. 2 phone numbers (one required, one optional)
  // 5. Village select
  // 6. Ward select + type
  // 7. Referred by name & Referred by phone
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _phone2Controller = TextEditingController();
  final TextEditingController _wardController = TextEditingController();
  final TextEditingController _referredByNameController =
      TextEditingController();
  final TextEditingController _referredByPhoneController =
      TextEditingController();

  // Unit and config state
  List<PublicUnit> _units = const [];
  String? _selectedUnitId;
  String? _selectedUnitName;
  bool _loadingUnits = false;
  bool _loadingConfig = false;

  List<String> _villages = [];
  List<WardConfig> _allWards = [];
  List<String> _filteredWards = [];
  String? _selectedVillage;
  String? _selectedWardDropdown;
  bool _isCustomWard = false;

  bool _isSubmitting = false;
  String? _errorMessage;

  // Volunteer's registered patients list state
  List<PatientEnquiry> _myEnquiries = [];
  bool _loadingEnquiries = false;
  String? _enquiriesError;
  String _selectedEnquiryStatusFilter = 'all';
  final TextEditingController _searchEnquiriesController =
      TextEditingController();
  String _searchEnquiriesQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.showRegistrationHistory ? 2 : 1,
      vsync: this,
      initialIndex:
          widget.showRegistrationHistory && widget.initialTabIndex > 0 ? 1 : 0,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _searchEnquiriesController.addListener(() {
      if (mounted) {
        setState(() {
          _searchEnquiriesQuery = _searchEnquiriesController.text
              .trim()
              .toLowerCase();
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _initForm());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchEnquiriesController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _phone2Controller.dispose();
    _wardController.dispose();
    _referredByNameController.dispose();
    _referredByPhoneController.dispose();
    super.dispose();
  }

  Future<void> _initForm() async {
    final auth = context.read<AuthService>();
    final isAuthenticated = auth.isAuthenticated;

    if (isAuthenticated) {
      // Authenticated volunteer: unit is automatically preset
      _selectedUnitId = auth.unitId ?? widget.initialUnitId;
      _selectedUnitName = auth.unitName.isNotEmpty
          ? auth.unitName
          : widget.initialUnitName;
      if (auth.isPublicUser && _selectedUnitId != null) {
        _loadPublicConfig(_selectedUnitId!);
      } else {
        _loadAuthenticatedConfig();
      }
      _loadMyEnquiries();
    } else {
      // Public form: load units list
      _selectedUnitId = widget.initialUnitId;
      _selectedUnitName = widget.initialUnitName;
      await _loadPublicUnits();
      if (_selectedUnitId != null && _selectedUnitId!.isNotEmpty) {
        _loadPublicConfig(_selectedUnitId!);
      }
    }
  }

  bool get _isRestrictedRole {
    final auth = context.read<AuthService>();
    return auth.isVolunteer || auth.isPublicUser;
  }

  PatientEnquiry? get _activePendingEnquiry {
    if (!_isRestrictedRole) return null;
    return _myEnquiries.where((e) => e.isPending).firstOrNull;
  }

  bool get hasActivePendingEnquiry => _activePendingEnquiry != null;

  Future<void> _loadMyEnquiries() async {
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated ||
        !auth.canAccessPatients) {
      return;
    }

    setState(() {
      _loadingEnquiries = true;
      _enquiriesError = null;
    });

    try {
      final list = widget.enquiriesLoader != null
          ? await widget.enquiriesLoader!()
          : await PatientEnquiryService.getEnquiries();
      if (!mounted) return;
      setState(() {
        _myEnquiries = list;
        _loadingEnquiries = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingEnquiries = false;
        _enquiriesError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _loadAuthenticatedConfig() async {
    setState(() => _loadingConfig = true);
    try {
      final config = widget.configLoader != null
          ? await widget.configLoader!()
          : await ConfigService.getConfig();
      if (!mounted) return;
      setState(() {
        _villages = List.from(config.villages)..sort();
        _allWards = sortWardConfigs(config.wards);
        _loadingConfig = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingConfig = false);
    }
  }

  Future<void> _loadPublicUnits() async {
    setState(() => _loadingUnits = true);
    try {
      final units = await PatientEnquiryService.getPublicUnits();
      if (!mounted) return;
      setState(() {
        _units = units;
        _loadingUnits = false;
        if (_selectedUnitId == null && units.length == 1) {
          _selectedUnitId = units.first.id;
          _selectedUnitName = units.first.name;
          _loadPublicConfig(_selectedUnitId!);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingUnits = false;
        _errorMessage =
            'Could not load palliative care units. Please check your connection.';
      });
    }
  }

  Future<void> _loadPublicConfig(String unitId) async {
    setState(() => _loadingConfig = true);
    try {
      if (widget.configLoader != null) {
        final cfg = await widget.configLoader!();
        if (!mounted) return;
        setState(() {
          _villages = List.from(cfg.villages)..sort();
          _allWards = sortWardConfigs(cfg.wards);
          _selectedVillage = null;
          _selectedWardDropdown = null;
          _wardController.clear();
          _filteredWards = [];
          _loadingConfig = false;
        });
        return;
      }
      final config = await PatientEnquiryService.getPublicUnitConfig(unitId);
      if (!mounted) return;
      setState(() {
        _villages = config.villages;
        _allWards = sortWardConfigs(config.wards);
        _selectedVillage = null;
        _selectedWardDropdown = null;
        _wardController.clear();
        _filteredWards = [];
        _loadingConfig = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingConfig = false);
    }
  }

  void _onVillageChanged(String? village) {
    setState(() {
      _selectedVillage = village;
      _updateFilteredWards();
    });
  }

  void _updateFilteredWards() {
    if (_selectedVillage == null) {
      _filteredWards = [];
    } else {
      _filteredWards =
          _allWards
              .where((w) => w.village == _selectedVillage)
              .map((w) => w.number)
              .toList()
            ..sort(compareWardNumbers);
    }

    if (_selectedWardDropdown != null &&
        !_filteredWards.contains(_selectedWardDropdown) &&
        !_isCustomWard) {
      _selectedWardDropdown = null;
      _wardController.clear();
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) {
      setState(
        () => _errorMessage = 'Please sign in to submit patient enquiries.',
      );
      return;
    }
    if ((auth.isVolunteer || auth.isPublicUser) && !auth.isEmailVerified) {
      setState(
        () => _errorMessage =
            'Email verification is required before you can submit a patient enquiry.',
      );
      return;
    }
    if (auth.isVolunteer && !auth.isVolunteerApproved) {
      setState(
        () => _errorMessage =
            'Volunteer approval required. Your account is pending approval.',
      );
      return;
    }

    final isRestrictedUser = auth.isVolunteer || auth.isPublicUser;
    final activePending = isRestrictedUser
        ? _myEnquiries.where((e) => e.isPending).firstOrNull
        : null;
    if (activePending != null) {
      setState(
        () => _errorMessage =
            'You already have a pending patient enquiry (${activePending.name}) awaiting verification. You can submit another enquiry once your current enquiry is approved or rejected by the unit.',
      );
      return;
    }

    // Determine final ward value
    final finalWard = _isCustomWard
        ? _wardController.text.trim()
        : (_selectedWardDropdown ?? _wardController.text.trim());

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final ageNum = int.tryParse(_ageController.text.trim());

      await PatientEnquiryService.submitAuthenticated(
        name: _nameController.text.trim(),
        age: ageNum,
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        phone2: _phone2Controller.text.trim(),
        village: _selectedVillage!,
        ward: finalWard.isEmpty ? null : finalWard,
        referredByName: _referredByNameController.text.trim(),
        referredByPhone: _referredByPhoneController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      await _loadMyEnquiries();
      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
      _loadMyEnquiries();
    }
  }

  void _showSuccessDialog() {
    final auth = context.read<AuthService>();
    final isUserOrVolunteer = auth.isVolunteer || auth.isPublicUser || !auth.isAdmin;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 28,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Text(
                'Enquiry Submitted',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Patient details have been submitted successfully.',
              style: TextStyle(fontSize: 15, height: 1.4),
            ),
            if (!isUserOrVolunteer &&
                _selectedUnitName != null &&
                _selectedUnitName!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Care Unit: $_selectedUnitName',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
        actions: isUserOrVolunteer
            ? [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.button,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _resetForm();
                  },
                  child: const Text('Close'),
                ),
              ]
            : [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _resetForm();
                  },
                  child: const Text('Add Another'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.button,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _resetForm();
                    if (widget.showRegistrationHistory) {
                      _tabController.animateTo(1);
                    }
                  },
                  child: const Text('View Registrations'),
                ),
              ],
      ),
    );
  }

  void _resetForm() {
    _nameController.clear();
    _ageController.clear();
    _addressController.clear();
    _phoneController.clear();
    _phone2Controller.clear();
    _wardController.clear();
    _referredByNameController.clear();
    _referredByPhoneController.clear();
    setState(() {
      _selectedVillage = null;
      _selectedWardDropdown = null;
      _isCustomWard = false;
      _errorMessage = null;
    });
  }

  InputDecoration _buildDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      isDense: true,
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 22, color: AppColors.primary),
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
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final isAuthenticated = auth.isAuthenticated;

    if (!auth.canAccessPatients) {
      return AdaptiveAppScaffold(
        appBar: AppBar(
          title: const Text('Register Patient'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.text,
          elevation: 0,
        ),
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    size: 40,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Access Denied',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'You do not have permission to access patient management or register patients.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!isAuthenticated) {
      return AdaptiveAppScaffold(
        appBar: AppBar(
          title: const Text('Volunteer Patient Register'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.text,
          elevation: 0,
        ),
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    size: 40,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Access Restricted',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Only registered, email-verified volunteers can submit patient enquiries.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if ((auth.isVolunteer || auth.isPublicUser) && !auth.isEmailVerified) {
      return AdaptiveAppScaffold(
        appBar: AppBar(
          title: Text(
            auth.isPublicUser
                ? 'Patient Registration Enquiry'
                : 'Volunteer Patient Register',
          ),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.text,
          elevation: 0,
        ),
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 40,
                    color: Color(0xFFB45309),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Email Verification Required',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  auth.isPublicUser
                      ? 'Please verify your email address to submit a patient registration enquiry.'
                      : 'Only email-verified volunteers can add new patient enquiries.\nPlease verify your email to unlock patient registration.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppPrimaryButton(
                  label: 'Verify Email Now',
                  icon: Icons.verified_user_outlined,
                  onPressed: () async {
                    final email = auth.userEmail;
                    if (email != null && email.isNotEmpty) {
                      final verified = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (context) => EmailVerificationPage(
                            email: email,
                            initialResendAfterSeconds: 0,
                          ),
                        ),
                      );
                      if (verified == true && mounted) {
                        await auth.fetchUserProfile();
                        setState(() {});
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (auth.isVolunteer && !auth.isVolunteerApproved) {
      return AdaptiveAppScaffold(
        appBar: AppBar(
          title: const Text('Volunteer Patient Register'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.text,
          elevation: 0,
        ),
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.pending_actions_rounded,
                    size: 40,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Approval Pending',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Your volunteer account is currently pending approval by the unit administrator.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AdaptiveAppScaffold(
      appBar: AppBar(
        title: Text(
          auth.isPublicUser
              ? 'Patient Registration Enquiry'
              : 'Register Patient',
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        bottom: widget.showRegistrationHistory
            ? TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                tabs: [
                  const Tab(
                    icon: Icon(Icons.person_add_alt_1_rounded),
                    text: 'New Registration',
                  ),
                  Tab(
                    icon: const Icon(Icons.list_alt_rounded),
                    text: _myEnquiries.isEmpty
                        ? 'My Registrations'
                        : 'My Registrations (${_myEnquiries.length})',
                  ),
                ],
              )
            : null,
      ),
      backgroundColor: AppColors.background,
      body: widget.showRegistrationHistory
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildFormView(context, isAuthenticated, auth),
                _buildMyRegistrationsView(context, auth),
              ],
            )
          : _buildFormView(context, isAuthenticated, auth),
    );
  }

  Widget _buildFormView(
    BuildContext context,
    bool isAuthenticated,
    AuthService auth,
  ) {
    final isRestrictedUser = auth.isVolunteer || auth.isPublicUser;
    final activePending = isRestrictedUser
        ? _myEnquiries.where((e) => e.isPending).firstOrNull
        : null;

    return RefreshIndicator(
      onRefresh: _loadMyEnquiries,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: AppInsets.screenHorizontal(context),
          vertical: AppSpacing.md,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (activePending != null) ...[
                    _buildPendingEnquiryAlertCard(context, activePending),
                    const SizedBox(height: AppSpacing.md),
                  ] else if (widget.showRegistrationHistory && _myEnquiries.isNotEmpty) ...[
                  InkWell(
                    onTap: () => _tabController.animateTo(1),
                    borderRadius: AppRadius.card,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.card,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.list_alt_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'You have registered ${_myEnquiries.length} patient${_myEnquiries.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const Text(
                            'View list →',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Informational Header Card
                _buildHeaderCard(isAuthenticated, auth),
                const SizedBox(height: AppSpacing.md),

                // Error Banner
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: AppRadius.card,
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Unit Selector (Only if unauthenticated public form)
                if (!isAuthenticated) ...[
                  _buildSectionHeader(
                    'Care Unit Selection',
                    Icons.apartment_rounded,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (_loadingUnits)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      key: ValueKey(_selectedUnitId),
                      initialValue: _selectedUnitId,
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                      style: AppTypography.dropdownTextStyle(context),
                      decoration: _buildDecoration(
                        label: 'Select Palliative Care Unit *',
                        icon: Icons.apartment_rounded,
                      ),
                      items: _units.map((unit) {
                        return DropdownMenuItem<String>(
                          value: unit.id,
                          child: Text(
                            unit.locationLabel.isEmpty
                                ? '${unit.name} (${unit.code})'
                                : '${unit.name} • ${unit.locationLabel}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      validator: (val) => val == null || val.isEmpty
                          ? 'Please select a care unit'
                          : null,
                      onChanged: (val) {
                        if (val != null && val != _selectedUnitId) {
                          final unit = _units.firstWhere((u) => u.id == val);
                          setState(() {
                            _selectedUnitId = val;
                            _selectedUnitName = unit.name;
                          });
                          _loadPublicConfig(val);
                        }
                      },
                    ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Form Fields Section (Strictly the 7 user requested inputs)
                _buildSectionHeader('Patient Details', Icons.person_rounded),
                const SizedBox(height: AppSpacing.xs),

                Card(
                  elevation: 0,
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.card,
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Name : required
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: [CapitalizeWordsInputFormatter()],
                          decoration: _buildDecoration(
                            label: 'Patient Full Name *',
                            icon: Icons.person_outline_rounded,
                            hint: 'Enter full name of patient',
                          ),
                          validator: (val) => val == null || val.trim().isEmpty
                              ? 'Patient name is required'
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // 2. Age
                        TextFormField(
                          controller: _ageController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: _buildDecoration(
                            label: 'Age',
                            icon: Icons.cake_outlined,
                            hint: 'e.g. 65',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // 3. Address
                        TextFormField(
                          controller: _addressController,
                          maxLines: 2,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: _buildDecoration(
                            label: 'Address',
                            icon: Icons.home_outlined,
                            hint: 'House name, landmark, etc.',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // 4. 2 Phone Numbers: Primary (Required), Secondary (Optional)
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9+ ()-]'),
                            ),
                          ],
                          decoration: _buildDecoration(
                            label: 'Primary Phone Number *',
                            icon: Icons.phone_outlined,
                            hint: 'e.g. 9876543210',
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Primary phone number is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),

                        TextFormField(
                          controller: _phone2Controller,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9+ ()-]'),
                            ),
                          ],
                          decoration: _buildDecoration(
                            label: 'Secondary Phone Number (Optional)',
                            icon: Icons.phone_android_outlined,
                            hint: 'Alternative contact number',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Location Details: Village (Select) & Ward (Select + Type)
                _buildSectionHeader(
                  'Location Details',
                  Icons.location_on_rounded,
                ),
                const SizedBox(height: AppSpacing.xs),

                Card(
                  elevation: 0,
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.card,
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_loadingConfig) ...[
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(AppSpacing.md),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        ] else ...[
                          // 5. Village select
                          DropdownButtonFormField<String>(
                            key: ValueKey(_selectedVillage),
                            initialValue: _selectedVillage,
                            isExpanded: true,
                            dropdownColor: AppColors.surface,
                            style: AppTypography.dropdownTextStyle(context),
                            decoration: _buildDecoration(
                              label: 'Village *',
                              icon: Icons.location_city_rounded,
                            ),
                            hint: const Text('Select Village'),
                            items: _villages.map((v) {
                              return DropdownMenuItem<String>(
                                value: v,
                                child: Text(v),
                              );
                            }).toList(),
                            validator: (val) => val == null || val.isEmpty
                                ? 'Village is required'
                                : null,
                            onChanged: _onVillageChanged,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // 6. Ward select + type
                          _buildWardSelectAndTypeWidget(),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Referred By: Name & Phone
                _buildSectionHeader(
                  'Referred By',
                  Icons.person_pin_circle_rounded,
                ),
                const SizedBox(height: AppSpacing.xs),

                Card(
                  elevation: 0,
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.card,
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Referred By Name
                        TextFormField(
                          controller: _referredByNameController,
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: [CapitalizeWordsInputFormatter()],
                          decoration: _buildDecoration(
                            label: 'Name',
                            icon: Icons.person_outline_rounded,
                            hint: 'Name',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Referred By Phone
                        TextFormField(
                          controller: _referredByPhoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9+ ()-]'),
                            ),
                          ],
                          decoration: _buildDecoration(
                            label: 'Phone',
                            icon: Icons.phone_outlined,
                            hint: 'Phone',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // Submit Action Button or Pending Lock Card
                if (activePending != null) ...[
                  _buildPendingSubmissionLockedCard(context, activePending),
                ] else ...[
                  AppPrimaryButton(
                    label: 'Submit Patient Enquiry',
                    icon: Icons.send_rounded,
                    loading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _submit,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Note: This submission does not directly create a patient. It will appear in the Admin Panel for verification before manual registration.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildPendingEnquiryAlertCard(
    BuildContext context,
    PatientEnquiry pending,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: AppRadius.card,
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  color: AppColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pending Enquiry Awaiting Verification',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Current enquiry: ${pending.name}${pending.village.isNotEmpty ? ' (${pending.village})' : ''}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.showRegistrationHistory)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                  ),
                  onPressed: () => _tabController.animateTo(1),
                  child: const Text('View Status →'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'To prevent duplicate submissions and misuse, you can only submit one enquiry until the admin approves or rejects the current enquiry.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingSubmissionLockedCard(
    BuildContext context,
    PatientEnquiry pending,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: AppRadius.card,
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lock_clock_rounded,
                  color: AppColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Text(
                  'Submission on Hold',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'You already have a pending enquiry for ${pending.name} waiting for approval or rejection. You can submit another patient enquiry once this one has been reviewed by the care unit.',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          if (widget.showRegistrationHistory) ...[
            const SizedBox(height: AppSpacing.md),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.button,
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm,
                  horizontal: AppSpacing.md,
                ),
              ),
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.list_alt_rounded, size: 18),
              label: const Text('View Current Enquiry Status'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMyRegistrationsView(BuildContext context, AuthService auth) {
    if (_loadingEnquiries && _myEnquiries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_enquiriesError != null && _myEnquiries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: AppEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Failed to load registrations',
            message: _enquiriesError!,
            action: AppPrimaryButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: _loadMyEnquiries,
            ),
          ),
        ),
      );
    }

    final pendingCount = _myEnquiries.where((e) => e.isPending).length;
    final verifiedCount = _myEnquiries.where((e) => e.isVerified).length;
    final rejectedCount = _myEnquiries.where((e) => e.isRejected).length;

    final filtered = _myEnquiries.where((item) {
      if (_selectedEnquiryStatusFilter == 'pending' && !item.isPending) {
        return false;
      }
      if (_selectedEnquiryStatusFilter == 'verified' && !item.isVerified) {
        return false;
      }
      if (_selectedEnquiryStatusFilter == 'rejected' && !item.isRejected) {
        return false;
      }

      if (_searchEnquiriesQuery.isNotEmpty) {
        final q = _searchEnquiriesQuery;
        final matches =
            item.name.toLowerCase().contains(q) ||
            item.phone.toLowerCase().contains(q) ||
            (item.phone2 ?? '').toLowerCase().contains(q) ||
            item.village.toLowerCase().contains(q) ||
            (item.ward ?? '').toLowerCase().contains(q) ||
            (item.displayReferredByName ?? '').toLowerCase().contains(q) ||
            (item.displayReferredByPhone ?? '').toLowerCase().contains(q);
        if (!matches) return false;
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadMyEnquiries,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: AppInsets.screenHorizontal(context),
              vertical: AppSpacing.md,
            ),
            children: [
              // Search input
              TextField(
                controller: _searchEnquiriesController,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search registered patients...',
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  suffixIcon: _searchEnquiriesQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _searchEnquiriesController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface,
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
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildEnquiryFilterChip('All', 'all', _myEnquiries.length),
                    const SizedBox(width: AppSpacing.xs),
                    _buildEnquiryFilterChip(
                      'Pending',
                      'pending',
                      pendingCount,
                      color: const Color(0xFFB45309),
                      backgroundColor: const Color(0xFFFEF3C7),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _buildEnquiryFilterChip(
                      'Verified',
                      'verified',
                      verifiedCount,
                      color: const Color(0xFF047857),
                      backgroundColor: const Color(0xFFD1FAE5),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _buildEnquiryFilterChip(
                      'Rejected',
                      'rejected',
                      rejectedCount,
                      color: const Color(0xFFB91C1C),
                      backgroundColor: const Color(0xFFFEE2E2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: AppEmptyState(
                    icon: Icons.assignment_outlined,
                    title: _myEnquiries.isEmpty
                        ? 'No patients registered yet'
                        : 'No matching records',
                    message: _myEnquiries.isEmpty
                        ? 'Patients you register will appear here with their status and details.'
                        : 'Try searching with a different name, village, or phone number.',
                    action: _myEnquiries.isEmpty
                        ? AppPrimaryButton(
                            label: 'Register New Patient',
                            icon: Icons.person_add_alt_1_rounded,
                            onPressed: () => _tabController.animateTo(0),
                          )
                        : null,
                  ),
                )
              else
                for (final item in filtered) ...[
                  _buildRegisteredPatientCard(context, item, auth),
                  const SizedBox(height: AppSpacing.sm),
                ],
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnquiryFilterChip(
    String label,
    String value,
    int count, {
    Color? color,
    Color? backgroundColor,
  }) {
    final selected = _selectedEnquiryStatusFilter == value;
    final activeColor = color ?? AppColors.primary;
    return FilterChip(
      selected: selected,
      label: Text('$label ($count)'),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
        color: selected ? activeColor : AppColors.textSecondary,
      ),
      selectedColor: backgroundColor ?? AppColors.primarySoft,
      checkmarkColor: activeColor,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: selected ? activeColor : AppColors.border),
      ),
      onSelected: (_) {
        setState(() => _selectedEnquiryStatusFilter = value);
      },
    );
  }

  Widget _buildRegisteredPatientCard(
    BuildContext context,
    PatientEnquiry item,
    AuthService auth,
  ) {
    Color statusBg;
    Color statusColor;
    Color statusBorder;
    IconData statusIcon;
    String statusLabel;

    if (item.isVerified) {
      statusBg = const Color(0xFFD1FAE5);
      statusColor = const Color(0xFF047857);
      statusBorder = const Color(0xFFA7F3D0);
      statusIcon = Icons.check_circle_rounded;
      statusLabel = 'Verified & Added';
    } else if (item.isRejected) {
      statusBg = const Color(0xFFFEE2E2);
      statusColor = const Color(0xFFB91C1C);
      statusBorder = const Color(0xFFFECACA);
      statusIcon = Icons.cancel_rounded;
      statusLabel = 'Rejected';
    } else {
      statusBg = const Color(0xFFFEF3C7);
      statusColor = const Color(0xFFB45309);
      statusBorder = const Color(0xFFFDE68A);
      statusIcon = Icons.hourglass_top_rounded;
      statusLabel = 'Pending Verification';
    }

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.card,
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Patient Name, Age & Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primarySoft,
                  child: Text(
                    item.name.trim().isNotEmpty
                        ? item.name.trim()[0].toUpperCase()
                        : 'P',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      if (item.age != null && item.age! > 0)
                        Text(
                          'Age: ${item.age} yrs',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 13, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: AppSpacing.lg),

            // Key Info Rows
            // 1. Phone numbers
            Row(
              children: [
                const Icon(
                  Icons.phone_outlined,
                  size: 15,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    item.phone2 != null && item.phone2!.trim().isNotEmpty
                        ? '${item.phone} • Alt: ${item.phone2}'
                        : item.phone,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 2. Village & Ward
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 15,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    item.ward != null && item.ward!.trim().isNotEmpty
                        ? '${item.village}, Ward ${item.ward}'
                        : item.village,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),

            // 3. Address (if provided)
            if (item.address.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.home_outlined,
                    size: 15,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      item.address.trim(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // 4. Referred By (if provided)
            if (item.displayReferredByName != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.person_pin_circle_outlined,
                    size: 15,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      item.displayReferredByPhone != null
                          ? 'Referred By: ${item.displayReferredByName} (${item.displayReferredByPhone})'
                          : 'Referred By: ${item.displayReferredByName}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // 5. Submission date
            if (item.createdAt != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Submitted: ${DateFormat('dd MMM yyyy, hh:mm a').format(item.createdAt!)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],

            // 6. Review Notes / Reason (if provided)
            if (item.notes != null && item.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: item.isRejected
                      ? const Color(0xFFFEE2E2)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: item.isRejected
                        ? const Color(0xFFFECACA)
                        : AppColors.border,
                  ),
                ),
                child: Text(
                  'Note: ${item.notes!.trim()}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: item.isRejected
                        ? const Color(0xFFB91C1C)
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],

            if (auth.isAdmin) ...[
              const SizedBox(height: AppSpacing.md),

              // Share to WhatsApp Button (Admin only)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text(
                    'Share to WhatsApp',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  onPressed: () {
                    PatientEnquiryService.shareToWhatsApp(
                      item,
                      context,
                      unitName: _selectedUnitName ?? auth.unitName,
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(bool isAuthenticated, AuthService auth) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.primaryLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auth.isPublicUser
                          ? 'Patient Registration Enquiry'
                          : 'Volunteer Patient Enquiry',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.text,
                      ),
                    ),
                    if (isAuthenticated && auth.unitName.isNotEmpty)
                      Text(
                        'Care Unit: ${auth.unitName}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Submitting this form does not directly add an active patient. It sends the details to the Unit Admin under unapproved patient enquiries. Admin will verify details via WhatsApp before manually adding the patient.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: AppSpacing.xs),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }

  /// Ward Select + Type Widget
  /// Allows choosing from configured wards of the village, or typing a custom ward.
  Widget _buildWardSelectAndTypeWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Ward',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            // Toggle between Dropdown and Custom Type
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: () {
                setState(() {
                  _isCustomWard = !_isCustomWard;
                  if (!_isCustomWard && _selectedWardDropdown != null) {
                    _wardController.text = _selectedWardDropdown!;
                  }
                });
              },
              icon: Icon(
                _isCustomWard ? Icons.list_rounded : Icons.edit_note_rounded,
                size: 16,
              ),
              label: Text(
                _isCustomWard ? 'Select from list' : 'Type ward manually',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        if (!_isCustomWard && _filteredWards.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            key: ValueKey('ward_${_selectedVillage}_$_selectedWardDropdown'),
            initialValue: _selectedWardDropdown,
            isExpanded: true,
            dropdownColor: AppColors.surface,
            style: AppTypography.dropdownTextStyle(context),
            decoration: _buildDecoration(
              label: 'Select Ward Number',
              icon: Icons.apartment_rounded,
              hint: 'Choose ward',
            ),
            items: [
              ..._filteredWards.map((w) {
                return DropdownMenuItem<String>(
                  value: w,
                  child: Text('Ward $w'),
                );
              }),
            ],
            onChanged: (val) {
              setState(() {
                _selectedWardDropdown = val;
                _wardController.text = val ?? '';
              });
            },
          ),
        ] else ...[
          TextFormField(
            controller: _wardController,
            decoration: _buildDecoration(
              label: 'Ward Number / Name',
              icon: Icons.edit_location_alt_outlined,
              hint: 'e.g. Ward 4 or North Ward',
            ),
          ),
          if (_filteredWards.isEmpty && _selectedVillage != null)
            const Padding(
              padding: EdgeInsets.only(top: 4, left: 4),
              child: Text(
                'No preset wards found for this village. You can type the ward number directly.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ),
        ],
      ],
    );
  }
}
