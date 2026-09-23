import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/models/config.dart';
import 'package:oruma_app/models/volunteer.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/services/config_service.dart';
import 'package:oruma_app/services/volunteer_service.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';
import 'package:oruma_app/widgets/module_theme.dart';
import 'package:oruma_app/widgets/reveal_action_fab.dart';
import 'package:provider/provider.dart';

const _volunteerPrimary = Color(0xFF0F766E);
const _volunteerIconSurface = Color(0xFFCCFBF1);

class VolunteerListPage extends StatefulWidget {
  const VolunteerListPage({super.key});

  @override
  State<VolunteerListPage> createState() => _VolunteerListPageState();
}

class _VolunteerListPageState extends State<VolunteerListPage> {
  final _searchController = TextEditingController();
  List<Volunteer> _volunteers = [];
  List<String> _villages = [];
  List<WardConfig> _allWards = [];
  List<String> _filteredWards = ['All'];
  String _selectedVillage = 'All';
  String _selectedWard = 'All';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        VolunteerService.getVolunteers(),
        ConfigService.getConfig(),
      ]);
      final config = results[1] as Config;
      if (!mounted) return;
      setState(() {
        _volunteers = results[0] as List<Volunteer>;
        _villages = [...config.villages]..sort(compareNaturally);
        _allWards = sortWardConfigs(config.wards);
        _updateFilteredWards();
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _updateFilteredWards() {
    if (_selectedVillage == 'All') {
      _filteredWards = ['All'];
    } else {
      _filteredWards =
          [
            'All',
            ..._allWards
                .where((ward) => ward.village == _selectedVillage)
                .map((ward) => ward.number),
          ]..sort((a, b) {
            if (a == 'All') return -1;
            if (b == 'All') return 1;
            return compareWardNumbers(a, b);
          });
    }

    if (!_filteredWards.contains(_selectedWard)) {
      _selectedWard = 'All';
    }
  }

  List<Volunteer> get _filteredVolunteers {
    final query = _searchController.text.trim();
    return _volunteers.where((volunteer) {
      if (_selectedVillage != 'All' && volunteer.village != _selectedVillage) {
        return false;
      }
      if (_selectedWard != 'All' && volunteer.ward != _selectedWard) {
        return false;
      }
      return volunteer.matches(query);
    }).toList();
  }

  Future<void> _openForm([Volunteer? volunteer]) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => VolunteerFormPage(volunteer: volunteer),
      ),
    );
    if (result == true) {
      await _loadData(showLoading: false);
    }
  }

  Future<void> _deleteVolunteer(Volunteer volunteer) async {
    if (volunteer.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        title: const _VolunteerDialogHeader(
          icon: Icons.delete_outline,
          title: 'Delete volunteer?',
          color: AppColors.danger,
        ),
        content: Text(
          'Delete ${volunteer.name} from volunteers?',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.45,
          ),
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

    if (confirmed != true) return;

    try {
      await VolunteerService.deleteVolunteer(volunteer.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Volunteer deleted'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadData(showLoading: false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(error)),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return ModuleTheme(
      palette: ModulePalettes.volunteers,
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
            'Volunteers',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: _VolunteerIconButton(
                icon: Icons.refresh,
                onPressed: _loading ? null : _loadData,
              ),
            ),
          ],
        ),
        floatingActionButton: auth.canCreate
            ? RevealActionFab(
                onPressed: () => _openForm(),
                backgroundColor: _volunteerPrimary,
                foregroundColor: Colors.white,
                icon: Icons.add,
                label: 'Add Volunteer',
              )
            : null,
        contentMaxWidth: 820,
        body: Column(
          children: [
            _buildFilters(),
            Expanded(child: _buildBody(auth)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return AppCard(
      margin: EdgeInsets.fromLTRB(
        AppInsets.screenHorizontal(context),
        AppSpacing.sm,
        AppInsets.screenHorizontal(context),
        AppSpacing.xs,
      ),
      padding: AppInsets.md,
      surfaceLevel: AppSurfaceLevel.elevated,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: _searchDecoration(),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _filterDropdown(
                  icon: Icons.location_city_outlined,
                  value: _selectedVillage,
                  items: ['All', ..._villages],
                  labelFor: (value) => value == 'All' ? 'All villages' : value,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedVillage = value;
                      _updateFilteredWards();
                    });
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _filterDropdown(
                  icon: Icons.apartment_outlined,
                  value: _selectedWard,
                  items: _filteredWards,
                  labelFor: (value) =>
                      value == 'All' ? 'All wards' : 'Ward $value',
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedWard = value);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown({
    required IconData icon,
    required String value,
    required List<String> items,
    required String Function(String value) labelFor,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      key: ValueKey('$value-${items.join('|')}'),
      initialValue: items.contains(value) ? value : null,
      isExpanded: true,
      dropdownColor: AppColors.surface,
      iconEnabledColor: AppColors.textSecondary,
      style: AppTypography.dropdownTextStyle(context),
      decoration: _compactInputDecoration(labelFor(value), icon),
      items: items
          .map(
            (item) =>
                DropdownMenuItem(value: item, child: Text(labelFor(item))),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildBody(AuthService auth) {
    if (_loading) {
      return const AppListSkeleton(itemCount: 5);
    }

    if (_error != null) {
      return _errorState();
    }

    final volunteers = _filteredVolunteers;
    if (volunteers.isEmpty) {
      return _emptyState();
    }

    return RefreshIndicator(
      color: _volunteerPrimary,
      onRefresh: () => _loadData(showLoading: false),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppInsets.screenHorizontal(context),
          AppSpacing.xs,
          AppInsets.screenHorizontal(context),
          112,
        ),
        itemCount: volunteers.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) =>
            _volunteerCard(volunteers[index], auth),
      ),
    );
  }

  Widget _volunteerCard(Volunteer volunteer, AuthService auth) {
    return AppCard(
      onTap: () => _showDetails(volunteer, auth),
      padding: const EdgeInsets.all(AppSpacing.md),
      surfaceLevel: AppSurfaceLevel.elevated,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avatar(size: 44),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  volunteer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  volunteer.locationLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _volunteerPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _inlineDetail(Icons.call_outlined, volunteer.phone),
                if (volunteer.phone2.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  _inlineDetail(Icons.phone_iphone_outlined, volunteer.phone2),
                ],
                if (volunteer.address.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  _inlineDetail(Icons.home_outlined, volunteer.address.trim()),
                ],
              ],
            ),
          ),
          if (auth.canEdit || auth.canDelete)
            PopupMenuButton<String>(
              iconColor: AppColors.textSecondary,
              onSelected: (value) {
                if (value == 'edit') _openForm(volunteer);
                if (value == 'delete') _deleteVolunteer(volunteer);
              },
              itemBuilder: (context) => [
                if (auth.canEdit)
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (auth.canDelete)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
              ],
            )
          else
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _avatar({double size = 50}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: _volunteerIconSurface,
        borderRadius: AppRadius.md,
      ),
      child: Icon(
        Icons.volunteer_activism_outlined,
        color: _volunteerPrimary,
        size: size * 0.52,
      ),
    );
  }

  Widget _inlineDetail(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppIcons.small, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  void _showDetails(Volunteer volunteer, AuthService auth) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottomSafePadding = MediaQuery.of(context).viewPadding.bottom;

        return ModuleTheme(
          palette: ModulePalettes.volunteers,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.sheet,
            ),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg + bottomSafePadding,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: _SheetHandle()),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      _avatar(size: 48),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              volunteer.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              volunteer.phone2.trim().isEmpty
                                  ? volunteer.phone
                                  : '${volunteer.phone} / ${volunteer.phone2}',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: _volunteerPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _detailLine(
                    Icons.location_city_outlined,
                    'Village',
                    volunteer.village,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _detailLine(
                    Icons.apartment_outlined,
                    'Ward',
                    volunteer.wardLabel,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _detailLine(Icons.place_outlined, 'Place', volunteer.place),
                  if (volunteer.address.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _detailLine(
                      Icons.home_outlined,
                      'Address',
                      volunteer.address.trim(),
                    ),
                  ],
                  if (volunteer.phone2.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _detailLine(
                      Icons.phone_iphone_outlined,
                      'Second Phone',
                      volunteer.phone2.trim(),
                    ),
                  ],
                  if (auth.canEdit || auth.canDelete) ...[
                    const SizedBox(height: AppSpacing.lg),
                    if (auth.canEdit)
                      AppPrimaryButton(
                        label: 'Edit volunteer',
                        icon: Icons.edit_outlined,
                        fullWidth: true,
                        onPressed: () {
                          Navigator.pop(context);
                          _openForm(volunteer);
                        },
                      ),
                    if (auth.canDelete) ...[
                      const SizedBox(height: AppSpacing.sm),
                      AppDangerButton(
                        label: 'Delete volunteer',
                        icon: Icons.delete_outline,
                        fullWidth: true,
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteVolunteer(volunteer);
                        },
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailLine(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _volunteerPrimary, size: AppIcons.normal),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                label,
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

  Widget _errorState() {
    return AppEmptyState(
      icon: Icons.cloud_off_outlined,
      title: 'Could not load volunteers',
      message: _error!,
      action: AppPrimaryButton(
        label: 'Retry',
        icon: Icons.refresh,
        onPressed: _loadData,
      ),
    );
  }

  Widget _emptyState() {
    final hasFilters =
        _searchController.text.isNotEmpty ||
        _selectedVillage != 'All' ||
        _selectedWard != 'All';

    return RefreshIndicator(
      onRefresh: () => _loadData(showLoading: false),
      color: _volunteerPrimary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: AppEmptyState(
                icon: hasFilters
                    ? Icons.search_off_outlined
                    : Icons.group_add_outlined,
                title: hasFilters ? 'No matching volunteers' : 'No volunteers',
                message: hasFilters
                    ? 'Try changing the search, village, or ward filter.'
                    : 'Volunteer profiles will appear here once added.',
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _compactPrefixIcon(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      margin: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: _volunteerIconSurface,
        borderRadius: AppRadius.sm,
      ),
      child: Icon(icon, color: _volunteerPrimary, size: AppIcons.normal),
    );
  }

  InputDecoration _searchDecoration() {
    return InputDecoration(
      isDense: true,
      hintText: 'Search name, phone, address, place or ward',
      hintStyle: const TextStyle(color: AppColors.textSecondary),
      prefixIcon: _compactPrefixIcon(Icons.search),
      prefixIconConstraints: const BoxConstraints(minWidth: 50, minHeight: 50),
      suffixIcon: _searchController.text.isEmpty
          ? null
          : IconButton(
              onPressed: () {
                _searchController.clear();
                FocusScope.of(context).unfocus();
              },
              icon: const Icon(Icons.close, size: 20),
            ),
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
        borderSide: const BorderSide(color: _volunteerPrimary, width: 1.5),
      ),
    );
  }

  InputDecoration _compactInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
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
        borderSide: const BorderSide(color: _volunteerPrimary, width: 1.4),
      ),
    );
  }

  String _friendlyError(Object error) {
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }
}

class VolunteerFormPage extends StatefulWidget {
  final Volunteer? volunteer;

  const VolunteerFormPage({super.key, this.volunteer});

  @override
  State<VolunteerFormPage> createState() => _VolunteerFormPageState();
}

class _VolunteerFormPageState extends State<VolunteerFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _phone2Controller;
  late final TextEditingController _placeController;
  late final TextEditingController _addressController;
  List<String> _villages = [];
  List<WardConfig> _allWards = [];
  List<String> _wardOptions = [];
  String? _selectedVillage;
  String? _selectedWard;
  bool _loadingConfig = true;
  bool _saving = false;
  String? _configError;

  bool get _editing => widget.volunteer != null;

  @override
  void initState() {
    super.initState();
    final volunteer = widget.volunteer;
    _nameController = TextEditingController(text: volunteer?.name);
    _phoneController = TextEditingController(text: volunteer?.phone);
    _phone2Controller = TextEditingController(text: volunteer?.phone2);
    _placeController = TextEditingController(text: volunteer?.place);
    _addressController = TextEditingController(text: volunteer?.address);
    _selectedVillage = volunteer?.village;
    _selectedWard = volunteer?.ward;
    _loadConfig();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _phone2Controller.dispose();
    _placeController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final config = await ConfigService.getConfig();
      if (!mounted) return;
      setState(() {
        _villages = [...config.villages]..sort(compareNaturally);
        _allWards = sortWardConfigs(config.wards);
        _updateWardOptions();
        _loadingConfig = false;
        _configError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _configError = _friendlyError(error);
        _loadingConfig = false;
      });
    }
  }

  void _updateWardOptions() {
    if (_selectedVillage == null) {
      _wardOptions = [];
    } else {
      _wardOptions =
          _allWards
              .where((ward) => ward.village == _selectedVillage)
              .map((ward) => ward.number)
              .toList()
            ..sort(compareWardNumbers);
    }

    if (_selectedWard != null && !_wardOptions.contains(_selectedWard)) {
      if (widget.volunteer?.ward == _selectedWard &&
          widget.volunteer?.village == _selectedVillage) {
        _wardOptions = [..._wardOptions, _selectedWard!]
          ..sort(compareWardNumbers);
      } else {
        _selectedWard = null;
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final volunteer = Volunteer(
      id: widget.volunteer?.id,
      village: _selectedVillage!,
      ward: normalizeWardNumberValue(_selectedWard),
      place: _placeController.text.trim(),
      address: _addressController.text.trim(),
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      phone2: _phone2Controller.text.trim(),
    );

    try {
      if (_editing) {
        await VolunteerService.updateVolunteer(
          widget.volunteer!.id!,
          volunteer,
        );
      } else {
        await VolunteerService.createVolunteer(volunteer);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editing ? 'Volunteer updated' : 'Volunteer created'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(error)),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingConfig) {
      return ModuleTheme(
        palette: ModulePalettes.volunteers,
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
              _editing ? 'Edit Volunteer' : 'New Volunteer',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          body: const AppListSkeleton(itemCount: 4),
          contentMaxWidth: 900,
        ),
      );
    }

    return ModuleTheme(
      palette: ModulePalettes.volunteers,
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
            _editing ? 'Edit Volunteer' : 'New Volunteer',
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
              if (_configError != null)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: AppInsets.md,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.08),
                    borderRadius: AppRadius.input,
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Text(
                    _configError!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              _formCard(
                title: 'Location',
                icon: Icons.map_outlined,
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      'village-${_selectedVillage ?? ''}-${_villageOptions.join('|')}',
                    ),
                    initialValue: _villageOptions.contains(_selectedVillage)
                        ? _selectedVillage
                        : null,
                    isExpanded: true,
                    style: AppTypography.dropdownTextStyle(context),
                    decoration: _inputDecoration(
                      'Village',
                      Icons.location_city_outlined,
                    ),
                    items: _villageOptions
                        .map(
                          (village) => DropdownMenuItem(
                            value: village,
                            child: Text(village),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedVillage = value;
                        _selectedWard = null;
                        _updateWardOptions();
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Village is required' : null,
                  ),
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      'ward-${_selectedWard ?? ''}-${_wardOptions.join('|')}',
                    ),
                    initialValue: _wardOptions.contains(_selectedWard)
                        ? _selectedWard
                        : null,
                    isExpanded: true,
                    style: AppTypography.dropdownTextStyle(context),
                    decoration: _inputDecoration(
                      'Ward',
                      Icons.apartment_outlined,
                    ),
                    hint: const Text('Select Ward'),
                    items: _wardOptions
                        .map(
                          (ward) => DropdownMenuItem(
                            value: ward,
                            child: Text('Ward $ward'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _selectedWard = value),
                    validator: (value) =>
                        value == null ? 'Ward is required' : null,
                  ),
                  TextFormField(
                    controller: _placeController,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecoration('Place', Icons.place_outlined),
                    validator: (value) => value?.trim().isEmpty == true
                        ? 'Place is required'
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _formCard(
                title: 'Volunteer',
                icon: Icons.volunteer_activism_outlined,
                children: [
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecoration('Name', Icons.person_outline),
                    validator: (value) => value?.trim().isEmpty == true
                        ? 'Name is required'
                        : null,
                  ),
                  TextFormField(
                    controller: _addressController,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecoration(
                      'Address',
                      Icons.home_outlined,
                    ),
                    minLines: 1,
                    maxLines: 3,
                  ),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: _inputDecoration('Phone', Icons.call_outlined),
                    validator: (value) => value?.trim().isEmpty == true
                        ? 'Phone is required'
                        : null,
                  ),
                  TextFormField(
                    controller: _phone2Controller,
                    keyboardType: TextInputType.phone,
                    decoration: _inputDecoration(
                      'Second Phone',
                      Icons.phone_iphone_outlined,
                    ),
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
              label: _editing ? 'Update Volunteer' : 'Save Volunteer',
              icon: Icons.save_outlined,
              fullWidth: true,
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ),
        ),
      ),
    );
  }

  List<String> get _villageOptions {
    final values = <String>{
      ..._villages,
      if (_selectedVillage?.trim().isNotEmpty == true) _selectedVillage!,
    }.toList()..sort(compareNaturally);
    return values;
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
                  color: _volunteerIconSurface,
                  borderRadius: AppRadius.sm,
                ),
                child: Icon(
                  icon,
                  color: _volunteerPrimary,
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

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      isDense: true,
      hintText: label,
      hintStyle: const TextStyle(color: AppColors.textSecondary),
      prefixIcon: _compactFormPrefixIcon(icon),
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
        borderSide: const BorderSide(color: _volunteerPrimary, width: 1.5),
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

  Widget _compactFormPrefixIcon(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      margin: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: _volunteerIconSurface,
        borderRadius: AppRadius.sm,
      ),
      child: Icon(icon, color: _volunteerPrimary, size: AppIcons.normal),
    );
  }

  String _friendlyError(Object error) {
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }
}

class _VolunteerIconButton extends StatelessWidget {
  const _VolunteerIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface1,
      borderRadius: AppRadius.md,
      child: InkWell(
        borderRadius: AppRadius.md,
        onTap: onPressed,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            color: onPressed == null ? AppColors.textMuted : AppColors.text,
            size: AppIcons.large,
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 5,
      decoration: BoxDecoration(
        color: AppColors.borderStrong,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _VolunteerDialogHeader extends StatelessWidget {
  const _VolunteerDialogHeader({
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
