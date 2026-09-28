import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oruma_app/core/theme/app_colors.dart';
import 'package:oruma_app/core/theme/app_radius.dart';
import 'package:oruma_app/core/theme/app_spacing.dart';
import 'package:oruma_app/features/reports/data/report_service.dart';
import 'package:oruma_app/features/reports/models/report_models.dart';
import 'package:oruma_app/features/reports/pdf/report_pdf_generator.dart';
import 'package:oruma_app/features/reports/presentation/report_config.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

Future<void> openReports(
  BuildContext context, {
  ReportType initialReport = ReportType.medicineStock,
}) {
  final auth = context.read<AuthService>();
  if (!auth.canAccessReports) {
    final message = auth.isAdmin || auth.isMember
        ? 'Advanced Reports is not enabled for this unit.'
        : 'Reports are available only to administrators and members.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    return Future<void>.value();
  }
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ReportsPage(initialReport: initialReport),
    ),
  );
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, this.initialReport = ReportType.medicineStock});

  final ReportType initialReport;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late ReportType _type;
  late ReportFilters _filters;
  late final TextEditingController _searchController;
  ReportResult? _result;
  bool _loading = false;
  bool _exporting = false;
  String? _error;
  Timer? _searchDebounce;

  ReportDefinition get _definition => reportDefinitions[_type]!;

  @override
  void initState() {
    super.initState();
    _type = widget.initialReport;
    _filters = _defaultFilters(_type);
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.read<AuthService>().canAccessReports) _load();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({int? page}) async {
    if (_loading) return;
    if (page != null) _filters = _filters.copyWith(page: page);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ReportService.fetch(_type, _filters);
      if (!mounted) return;
      setState(() => _result = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectReport(ReportType type) {
    if (type == _type) return;
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _type = type;
      _filters = _defaultFilters(type);
      _result = null;
      _error = null;
    });
    _load();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      _filters = _filters.copyWith(search: value, page: 1);
      _load();
    });
  }

  Future<void> _exportPdf() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final report = await ReportService.fetch(_type, _filters, export: true);
      if (!mounted) return;
      final auth = context.read<AuthService>();
      final bytes = await ReportPdfGenerator.generate(
        definition: _definition,
        report: report,
        filters: _filters,
        unitName: auth.unitName,
        unitLocation: auth.unitLocation,
        generatedBy: auth.user?['name']?.toString() ?? auth.role ?? 'User',
        logoSource: auth.unitLogo ?? auth.unitAppIcon,
      );
      await Printing.layoutPdf(
        name: ReportPdfGenerator.fileName(_type),
        onLayout: (_) async => bytes,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(error)),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.canAccessReports) {
      return AdaptiveAppScaffold(
        appBar: AppBar(title: const Text('Reports')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  auth.isAdmin || auth.isMember
                      ? 'Advanced Reports is not enabled for this unit.'
                      : 'Reports are available only to administrators and members.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AdaptiveAppScaffold(
      backgroundColor: AppColors.background,
      contentMaxWidth: 1280,
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        actions: [
          IconButton(
            tooltip: 'Export PDF',
            onPressed: _exporting || _loading ? null : _exportPdf,
            icon: _exporting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Column(
        children: [
          _ReportSelector(selected: _type, onSelected: _selectReport),
          _buildToolbar(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    final dateFormat = DateFormat('dd MMM');
    final period = _filters.from == null && _filters.to == null
        ? 'All time'
        : '${_filters.from == null ? 'Start' : dateFormat.format(_filters.from!)} – '
              '${_filters.to == null ? 'Today' : dateFormat.format(_filters.to!)}';

    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(
        AppInsets.screenHorizontal(context),
        AppSpacing.xs,
        AppInsets.screenHorizontal(context),
        AppSpacing.md,
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search ${_type.label.toLowerCase()} records',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        _filters = _filters.copyWith(search: '', page: 1);
                        setState(() {});
                        _load();
                      },
                      icon: const Icon(Icons.close),
                    ),
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
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.date_range_outlined, size: 18),
                      label: Text(period),
                      onPressed: _showFilters,
                    ),
                    ActionChip(
                      avatar: Badge(
                        isLabelVisible: _filters.activeFilterCount > 0,
                        label: Text('${_filters.activeFilterCount}'),
                        child: const Icon(Icons.filter_list, size: 18),
                      ),
                      label: const Text('Filters'),
                      onPressed: _showFilters,
                    ),
                    ActionChip(
                      avatar: Icon(
                        _filters.sortOrder == 'asc'
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 18,
                      ),
                      label: Text(_sortLabel()),
                      onPressed: _showSort,
                    ),
                  ],
                ),
              ),
              if (_filters.activeFilterCount > 0 || _filters.search.isNotEmpty)
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _filters = _defaultFilters(_type));
                    _load();
                  },
                  child: const Text('Reset'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading && _result == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _result == null) {
      return _ReportMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load report',
        message: _error!,
        action: OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );
    }

    final result = _result;
    if (result == null) return const SizedBox.shrink();
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: AppInsets.screen(context, top: AppSpacing.md),
                sliver: SliverList.list(
                  children: [
                    _buildSummary(result),
                    const SizedBox(height: AppSpacing.md),
                    if (result.rows.isEmpty)
                      const SizedBox(
                        height: 280,
                        child: _ReportMessage(
                          icon: Icons.query_stats_outlined,
                          title: 'No matching records',
                          message: 'Try changing the date range or filters.',
                        ),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return constraints.maxWidth >= 760
                              ? _buildTable(result)
                              : _buildCards(result);
                        },
                      ),
                    if (result.pagination.totalPages > 1) ...[
                      const SizedBox(height: AppSpacing.md),
                      _buildPagination(result.pagination),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_loading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  Widget _buildSummary(ReportResult result) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _definition.summaryLabels.entries.map((entry) {
          final value = result.summary[entry.key] ?? 0;
          final warning =
              entry.key == 'lowStock' ||
              entry.key == 'expiringSoon' ||
              entry.key == 'dueSoon';
          final danger =
              entry.key == 'outOfStock' ||
              entry.key == 'expired' ||
              entry.key == 'overdue' ||
              entry.key == 'lost';
          final color = danger
              ? AppColors.danger
              : warning
              ? AppColors.warning
              : _definition.color;
          return Container(
            width: 142,
            margin: const EdgeInsets.only(right: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.card,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  formatReportValue(entry.key, value),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTable(ReportResult result) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: const WidgetStatePropertyAll(AppColors.surface2),
          columns: _definition.columns
              .map(
                (column) => DataColumn(
                  numeric: column.numeric,
                  label: Text(
                    column.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              )
              .toList(),
          rows: result.rows.map((row) {
            return DataRow(
              cells: _definition.columns
                  .map(
                    (column) => DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 210),
                        child: Text(
                          formatReportValue(column.key, row[column.key]),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCards(ReportResult result) {
    final primaryColumn = _definition.columns.length > 1
        ? _definition.columns[1]
        : _definition.columns.first;
    final detailColumns = _definition.columns
        .where((column) => column.key != primaryColumn.key)
        .toList(growable: false);
    return Column(
      children: result.rows.map((row) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.card,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _definition.color.withValues(alpha: 0.1),
                      borderRadius: AppRadius.sm,
                    ),
                    child: Icon(
                      _definition.icon,
                      color: _definition.color,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      formatReportValue(
                        primaryColumn.key,
                        row[primaryColumn.key],
                      ),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columnCount = constraints.maxWidth >= 520 ? 3 : 2;
                  final spacing = AppSpacing.sm * (columnCount - 1);
                  final itemWidth =
                      (constraints.maxWidth - spacing) / columnCount;
                  return Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: detailColumns.map((column) {
                      return SizedBox(
                        width: itemWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              column.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              formatReportValue(column.key, row[column.key]),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.2,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPagination(ReportPagination pagination) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Previous page',
          onPressed: pagination.page > 1 && !_loading
              ? () => _load(page: pagination.page - 1)
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          'Page ${pagination.page} of ${pagination.totalPages} '
          '(${pagination.totalRows} records)',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        IconButton(
          tooltip: 'Next page',
          onPressed: pagination.page < pagination.totalPages && !_loading
              ? () => _load(page: pagination.page + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  String _sortLabel() {
    final field = _filters.sortBy;
    if (field.isEmpty) return 'Sort';
    for (final sort in _definition.sorts) {
      if (sort.field == field) return sort.label;
    }
    return 'Sort';
  }

  TextStyle _compactDropdownTextStyle() {
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.2,
    );
  }

  InputDecoration _compactDropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w400,
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    );
  }

  Future<void> _showSort() async {
    var field = _filters.sortBy.isEmpty
        ? _definition.sorts.first.field
        : _filters.sortBy;
    var order = _filters.sortOrder;
    final result = await showModalBottomSheet<(String, String)>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sort report',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String>(
                    initialValue: field,
                    isDense: true,
                    itemHeight: 48,
                    menuMaxHeight: 320,
                    style: _compactDropdownTextStyle(),
                    decoration: _compactDropdownDecoration('Sort by'),
                    items: _definition.sorts
                        .map(
                          (sort) => DropdownMenuItem(
                            value: sort.field,
                            child: Text(
                              sort.label,
                              style: _compactDropdownTextStyle(),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setModalState(() => field = value ?? field),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<String>(
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      textStyle: const WidgetStatePropertyAll(
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
                      ),
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    segments: const [
                      ButtonSegment(
                        value: 'asc',
                        label: Text('Ascending'),
                        icon: Icon(Icons.arrow_upward),
                      ),
                      ButtonSegment(
                        value: 'desc',
                        label: Text('Descending'),
                        icon: Icon(Icons.arrow_downward),
                      ),
                    ],
                    selected: {order},
                    onSelectionChanged: (value) =>
                        setModalState(() => order = value.first),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, (field, order)),
                      child: const Text('Apply sort'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (result == null) return;
    setState(() {
      _filters = _filters.copyWith(
        sortBy: result.$1,
        sortOrder: result.$2,
        page: 1,
      );
    });
    _load();
  }

  Future<void> _showFilters() async {
    var from = _filters.from;
    var to = _filters.to;
    var extra = Map<String, String>.from(_filters.extra);
    final lowStockController = TextEditingController(
      text: extra['lowStockThreshold'] ?? '10',
    );
    final expiryController = TextEditingController(
      text: extra['expiryDays'] ?? '60',
    );
    final result = await showModalBottomSheet<ReportFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> pickDate(bool start) async {
            final selected = await showDatePicker(
              context: context,
              initialDate: (start ? from : to) ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime.now().add(const Duration(days: 3650)),
            );
            if (selected == null) return;
            setModalState(() {
              if (start) {
                from = selected;
              } else {
                to = selected;
              }
            });
          }

          void setPreset(String preset) {
            final now = DateTime.now();
            setModalState(() {
              switch (preset) {
                case 'month':
                  from = DateTime(now.year, now.month);
                  to = DateTime(now.year, now.month + 1, 0);
                case '30':
                  from = now.subtract(const Duration(days: 29));
                  to = now;
                case '90':
                  from = now.subtract(const Duration(days: 89));
                  to = now;
                case 'all':
                  from = null;
                  to = null;
              }
            });
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Filter ${_type.label}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: () => setModalState(() {
                            from = null;
                            to = null;
                            extra = {};
                            lowStockController.text = '10';
                            expiryController.text = '60';
                          }),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: [
                        ActionChip(
                          label: const Text('This month'),
                          onPressed: () => setPreset('month'),
                        ),
                        ActionChip(
                          label: const Text('Last 30 days'),
                          onPressed: () => setPreset('30'),
                        ),
                        ActionChip(
                          label: const Text('Last 90 days'),
                          onPressed: () => setPreset('90'),
                        ),
                        ActionChip(
                          label: const Text('All time'),
                          onPressed: () => setPreset('all'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _DateField(
                            label: 'From',
                            value: from,
                            onTap: () => pickDate(true),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _DateField(
                            label: 'To',
                            value: to,
                            onTap: () => pickDate(false),
                          ),
                        ),
                      ],
                    ),
                    ..._definition.filters.map((filter) {
                      final current = extra[filter.key] ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: DropdownButtonFormField<String>(
                          initialValue:
                              filter.choices.any(
                                (choice) => choice.value == current,
                              )
                              ? current
                              : '',
                          isDense: true,
                          itemHeight: 48,
                          menuMaxHeight: 320,
                          style: _compactDropdownTextStyle(),
                          decoration: _compactDropdownDecoration(filter.label),
                          items: filter.choices
                              .map(
                                (choice) => DropdownMenuItem(
                                  value: choice.value,
                                  child: Text(
                                    choice.label,
                                    style: _compactDropdownTextStyle(),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setModalState(
                            () => extra[filter.key] = value ?? '',
                          ),
                        ),
                      );
                    }),
                    if (_type == ReportType.medicineStock) ...[
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: lowStockController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Low stock threshold',
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: TextField(
                              controller: expiryController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Expiry window (days)',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          if (_type == ReportType.medicineStock) {
                            extra['lowStockThreshold'] = lowStockController.text
                                .trim();
                            extra['expiryDays'] = expiryController.text.trim();
                          }
                          Navigator.pop(
                            context,
                            _filters.copyWith(
                              from: from,
                              to: to,
                              clearFrom: from == null,
                              clearTo: to == null,
                              extra: extra,
                              page: 1,
                            ),
                          );
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Apply filters'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    lowStockController.dispose();
    expiryController.dispose();
    if (result == null) return;
    setState(() => _filters = result);
    _load();
  }

  String _friendlyError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  ReportFilters _defaultFilters(ReportType type) {
    return switch (type) {
      ReportType.medicineStock ||
      ReportType.equipmentStock => const ReportFilters(),
      _ => ReportFilters.currentMonth(),
    };
  }
}

class _ReportSelector extends StatelessWidget {
  const _ReportSelector({required this.selected, required this.onSelected});

  final ReportType selected;
  final ValueChanged<ReportType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(
        AppInsets.screenHorizontal(context),
        AppSpacing.sm,
        AppInsets.screenHorizontal(context),
        AppSpacing.xs,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ReportType.values.map((type) {
            final definition = reportDefinitions[type]!;
            final isSelected = type == selected;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: ChoiceChip(
                selected: isSelected,
                showCheckmark: false,
                avatar: Icon(
                  definition.icon,
                  size: 18,
                  color: isSelected
                      ? definition.color
                      : AppColors.textSecondary,
                ),
                label: Text(type.label),
                onSelected: (_) => onSelected(type),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.input,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_month_outlined),
        ),
        child: Text(
          value == null ? 'Any date' : DateFormat('dd MMM yyyy').format(value!),
        ),
      ),
    );
  }
}

class _ReportMessage extends StatelessWidget {
  const _ReportMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.md),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
