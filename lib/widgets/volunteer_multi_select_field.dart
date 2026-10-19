import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_colors.dart';
import 'package:oruma_app/core/theme/app_spacing.dart';
import 'package:oruma_app/models/volunteer.dart';
import 'package:oruma_app/services/volunteer_service.dart';

class VolunteerMultiSelectField extends StatefulWidget {
  final List<String> selectedVolunteerIds;
  final ValueChanged<List<String>> onChanged;
  final String label;
  final String hint;

  const VolunteerMultiSelectField({
    super.key,
    required this.selectedVolunteerIds,
    required this.onChanged,
    this.label = 'Assign Volunteers',
    this.hint = 'Tap to assign volunteers (Optional)',
  });

  @override
  State<VolunteerMultiSelectField> createState() =>
      _VolunteerMultiSelectFieldState();
}

class _VolunteerMultiSelectFieldState extends State<VolunteerMultiSelectField> {
  List<Volunteer> _allVolunteers = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchVolunteers();
  }

  Future<void> _fetchVolunteers() async {
    setState(() => _loading = true);
    try {
      final list = await VolunteerService.getVolunteers();
      final approved =
          list.where((v) => v.applicationStatus == 'approved').toList();
      if (mounted) {
        setState(() {
          _allVolunteers = approved;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openSelectionSheet() async {
    if (_allVolunteers.isEmpty && !_loading) {
      await _fetchVolunteers();
    }
    if (!mounted) return;

    final selected = Set<String>.from(widget.selectedVolunteerIds);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _VolunteerPickerSheet(
          volunteers: _allVolunteers,
          initialSelected: selected,
          onConfirmed: (newSelected) {
            widget.onChanged(newSelected.toList());
          },
        );
      },
    );
  }

  void _removeVolunteer(String id) {
    final updated = List<String>.from(widget.selectedVolunteerIds)..remove(id);
    widget.onChanged(updated);
  }

  Volunteer? _findVolunteer(String id) {
    for (final v in _allVolunteers) {
      if (v.id == id) return v;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIds = widget.selectedVolunteerIds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.volunteer_activism_outlined,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              widget.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '(Optional)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
            ),
            const Spacer(),
            if (selectedIds.isNotEmpty)
              TextButton(
                onPressed: _openSelectionSheet,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 24),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Edit', style: TextStyle(fontSize: 13)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          onTap: _openSelectionSheet,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: selectedIds.isEmpty
                ? Row(
                    children: [
                      const Icon(
                        Icons.person_add_alt_outlined,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          widget.hint,
                          style: TextStyle(
                            color: AppColors.textSecondary.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  )
                : Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: selectedIds.map((id) {
                      final vol = _findVolunteer(id);
                      final name = vol?.name ?? 'Volunteer';
                      final initial = name.isNotEmpty ? name[0].toUpperCase() : 'V';

                      return Chip(
                        avatar: CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.primary.withOpacity(0.15),
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        label: Text(
                          name,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        deleteIcon: const Icon(Icons.close_rounded, size: 16),
                        onDeleted: () => _removeVolunteer(id),
                        backgroundColor: AppColors.surfaceFloating,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(color: AppColors.border),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ),
      ],
    );
  }
}

class _VolunteerPickerSheet extends StatefulWidget {
  final List<Volunteer> volunteers;
  final Set<String> initialSelected;
  final ValueChanged<Set<String>> onConfirmed;

  const _VolunteerPickerSheet({
    required this.volunteers,
    required this.initialSelected,
    required this.onConfirmed,
  });

  @override
  State<_VolunteerPickerSheet> createState() => _VolunteerPickerSheetState();
}

class _VolunteerPickerSheetState extends State<_VolunteerPickerSheet> {
  late Set<String> _selected;
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initialSelected);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Volunteer> get _filteredVolunteers {
    if (_search.trim().isEmpty) return widget.volunteers;
    final q = _search.trim().toLowerCase();
    return widget.volunteers.where((v) {
      return v.name.toLowerCase().contains(q) ||
          v.phone.contains(q) ||
          v.phone2.contains(q) ||
          v.place.toLowerCase().contains(q) ||
          v.ward.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredVolunteers;
    final media = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: media.size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceFloating,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Sheet Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assign Volunteers',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          'Only active volunteers of your unit',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_selected.length} selected',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Search input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name or phone...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface1,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                onChanged: (val) => setState(() => _search = val),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // Select all / Clear buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.select_all_rounded, size: 16),
                    label: const Text('Select All', style: TextStyle(fontSize: 13)),
                    onPressed: () {
                      setState(() {
                        for (final v in filtered) {
                          if (v.id != null) _selected.add(v.id!);
                        }
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  TextButton.icon(
                    icon: const Icon(Icons.clear_all_rounded, size: 16),
                    label: const Text('Clear', style: TextStyle(fontSize: 13)),
                    onPressed: () {
                      setState(() => _selected.clear());
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // Volunteer List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        _search.isEmpty
                            ? 'No active volunteers found'
                            : 'No volunteers matching "$_search"',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, index) {
                        final vol = filtered[index];
                        final id = vol.id ?? '';
                        final isChecked = _selected.contains(id);
                        final initial = vol.name.isNotEmpty
                            ? vol.name[0].toUpperCase()
                            : 'V';

                        return CheckboxListTile(
                          value: isChecked,
                          activeColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          secondary: CircleAvatar(
                            backgroundColor: isChecked
                                ? AppColors.primary
                                : AppColors.surface1,
                            foregroundColor: isChecked
                                ? Colors.white
                                : AppColors.text,
                            child: Text(
                              initial,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          title: Text(
                            vol.name,
                            style: TextStyle(
                              fontWeight:
                                  isChecked ? FontWeight.bold : FontWeight.w500,
                              color: AppColors.text,
                            ),
                          ),
                          subtitle: Text(
                            [
                              if (vol.phone.isNotEmpty) vol.phone,
                              if (vol.place.isNotEmpty) vol.place,
                              if (vol.ward.isNotEmpty) vol.wardLabel,
                            ].join(' • '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selected.add(id);
                              } else {
                                _selected.remove(id);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),

            // Bottom Confirmation Button
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onConfirmed(_selected);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Confirm Selection (${_selected.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
