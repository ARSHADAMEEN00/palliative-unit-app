import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/models/patient.dart';
import 'package:oruma_app/services/patient_service.dart';
import 'package:oruma_app/patient_details_page.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';
import 'package:oruma_app/widgets/module_theme.dart';
import 'package:intl/intl.dart';

class DeceasedPatientListPage extends StatefulWidget {
  const DeceasedPatientListPage({super.key});

  @override
  State<DeceasedPatientListPage> createState() =>
      _DeceasedPatientListPageState();
}

class _DeceasedPatientListPageState extends State<DeceasedPatientListPage> {
  // Data
  List<Patient> _allPatients = [];
  bool _isLoading = true;
  String? _error;

  // Search
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    _loadPatients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await PatientService.getAllPatients(isDead: true);
      if (mounted) {
        setState(() {
          _allPatients = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveAppScaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: AppSpacing.md,
        title: _isSearching
            ? _buildSearchField()
            : Text(
                "Passed Away Patients",
                style: Theme.of(context).textTheme.titleLarge,
              ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: _DeceasedIconButton(
              icon: _isSearching ? Icons.close : Icons.search,
              onPressed: () {
                setState(() {
                  if (_isSearching) {
                    _isSearching = false;
                    _searchController.clear();
                    _searchQuery = '';
                  } else {
                    _isSearching = true;
                  }
                });
              },
            ),
          ),
          if (!_isSearching)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: _DeceasedIconButton(
                icon: Icons.refresh,
                onPressed: _loadPatients,
              ),
            ),
        ],
      ),
      backgroundColor: AppColors.background,
      contentMaxWidth: 820,
      body: Builder(
        builder: (context) {
          if (_isLoading) {
            return const AppListSkeleton(itemCount: 5);
          }

          if (_error != null) {
            return AppEmptyState(
              icon: Icons.error_outline,
              title: 'Could not load records',
              message: _error!,
              action: AppPrimaryButton(
                label: 'Retry',
                icon: Icons.refresh,
                onPressed: _loadPatients,
              ),
            );
          }

          final filteredPatients = _allPatients.where((p) {
            if (_searchQuery.isEmpty) return true;
            final q = _searchQuery.toLowerCase();
            return p.name.toLowerCase().contains(q) ||
                p.village.toLowerCase().contains(q) ||
                (p.registerId ?? '').toLowerCase().contains(q) ||
                p.phone.toLowerCase().contains(q);
          }).toList();

          if (filteredPatients.isEmpty) {
            if (_searchQuery.isNotEmpty) {
              return const AppEmptyState(
                icon: Icons.search_off,
                title: 'No matching records',
                message:
                    'Try a different name, register ID, village, or phone number.',
              );
            }
            return const AppEmptyState(
              icon: Icons.person_off_outlined,
              title: 'No passed away patients',
              message: 'Passed away patient records will appear here.',
            );
          }

          return RefreshIndicator(
            onRefresh: _loadPatients,
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(
                AppInsets.screenHorizontal(context),
                AppSpacing.md,
                AppInsets.screenHorizontal(context),
                AppSpacing.lg,
              ),
              itemCount: filteredPatients.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final patient = filteredPatients[index];
                return _buildPatientCard(context, patient);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: 'Search passed away patients...',
          prefixIcon: const Icon(Icons.search, size: AppIcons.normal),
          filled: true,
          fillColor: AppColors.surface1,
          contentPadding: AppInsets.input,
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
        ),
      ),
    );
  }

  Widget _buildPatientCard(BuildContext context, Patient patient) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      surfaceLevel: AppSurfaceLevel.elevated,
      borderColor: AppColors.borderStrong,
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ModuleTheme(
              palette: ModulePalettes.patients,
              child: PatientDetailsPage(patient: patient),
            ),
          ),
        );
        if (result == true) {
          _loadPatients();
        }
      },
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.surface2,
              borderRadius: AppRadius.md,
            ),
            child: const Icon(
              Icons.person_off_outlined,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.name,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if (patient.dateOfDeath != null)
                      _DeceasedPill(
                        icon: Icons.event_busy_outlined,
                        label:
                            'Died ${DateFormat('MMM dd, yyyy').format(patient.dateOfDeath!)}',
                        color: AppColors.danger,
                      ),
                    _DeceasedPill(
                      icon: Icons.place_outlined,
                      label: '${patient.age} years • ${patient.village}',
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textMuted,
            size: AppIcons.large,
          ),
        ],
      ),
    );
  }
}

class _DeceasedIconButton extends StatelessWidget {
  const _DeceasedIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

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
          child: Icon(icon, size: AppIcons.large, color: AppColors.text),
        ),
      ),
    );
  }
}

class _DeceasedPill extends StatelessWidget {
  const _DeceasedPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: AppIcons.small),
          const SizedBox(width: AppSpacing.xxs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
