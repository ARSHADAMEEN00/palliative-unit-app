import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oruma_app/features/visit_assessment/domain/visit_assessment.dart';
import 'package:oruma_app/features/visit_assessment/presentation/providers/visit_assessment_controller.dart';
import 'package:oruma_app/features/visit_assessment/presentation/widgets/assessment_widgets.dart';

class MedicinesStep extends StatefulWidget {
  const MedicinesStep({super.key, required this.controller});

  final VisitAssessmentController controller;

  @override
  State<MedicinesStep> createState() => _MedicinesStepState();
}

class _MedicinesStepState extends State<MedicinesStep> {
  static const int _minimumRows = 8;
  static const double _rowHeight = 42;
  static const double _groupHeaderHeight = 25;
  static const double _subHeaderHeight = 25;
  static const double _noWidth = 38;
  static const double _medicineStrengthWidth = 240;
  static const double _instructionWidth = 92;
  static const double _routeWidth = 38;
  static const double _durationWidth = 108;
  static const double _remarksWidth = 118;
  static const double _clearWidth = 36;
  static const _specifiedOptions = ['Yes', 'No'];
  static const _usageOptions = ['1-1-1', '1-0-1', '0-0-1', '1-0-0', 'SoS'];
  static const double _tableWidth =
      _noWidth +
      _medicineStrengthWidth +
      (_instructionWidth * 2) +
      (_routeWidth * 4) +
      _durationWidth +
      _remarksWidth +
      _clearWidth;

  final List<_MedicineTableRow> _rows = [];
  final ScrollController _tableScrollController = ScrollController();
  int _nextLocalId = 0;

  @override
  void initState() {
    super.initState();
    _replaceRows(widget.controller.assessment.medicines);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant MedicinesStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _replaceRows(widget.controller.assessment.medicines);
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    _tableScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPrevious = widget.controller.previousAssessments.any(
      (item) => item.medicines.isNotEmpty,
    );
    final isMalayalam = widget.controller.isMalayalam;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 22),
      children: [
        AssessmentSectionTitle(
          'Medicines',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasPrevious) ...[
                TextButton.icon(
                  onPressed: _copyPreviousMedicines,
                  icon: const Icon(Icons.copy_all_outlined, size: 15),
                  label: const Text('Copy Previous'),
                  style: TextButton.styleFrom(
                    foregroundColor: assessmentGreenDark,
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 10),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              OutlinedButton.icon(
                onPressed: _addRow,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Row'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: assessmentGreenDark,
                  visualDensity: VisualDensity.compact,
                  side: const BorderSide(color: Color(0xFFBBDDCF)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Type Medicine, Strength in one cell, like “Paracetamol, 500mg”. Any mark under P / G / S / O saves that source.',
          style: TextStyle(color: assessmentMuted, fontSize: 10, height: 1.3),
        ),
        const SizedBox(height: 10),
        Text(
          isMalayalam
              ? 'സ്ഥിരമായി കഴിക്കുന്ന മരുന്നുകൾ (മരുന്ന് അലർജി)'
              : 'Regular medications (Drug allergy)',
          style: const TextStyle(
            color: assessmentText,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        _medicineTable(isMalayalam),
        const SizedBox(height: 12),
        _complementarySelector(isMalayalam),
      ],
    );
  }

  Widget _complementarySelector(bool isMalayalam) {
    const options = ['Nil', 'Ay', 'H', 'U', 'Sd', 'N', 'O'];
    final selected = widget.controller.assessment.complementary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD9E1E4)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              isMalayalam ? 'കോംപ്ലിമെന്ററി മരുന്ന്' : 'Complementary Medicine',
              style: const TextStyle(
                color: assessmentText,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Rx:',
              style: TextStyle(
                color: assessmentGreenDark,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            for (var index = 0; index < options.length; index++) ...[
              _complementaryOption(options[index], selected),
              if (index != options.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: Text(
                    '/',
                    style: TextStyle(
                      color: assessmentMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _complementaryOption(String value, String selected) {
    final active = selected == value;
    return InkWell(
      onTap: () => widget.controller.update(
        (item) => item.copyWith(complementary: value),
      ),
      borderRadius: BorderRadius.circular(5),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: active ? assessmentGreen.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: active ? assessmentGreen : Colors.transparent,
          ),
        ),
        child: Text(
          value,
          style: TextStyle(
            color: active ? assessmentGreenDark : assessmentText,
            fontSize: 11,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _medicineTable(bool isMalayalam) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD9E1E4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SingleChildScrollView(
              controller: _tableScrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: _tableWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _tableHeader(isMalayalam),
                    for (var index = 0; index < _rows.length; index++)
                      _tableRow(_rows[index], index),
                  ],
                ),
              ),
            ),
            _tableScrollHandle(),
          ],
        ),
      ),
    );
  }

  Widget _tableScrollHandle() {
    return AnimatedBuilder(
      animation: _tableScrollController,
      builder: (context, _) {
        final hasScrollableTable =
            _tableScrollController.hasClients &&
            _tableScrollController.position.hasContentDimensions &&
            _tableScrollController.position.maxScrollExtent > 0;
        final max = hasScrollableTable
            ? _tableScrollController.position.maxScrollExtent
            : 1.0;
        final value = hasScrollableTable
            ? _tableScrollController.offset.clamp(0.0, max).toDouble()
            : 0.0;

        return Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE7ECEE))),
          ),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: assessmentGreen.withValues(alpha: 0.55),
              inactiveTrackColor: const Color(0xFFE2E8EA),
              thumbColor: assessmentGreen,
              overlayColor: assessmentGreen.withValues(alpha: 0.12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 13),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: max,
              onChanged: hasScrollableTable
                  ? (next) => _tableScrollController.jumpTo(next)
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _tableHeader(bool isMalayalam) {
    return Row(
      children: [
        _spanningHeaderCell(isMalayalam ? 'ക്രമനമ്പർ' : 'No', width: _noWidth),
        _spanningHeaderCell(
          isMalayalam ? 'മരുന്ന്, Strength' : 'Medicine, Strength',
          width: _medicineStrengthWidth,
        ),
        _groupHeaderCell(
          isMalayalam ? 'ഉപയോഗക്രമ' : 'Instructions',
          children: [
            (isMalayalam ? 'നിർദിഷ്ടം' : 'Specified', _instructionWidth),
            (isMalayalam ? 'ഉപയോഗം' : 'Usage', _instructionWidth),
          ],
        ),
        _groupHeaderCell(
          isMalayalam ? 'സ്രോതസ്സ' : 'Source',
          children: const [
            ('P', _routeWidth),
            ('G', _routeWidth),
            ('S', _routeWidth),
            ('O', _routeWidth),
          ],
        ),
        _spanningHeaderCell(
          isMalayalam ? 'കാലാവധി' : 'Duration',
          width: _durationWidth,
        ),
        _spanningHeaderCell(
          isMalayalam ? 'റിമാർക്സ്' : 'Remarks',
          width: _remarksWidth,
        ),
        _spanningHeaderCell('', width: _clearWidth, isLast: true),
      ],
    );
  }

  Widget _tableRow(_MedicineTableRow row, int index) {
    return Row(
      children: [
        _bodyCell(
          width: _noWidth,
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: assessmentMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        _textCell(
          row.medicineStrength,
          key: ValueKey('medicine-name-strength-$index'),
          width: _medicineStrengthWidth,
          hint: 'Medicine, 30mg',
        ),
        _dropdownCell(
          row.instructionSpecified,
          key: ValueKey('medicine-instruction-specified-$index'),
          width: _instructionWidth,
          hint: 'Specified',
          options: _specifiedOptions,
        ),
        _dropdownCell(
          row.instructionUsage,
          key: ValueKey('medicine-instruction-usage-$index'),
          width: _instructionWidth,
          hint: 'Usage',
          options: _usageOptions,
        ),
        _tickCell(
          row.routeP,
          key: ValueKey('medicine-route-p-$index'),
          width: _routeWidth,
        ),
        _tickCell(
          row.routeG,
          key: ValueKey('medicine-route-g-$index'),
          width: _routeWidth,
        ),
        _tickCell(
          row.routeS,
          key: ValueKey('medicine-route-s-$index'),
          width: _routeWidth,
        ),
        _tickCell(
          row.routeO,
          key: ValueKey('medicine-route-o-$index'),
          width: _routeWidth,
        ),
        _monthCell(row, index),
        _textCell(
          row.remarks,
          key: ValueKey('medicine-remarks-$index'),
          width: _remarksWidth,
          hint: 'Instruction',
        ),
        _bodyCell(
          width: _clearWidth,
          isLast: true,
          child: IconButton(
            tooltip: 'Clear row',
            visualDensity: VisualDensity.compact,
            onPressed: row.isEmpty ? null : () => _clearRow(index),
            icon: Icon(
              Icons.close,
              size: 15,
              color: row.isEmpty ? assessmentBorder : assessmentDanger,
            ),
          ),
        ),
      ],
    );
  }

  Widget _spanningHeaderCell(
    String label, {
    required double width,
    bool isLast = false,
  }) {
    return Container(
      width: width,
      height: _groupHeaderHeight + _subHeaderHeight + 1,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8F7),
        border: Border(
          right: isLast
              ? BorderSide.none
              : const BorderSide(color: Color(0xFFD9E1E4)),
          bottom: const BorderSide(color: Color(0xFFD9E1E4)),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: assessmentText,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _groupHeaderCell(
    String label, {
    required List<(String, double)> children,
  }) {
    final width = children.fold<double>(0, (total, child) => total + child.$2);
    return Container(
      width: width,
      height: _groupHeaderHeight + _subHeaderHeight + 1,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F8F7),
        border: Border(
          right: BorderSide(color: Color(0xFFD9E1E4)),
          bottom: BorderSide(color: Color(0xFFD9E1E4)),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: _groupHeaderHeight,
            child: Center(child: _headerText(label)),
          ),
          Container(
            height: _subHeaderHeight,
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFD9E1E4))),
            ),
            child: Row(
              children: [
                for (var index = 0; index < children.length; index++)
                  Expanded(
                    flex: children[index].$2.round(),
                    child: _subHeaderCell(
                      children[index].$1,
                      isLast: index == children.length - 1,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _subHeaderCell(String label, {bool isLast = false}) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
          right: isLast
              ? BorderSide.none
              : const BorderSide(color: Color(0xFFD9E1E4)),
        ),
      ),
      child: _headerText(label, small: true),
    );
  }

  Widget _headerText(String label, {bool small = false}) {
    return Text(
      label,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: assessmentText,
        fontSize: small ? 9 : 10,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _textCell(
    TextEditingController textController, {
    required Key key,
    required double width,
    String? hint,
    bool center = false,
  }) {
    return _bodyCell(
      width: width,
      child: TextField(
        key: key,
        controller: textController,
        onChanged: (_) => _rowChanged(),
        textAlign: center ? TextAlign.center : TextAlign.start,
        textInputAction: TextInputAction.next,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFFA8B0B8),
            fontSize: 9,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: center ? 2 : 6,
            vertical: 11,
          ),
        ),
      ),
    );
  }

  Widget _dropdownCell(
    TextEditingController textController, {
    required Key key,
    required double width,
    required String hint,
    required List<String> options,
  }) {
    final current = textController.text.trim();
    final selected = options.contains(current) ? current : null;
    return _bodyCell(
      width: width,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: key,
          value: selected,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              hint,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFA8B0B8),
                fontSize: 9,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 15),
          style: const TextStyle(
            color: assessmentText,
            fontSize: 10,
            fontWeight: FontWeight.normal,
          ),
          items: options
              .map(
                (option) => DropdownMenuItem(
                  value: option,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(option, overflow: TextOverflow.ellipsis),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => textController.text = value);
            _rowChanged();
          },
        ),
      ),
    );
  }

  Widget _tickCell(
    TextEditingController textController, {
    required Key key,
    required double width,
  }) {
    final active = textController.text.trim().isNotEmpty;
    return _bodyCell(
      width: width,
      child: InkWell(
        key: key,
        onTap: () {
          setState(() => textController.text = active ? '' : '✓');
          _rowChanged();
        },
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: active ? assessmentGreen : Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: active ? assessmentGreen : assessmentBorder,
                width: 1.4,
              ),
            ),
            child: active
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }

  Widget _monthCell(_MedicineTableRow row, int index) {
    return _bodyCell(
      width: _durationWidth,
      child: TextField(
        key: ValueKey('medicine-duration-$index'),
        controller: row.duration,
        readOnly: true,
        onTap: () => _pickDurationMonth(row),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        decoration: const InputDecoration(
          hintText: 'Month',
          hintStyle: TextStyle(
            color: Color(0xFFA8B0B8),
            fontSize: 9,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
          isDense: true,
          suffixIcon: Icon(Icons.calendar_month_outlined, size: 15),
          suffixIconConstraints: BoxConstraints(minWidth: 22, minHeight: 22),
          contentPadding: EdgeInsets.fromLTRB(6, 11, 3, 10),
        ),
      ),
    );
  }

  Widget _bodyCell({
    required double width,
    required Widget child,
    bool isLast = false,
  }) {
    return Container(
      width: width,
      height: _rowHeight,
      decoration: BoxDecoration(
        border: Border(
          right: isLast
              ? BorderSide.none
              : const BorderSide(color: Color(0xFFD9E1E4)),
          bottom: const BorderSide(color: Color(0xFFE7ECEE)),
        ),
      ),
      child: child,
    );
  }

  Future<void> _pickDurationMonth(_MedicineTableRow row) async {
    final now = DateTime.now();
    final initial = _parseMonth(row.duration.text) ?? now;
    var visibleYear = initial.year;
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              title: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous year',
                    onPressed: () => setDialogState(() => visibleYear -= 1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      visibleYear.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next year',
                    onPressed: () => setDialogState(() => visibleYear += 1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              content: SizedBox(
                width: 320,
                child: GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.35,
                  children: List.generate(12, (index) {
                    final month = index + 1;
                    final isSelected =
                        visibleYear == initial.year && month == initial.month;
                    return OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isSelected
                            ? assessmentGreenDark
                            : assessmentText,
                        backgroundColor: isSelected
                            ? assessmentMint
                            : Colors.white,
                        side: BorderSide(
                          color: isSelected
                              ? assessmentGreen
                              : assessmentBorder,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => Navigator.pop(
                        dialogContext,
                        DateTime(visibleYear, month),
                      ),
                      child: Text(
                        DateFormat('MMM').format(DateTime(2020, month)),
                      ),
                    );
                  }),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
    if (picked == null) return;
    setState(() => row.duration.text = _formatMonth(picked));
    _rowChanged();
  }

  DateTime? _parseMonth(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    try {
      return DateFormat('MMMM yyyy').parseStrict(trimmed);
    } catch (_) {
      try {
        return DateFormat('MMM yyyy').parseStrict(trimmed);
      } catch (_) {
        return null;
      }
    }
  }

  String _formatMonth(DateTime value) => DateFormat('MMMM yyyy').format(value);

  void _replaceRows(List<AssessmentMedicine> medicines) {
    for (final row in _rows) {
      row.dispose();
    }
    _rows
      ..clear()
      ..addAll(
        medicines.map(
          (medicine) =>
              _MedicineTableRow.fromMedicine(medicine, localId: _nextLocalId++),
        ),
      );
    _ensureMinimumRows();
  }

  void _ensureMinimumRows() {
    while (_rows.length < _minimumRows || _rows.last.hasContent) {
      _rows.add(_MedicineTableRow.blank(localId: _nextLocalId++));
    }
  }

  void _rowChanged() {
    final shouldAppendBlank = _rows.isNotEmpty && _rows.last.hasContent;
    if (shouldAppendBlank) {
      setState(_ensureMinimumRows);
    }
    _commitRows();
  }

  void _addRow() {
    setState(() {
      _rows.add(_MedicineTableRow.blank(localId: _nextLocalId++));
    });
  }

  void _clearRow(int index) {
    if (index < 0 || index >= _rows.length) return;
    setState(() {
      _rows[index].clear();
    });
    _commitRows();
  }

  void _copyPreviousMedicines() {
    widget.controller.copyMedicinesFromPrevious();
    setState(() => _replaceRows(widget.controller.assessment.medicines));
  }

  void _commitRows() {
    final medicines = _rows
        .where((row) => row.hasContent)
        .map((row) => row.toMedicine())
        .toList(growable: false);
    widget.controller.update((item) => item.copyWith(medicines: medicines));
  }
}

class _MedicineTableRow {
  _MedicineTableRow({
    required this.localId,
    this.id,
    this.medicineId,
    this.originalMedicineName = '',
    String medicineName = '',
    String strength = '',
    String instructionSpecified = '',
    String instructionUsage = '',
    Set<String> routes = const {},
    String duration = '',
    String remarks = '',
  }) : medicineStrength = TextEditingController(
         text: _formatMedicineStrength(medicineName, strength),
       ),
       instructionSpecified = TextEditingController(
         text: _sanitizeSpecified(instructionSpecified),
       ),
       instructionUsage = TextEditingController(
         text: _sanitizeUsage(instructionUsage),
       ),
       routeP = TextEditingController(text: routes.contains('P') ? '✓' : ''),
       routeG = TextEditingController(text: routes.contains('G') ? '✓' : ''),
       routeS = TextEditingController(text: routes.contains('S') ? '✓' : ''),
       routeO = TextEditingController(text: routes.contains('O') ? '✓' : ''),
       duration = TextEditingController(text: _sanitizeDuration(duration)),
       remarks = TextEditingController(text: remarks);

  factory _MedicineTableRow.blank({required int localId}) =>
      _MedicineTableRow(localId: localId);

  factory _MedicineTableRow.fromMedicine(
    AssessmentMedicine medicine, {
    required int localId,
  }) => _MedicineTableRow(
    localId: localId,
    id: medicine.id,
    medicineId: medicine.medicineId,
    originalMedicineName: medicine.medicineName,
    medicineName: medicine.medicineName,
    strength: medicine.strength,
    instructionSpecified: medicine.instructionSpecified,
    instructionUsage: medicine.instructionUsage,
    routes: medicine.routes,
    duration: medicine.duration,
    remarks: medicine.remarks,
  );

  final int localId;
  final String? id;
  final String? medicineId;
  final String originalMedicineName;
  final TextEditingController medicineStrength;
  final TextEditingController instructionSpecified;
  final TextEditingController instructionUsage;
  final TextEditingController routeP;
  final TextEditingController routeG;
  final TextEditingController routeS;
  final TextEditingController routeO;
  final TextEditingController duration;
  final TextEditingController remarks;

  bool get hasContent =>
      medicineStrength.text.trim().isNotEmpty ||
      instructionSpecified.text.trim().isNotEmpty ||
      instructionUsage.text.trim().isNotEmpty ||
      routeP.text.trim().isNotEmpty ||
      routeG.text.trim().isNotEmpty ||
      routeS.text.trim().isNotEmpty ||
      routeO.text.trim().isNotEmpty ||
      duration.text.trim().isNotEmpty ||
      remarks.text.trim().isNotEmpty;

  bool get isEmpty => !hasContent;

  AssessmentMedicine toMedicine() {
    final parsed = _parseMedicineStrength(medicineStrength.text);
    return AssessmentMedicine(
      id: id,
      medicineId: parsed.name == originalMedicineName ? medicineId : null,
      medicineName: parsed.name,
      strength: parsed.strength,
      instructionSpecified: _sanitizeSpecified(instructionSpecified.text),
      instructionUsage: _sanitizeUsage(instructionUsage.text),
      routes: {
        if (routeP.text.trim().isNotEmpty) 'P',
        if (routeG.text.trim().isNotEmpty) 'G',
        if (routeS.text.trim().isNotEmpty) 'S',
        if (routeO.text.trim().isNotEmpty) 'O',
      },
      duration: _sanitizeDuration(duration.text),
      remarks: remarks.text.trim(),
    );
  }

  void clear() {
    medicineStrength.clear();
    instructionSpecified.clear();
    instructionUsage.clear();
    routeP.clear();
    routeG.clear();
    routeS.clear();
    routeO.clear();
    duration.clear();
    remarks.clear();
  }

  void dispose() {
    medicineStrength.dispose();
    instructionSpecified.dispose();
    instructionUsage.dispose();
    routeP.dispose();
    routeG.dispose();
    routeS.dispose();
    routeO.dispose();
    duration.dispose();
    remarks.dispose();
  }

  static String _formatMedicineStrength(String medicineName, String strength) {
    final trimmedName = medicineName.trim();
    final trimmedStrength = strength.trim();
    if (trimmedName.isEmpty) return trimmedStrength;
    if (trimmedStrength.isEmpty) return trimmedName;
    return '$trimmedName, $trimmedStrength';
  }

  static String _sanitizeSpecified(String value) {
    final trimmed = value.trim();
    return const {'Yes', 'No'}.contains(trimmed) ? trimmed : '';
  }

  static String _sanitizeUsage(String value) {
    final trimmed = value.trim();
    return const {'1-1-1', '1-0-1', '0-0-1', '1-0-0', 'SoS'}.contains(trimmed)
        ? trimmed
        : '';
  }

  static String _sanitizeDuration(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    for (final pattern in const ['MMMM yyyy', 'MMM yyyy']) {
      try {
        final date = DateFormat(pattern).parseStrict(trimmed);
        return DateFormat('MMMM yyyy').format(date);
      } catch (_) {
        continue;
      }
    }
    return '';
  }

  static ({String name, String strength}) _parseMedicineStrength(String value) {
    final trimmed = value.trim();
    final commaIndex = trimmed.indexOf(',');
    if (commaIndex < 0) return (name: trimmed, strength: '');
    return (
      name: trimmed.substring(0, commaIndex).trim(),
      strength: trimmed.substring(commaIndex + 1).trim(),
    );
  }
}
