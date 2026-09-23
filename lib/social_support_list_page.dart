import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/models/patient.dart';
import 'package:oruma_app/models/social_support.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/services/patient_service.dart';
import 'package:oruma_app/services/social_support_service.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:oruma_app/social_support_page.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';
import 'package:oruma_app/widgets/module_theme.dart';
import 'package:oruma_app/widgets/reveal_action_fab.dart';
import 'package:provider/provider.dart';

const _supportPrimary = Color(0xFFBE185D);
const _supportCard = Color(0xFFFDF2F8);
const _supportIcon = Color(0xFFFCE7F3);

class SocialSupportListPage extends StatefulWidget {
  const SocialSupportListPage({super.key});

  @override
  State<SocialSupportListPage> createState() => _SocialSupportListPageState();
}

class _SocialSupportListPageState extends State<SocialSupportListPage> {
  final _searchController = TextEditingController();
  List<SocialSupport> _records = [];
  List<Patient> _patients = [];
  Patient? _selectedPatient;
  DateTimeRange? _dateRange;
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
        SocialSupportService.getAllSocialSupports(),
        PatientService.getAllPatients(),
      ]);
      if (!mounted) return;
      setState(() {
        _records = results[0] as List<SocialSupport>;
        _patients = results[1] as List<Patient>;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = _friendlyError(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<SocialSupport> get _filteredRecords {
    final query = _searchController.text.trim().toLowerCase();
    return _records.where((record) {
      if (_selectedPatient != null) {
        final selectedId = _selectedPatient!.id;
        final selectedName = _selectedPatient!.name.toLowerCase();
        final matchesPatient =
            (selectedId != null && record.patientObjectId == selectedId) ||
            record.patientName.toLowerCase() == selectedName;
        if (!matchesPatient) return false;
      }

      if (_dateRange != null) {
        final date = _dateOnly(record.givenAt);
        final start = _dateOnly(_dateRange!.start);
        final end = _dateOnly(_dateRange!.end);
        if (date.isBefore(start) || date.isAfter(end)) return false;
      }

      if (query.isEmpty) return true;
      final haystack = [
        record.patientName,
        record.patientRegisterId,
        record.patientPlace,
        record.patientPhone,
        record.supportTypesLabel,
        record.note,
        record.volunteerName,
        record.volunteerContact,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Future<void> _openCreate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ModuleTheme(
          palette: ModulePalettes.socialSupport,
          child: SocialSupportPage(),
        ),
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: _dateRange,
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
    if (picked != null) setState(() => _dateRange = picked);
  }

  Future<void> _deleteRecord(SocialSupport record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        title: const _SupportDialogHeader(
          icon: Icons.delete_outline,
          title: 'Delete record?',
          color: AppColors.danger,
        ),
        content: Text(
          'Delete social support record for ${record.patientName}?',
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

    if (confirm != true || record.id == null) return;

    try {
      await SocialSupportService.deleteSocialSupport(record.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Social support record deleted'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadData(showLoading: false);
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
          'Social Support',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: _SupportIconButton(
              icon: Icons.refresh,
              onPressed: _loading ? null : _loadData,
            ),
          ),
        ],
      ),
      floatingActionButton: auth.canCreate
          ? RevealActionFab(
              onPressed: _openCreate,
              backgroundColor: _supportPrimary,
              foregroundColor: Colors.white,
              icon: Icons.add,
              label: 'New Support',
            )
          : null,
      contentMaxWidth: 820,
      body: Column(
        children: [
          _buildFilters(),
          Expanded(child: _buildBody(auth)),
        ],
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _dateFilterField()),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _patientFilter()),
            ],
          ),
          if (_selectedPatient != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                label: Text(_patientLabel(_selectedPatient!)),
                avatar: const Icon(Icons.person_outline, size: 18),
                backgroundColor: _supportCard,
                side: const BorderSide(color: _supportIcon),
                labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: _supportPrimary,
                  fontWeight: FontWeight.w600,
                ),
                onDeleted: () => setState(() => _selectedPatient = null),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dateFilterField() {
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.input,
      child: InkWell(
        onTap: _pickDateRange,
        borderRadius: AppRadius.input,
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.only(left: 6, right: AppSpacing.xs),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: AppRadius.input,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _compactPrefixIcon(Icons.date_range_outlined),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  _dateRangeLabel(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _dateRange == null
                        ? AppColors.textSecondary
                        : _supportPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_dateRange != null)
                IconButton(
                  tooltip: 'Clear date filter',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _dateRange = null),
                  icon: const Icon(Icons.close, size: 18),
                  color: _supportPrimary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _searchDecoration() {
    return InputDecoration(
      isDense: true,
      hintText: 'Search patient, type, note or volunteer',
      hintStyle: const TextStyle(color: AppColors.textSecondary),
      prefixIcon: _compactPrefixIcon(Icons.search),
      prefixIconConstraints: const BoxConstraints(minWidth: 50, minHeight: 50),
      suffixIcon: _searchController.text.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () {
                _searchController.clear();
                FocusScope.of(context).unfocus();
              },
            )
          : null,
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
    );
  }

  Widget _patientFilter() {
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
      onSelected: (patient) => setState(() => _selectedPatient = patient),
      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          onEditingComplete: onEditingComplete,
          textInputAction: TextInputAction.search,
          decoration: _compactInputDecoration(
            'Filter by patient',
            Icons.person_search_outlined,
          ),
        );
      },
    );
  }

  Widget _buildBody(AuthService auth) {
    if (_loading) {
      return const AppListSkeleton(itemCount: 5);
    }
    if (_error != null) {
      return _errorState();
    }

    final records = _filteredRecords;
    if (records.isEmpty) {
      return _emptyState();
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(showLoading: false),
      color: _supportPrimary,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppInsets.screenHorizontal(context),
          AppSpacing.xs,
          AppInsets.screenHorizontal(context),
          112,
        ),
        itemCount: records.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) => _recordCard(records[index], auth),
      ),
    );
  }

  Widget _recordCard(SocialSupport record, AuthService auth) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      surfaceLevel: AppSurfaceLevel.elevated,
      onTap: () => _showDetails(record),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: _supportIcon,
                  borderRadius: AppRadius.md,
                ),
                child: const Icon(
                  Icons.volunteer_activism_outlined,
                  color: _supportPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.patientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    if (_patientMeta(record).isNotEmpty) ...[
                      Text(
                        _patientMeta(record),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                    ],
                    Text(
                      DateFormat('dd MMM yyyy').format(record.givenAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _supportPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (auth.canDelete)
                PopupMenuButton<String>(
                  iconColor: AppColors.textSecondary,
                  onSelected: (value) {
                    if (value == 'delete') _deleteRecord(record);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _supportChips(record),
          const SizedBox(height: AppSpacing.sm),
          _detailLine(Icons.person_outline, 'Volunteer', record.volunteerName),
          const SizedBox(height: AppSpacing.xs),
          _detailLine(Icons.call_outlined, 'Contact', record.volunteerContact),
          if (record.note?.trim().isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.xs),
            _detailLine(Icons.notes_outlined, 'Note', record.note!),
          ],
        ],
      ),
    );
  }

  Widget _supportChips(SocialSupport record) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: record.supportTypes.map((type) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _supportCard,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: _supportIcon),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_supportTypeIcon(type), color: _supportPrimary, size: 14),
              const SizedBox(width: 5),
              Text(
                socialSupportTypeLabels[type] ?? type,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _supportPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _patientMeta(SocialSupport record) {
    return [
      if (record.patientRegisterId?.trim().isNotEmpty == true)
        'ID ${record.patientRegisterId!.trim()}',
      if (record.patientPlace?.trim().isNotEmpty == true)
        record.patientPlace!.trim(),
    ].join(' • ');
  }

  Widget _detailLine(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppIcons.small, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.text),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showDetails(SocialSupport record) {
    final auth = context.read<AuthService>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottomSafePadding = MediaQuery.of(context).viewPadding.bottom;

        return Container(
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
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: _supportIcon,
                        borderRadius: AppRadius.md,
                      ),
                      child: const Icon(
                        Icons.volunteer_activism_outlined,
                        color: _supportPrimary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.patientName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (_patientMeta(record).isNotEmpty)
                            Text(
                              _patientMeta(record),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          Text(
                            DateFormat('dd MMM yyyy').format(record.givenAt),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: _supportPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _supportChips(record),
                const SizedBox(height: AppSpacing.lg),
                _detailLine(
                  Icons.person_outline,
                  'Volunteer',
                  record.volunteerName,
                ),
                const SizedBox(height: AppSpacing.sm),
                _detailLine(
                  Icons.call_outlined,
                  'Contact',
                  record.volunteerContact,
                ),
                if (record.note?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _detailLine(Icons.notes_outlined, 'Note', record.note!),
                ],
                if (auth.canDelete) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppDangerButton(
                    label: 'Delete Record',
                    icon: Icons.delete_outline,
                    fullWidth: true,
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteRecord(record);
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _errorState() {
    return AppEmptyState(
      icon: Icons.cloud_off_outlined,
      title: 'Could not load support records',
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
        _selectedPatient != null ||
        _dateRange != null;

    return RefreshIndicator(
      onRefresh: () => _loadData(showLoading: false),
      color: _supportPrimary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: AppEmptyState(
                icon: hasFilters
                    ? Icons.search_off_outlined
                    : Icons.volunteer_activism_outlined,
                title: hasFilters
                    ? 'No matching records'
                    : 'No social support records',
                message: hasFilters
                    ? 'Try changing the search, patient, or date filter.'
                    : 'Recorded support for patients will appear here.',
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
        color: _supportIcon,
        borderRadius: AppRadius.sm,
      ),
      child: Icon(icon, color: _supportPrimary, size: AppIcons.normal),
    );
  }

  InputDecoration _compactInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textSecondary),
      prefixIcon: _compactPrefixIcon(icon),
      prefixIconConstraints: const BoxConstraints(minWidth: 50, minHeight: 50),
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
        borderSide: const BorderSide(color: _supportPrimary, width: 1.4),
      ),
    );
  }

  String _dateRangeLabel() {
    if (_dateRange == null) return 'All dates';
    final formatter = DateFormat('dd MMM');
    return '${formatter.format(_dateRange!.start)} - ${formatter.format(_dateRange!.end)}';
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
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

  String _friendlyError(Object error) {
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }
}

class _SupportIconButton extends StatelessWidget {
  const _SupportIconButton({required this.icon, required this.onPressed});

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

class _SupportDialogHeader extends StatelessWidget {
  const _SupportDialogHeader({
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
