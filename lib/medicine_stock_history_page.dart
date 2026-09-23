import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oruma_app/models/medicine_stock_entry.dart';
import 'package:oruma_app/services/medicine_stock_service.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';

const _medicineGreen = Color(0xFF0F6E56);
const _medicineDarkGreen = Color(0xFF0A4A3A);
const _medicineSurface = Color(0xFFE1F5EE);
const _medicineIconBackground = Color(0xFF9FE1CB);

class MedicineStockHistoryPage extends StatefulWidget {
  const MedicineStockHistoryPage({super.key});

  @override
  State<MedicineStockHistoryPage> createState() =>
      _MedicineStockHistoryPageState();
}

class _MedicineStockHistoryPageState extends State<MedicineStockHistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<MedicineStockEntry> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearch);
    _loadHistory();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _loadHistory(showLoader: false),
    );
    setState(() {});
  }

  Future<void> _loadHistory({bool showLoader = true}) async {
    final search = _searchController.text.trim();
    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final entries = await MedicineStockService.getHistory(
        search: search.isEmpty ? null : search,
      );
      if (!mounted || search != _searchController.text.trim()) return;
      setState(() {
        _entries = entries;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || search != _searchController.text.trim()) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveAppScaffold(
      backgroundColor: const Color(0xFFF5FAF8),
      appBar: AppBar(
        backgroundColor: _medicineDarkGreen,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Stock History',
          style: TextStyle(fontSize: 18, color: Colors.white),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadHistory,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _searchField(),
          Expanded(child: _content()),
        ],
      ),
      contentMaxWidth: 900,
    );
  }

  Widget _searchField() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search medicine, batch or note',
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          prefixIcon: const Icon(Icons.search, size: 18),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 38,
            minHeight: 38,
          ),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: _searchController.clear,
                  icon: const Icon(Icons.close, size: 20),
                ),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _medicineGreen, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _medicineGreen),
      );
    }
    if (_error != null) {
      return _messageState(
        Icons.cloud_off_outlined,
        'Could not load stock history',
        _error!,
        action: OutlinedButton.icon(
          onPressed: _loadHistory,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );
    }
    if (_entries.isEmpty) {
      return _messageState(
        Icons.history_outlined,
        _searchController.text.trim().isEmpty
            ? 'No stock entries yet'
            : 'No stock entries found',
        _searchController.text.trim().isEmpty
            ? 'New stock entries will appear here.'
            : 'Try another medicine name, batch number or note.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: _medicineGreen,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 18),
        itemCount: _entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _historyCard(_entries[index]),
      ),
    );
  }

  Widget _historyCard(MedicineStockEntry entry) {
    final footer = [
      if (entry.note?.trim().isNotEmpty == true) entry.note!.trim(),
      if (entry.createdBy?.name?.trim().isNotEmpty == true)
        'Added by ${entry.createdBy!.name}',
    ].join('  •  ');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: _medicineDarkGreen.withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _medicineIconBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: _medicineGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.medicineName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                if (entry.medicineCode.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.medicineCode,
                    style: const TextStyle(
                      color: _medicineDarkGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    _detailChip(
                      Icons.add_box_outlined,
                      'Avail ${_number(entry.quantity)} ${_unitLabel(entry.qtyUnit)}',
                      strong: true,
                    ),
                    if (entry.originalQuantity != entry.quantity)
                      _detailChip(
                        Icons.playlist_add_check_outlined,
                        'Received ${_number(entry.originalQuantity)}',
                      ),
                    _detailChip(
                      Icons.event_available_outlined,
                      _formatDate(entry.entryDate),
                    ),
                    _detailChip(
                      Icons.event_busy_outlined,
                      'Exp ${_formatDate(entry.expiryDate)}',
                    ),
                    if (entry.batchNumber?.trim().isNotEmpty == true)
                      _detailChip(
                        Icons.confirmation_number_outlined,
                        entry.batchNumber!.trim(),
                      ),
                    _detailChip(Icons.label_outline, _sourceText(entry)),
                  ],
                ),
                if (footer.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    footer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailChip(IconData icon, String text, {bool strong = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: strong ? _medicineSurface : const Color(0xFFF5FAF8),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _medicineGreen),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: strong ? _medicineDarkGreen : Colors.grey.shade700,
              fontSize: 11,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _sourceText(MedicineStockEntry entry) {
    final label = entry.sourceLabel.trim().isEmpty
        ? 'Main Stock'
        : entry.sourceLabel.trim();
    final patientName = entry.sourcePatientName?.trim();
    final registerId = entry.sourcePatientRegisterId?.trim();
    if (entry.sourceType == 'return' &&
        patientName != null &&
        patientName.isNotEmpty) {
      final patientText = registerId != null && registerId.isNotEmpty
          ? '$patientName ($registerId)'
          : patientName;
      return '$label • $patientText';
    }
    return label;
  }

  Widget _messageState(
    IconData icon,
    String title,
    String message, {
    Widget? action,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(30),
      children: [
        const SizedBox(height: 80),
        Icon(icon, size: 52, color: _medicineGreen),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
        if (action != null) ...[
          const SizedBox(height: 16),
          Center(child: action),
        ],
      ],
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date.toLocal());
  }

  String _number(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  String _unitLabel(String value) {
    return switch (value.trim().toLowerCase()) {
      'tab' => 'Tab',
      'bottle' => 'Bottle',
      'gel' => 'Gel',
      'piece' => 'Piece',
      '' => 'units',
      _ => value.trim(),
    };
  }

  String _friendlyError(Object error) {
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }
}
