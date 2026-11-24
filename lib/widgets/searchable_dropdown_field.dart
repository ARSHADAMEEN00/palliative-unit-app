import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';

class SearchableDropdownField<T> extends FormField<T> {
  SearchableDropdownField({
    super.key,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    required this.decoration,
    this.itemSearchText,
    this.hintText,
    this.searchHintText = 'Search...',
    this.dialogTitle,
    this.emptyText = 'No matching options',
    this.style,
    this.clearable = false,
    this.clearLabel = 'Clear selection',
    bool enabled = true,
    super.validator,
    super.onSaved,
    super.autovalidateMode,
  }) : super(
         initialValue: value,
         enabled: enabled && onChanged != null,
         builder: (state) =>
             (state as _SearchableDropdownFieldState<T>)._buildField(),
       );

  final T? value;
  final List<T> items;
  final String Function(T item) itemLabel;
  final String Function(T item)? itemSearchText;
  final ValueChanged<T?>? onChanged;
  final InputDecoration decoration;
  final String? hintText;
  final String searchHintText;
  final String? dialogTitle;
  final String emptyText;
  final TextStyle? style;
  final bool clearable;
  final String clearLabel;

  @override
  FormFieldState<T> createState() => _SearchableDropdownFieldState<T>();
}

class _SearchableDropdownFieldState<T> extends FormFieldState<T> {
  @override
  SearchableDropdownField<T> get widget =>
      super.widget as SearchableDropdownField<T>;

  @override
  void didUpdateWidget(covariant SearchableDropdownField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      setValue(widget.value);
    }
  }

  Future<void> _openPicker() async {
    if (!widget.enabled || widget.onChanged == null) return;
    FocusScope.of(context).unfocus();
    final result = await showModalBottomSheet<_SearchableSelection<T>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SearchablePickerSheet<T>(
        title:
            widget.dialogTitle ??
            widget.decoration.labelText ??
            'Select option',
        items: widget.items,
        selectedValue: value,
        itemLabel: widget.itemLabel,
        itemSearchText: widget.itemSearchText,
        searchHintText: widget.searchHintText,
        emptyText: widget.emptyText,
        clearable: widget.clearable,
        clearLabel: widget.clearLabel,
      ),
    );
    if (!mounted || result == null) return;
    didChange(result.value);
    widget.onChanged?.call(result.value);
  }

  Widget _buildField() {
    final enabled = widget.enabled && widget.onChanged != null;
    final selected = value;
    final text = selected == null ? widget.hintText : widget.itemLabel(selected);
    final baseStyle = widget.style ?? Theme.of(context).textTheme.bodyMedium;

    return InkWell(
      onTap: enabled ? _openPicker : null,
      borderRadius: AppRadius.md,
      child: InputDecorator(
        isEmpty: selected == null,
        decoration: widget.decoration.copyWith(
          enabled: enabled,
          errorText: errorText,
          hintText: null,
          suffixIcon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: enabled ? AppColors.textSecondary : AppColors.textMuted,
          ),
        ),
        child: Text(
          text ?? 'Select',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: baseStyle?.copyWith(
            color: selected == null ? AppColors.textMuted : baseStyle.color,
          ),
        ),
      ),
    );
  }
}

class _SearchableSelection<T> {
  const _SearchableSelection(this.value);

  final T? value;
}

class _SearchablePickerSheet<T> extends StatefulWidget {
  const _SearchablePickerSheet({
    required this.title,
    required this.items,
    required this.selectedValue,
    required this.itemLabel,
    required this.itemSearchText,
    required this.searchHintText,
    required this.emptyText,
    required this.clearable,
    required this.clearLabel,
  });

  final String title;
  final List<T> items;
  final T? selectedValue;
  final String Function(T item) itemLabel;
  final String Function(T item)? itemSearchText;
  final String searchHintText;
  final String emptyText;
  final bool clearable;
  final String clearLabel;

  @override
  State<_SearchablePickerSheet<T>> createState() =>
      _SearchablePickerSheetState<T>();
}

class _SearchablePickerSheetState<T>
    extends State<_SearchablePickerSheet<T>> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<T> get _visibleItems {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.items;
    return widget.items.where((item) {
      final searchable =
          widget.itemSearchText?.call(item) ?? widget.itemLabel(item);
      return searchable.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _visibleItems;
    return FractionallySizedBox(
      heightFactor: 0.78,
      child: Material(
        color: AppColors.surfaceModal,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: widget.searchHintText,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: visibleItems.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          widget.emptyText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      children: [
                        if (widget.clearable && _query.isEmpty)
                          ListTile(
                            leading: const Icon(Icons.clear),
                            title: Text(widget.clearLabel),
                            onTap: () => Navigator.pop(
                              context,
                              const _SearchableSelection(null),
                            ),
                          ),
                        for (final item in visibleItems)
                          ListTile(
                            leading: Icon(
                              item == widget.selectedValue
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: item == widget.selectedValue
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            title: Text(widget.itemLabel(item)),
                            selected: item == widget.selectedValue,
                            selectedColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.sm,
                            ),
                            onTap: () => Navigator.pop(
                              context,
                              _SearchableSelection<T>(item),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
