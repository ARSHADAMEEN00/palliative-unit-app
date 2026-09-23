import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oruma_app/features/visit_assessment/presentation/providers/visit_assessment_controller.dart';
import 'package:oruma_app/features/visit_assessment/presentation/widgets/assessment_widgets.dart';

const _visitModeOptions = <({String value, String label, IconData icon})>[
  (value: 'new', label: 'New', icon: Icons.add_circle_outline),
  (value: 'monthly', label: 'Planned NHC', icon: Icons.calendar_month_outlined),
  (value: 'emergency', label: 'Emergency', icon: Icons.emergency),
  (value: 'dhc_visit', label: 'DHC', icon: Icons.home_work_outlined),
  (value: 'vhc_visit', label: 'VHC', icon: Icons.local_hospital_outlined),
];

class VisitHeaderStep extends StatelessWidget {
  const VisitHeaderStep({
    super.key,
    required this.controller,
    this.allowVisitDateChange = true,
  });

  final VisitAssessmentController controller;
  final bool allowVisitDateChange;

  @override
  Widget build(BuildContext context) {

    final assessment = controller.assessment;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      children: [
        const AssessmentSectionTitle('Visit Information'),
        const SizedBox(height: 15),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AssessmentLabel('Patient'),
                  AssessmentTextField(
                    initialValue: assessment.patientName,
                    readOnly: true,
                    suffixIcon: const Icon(Icons.person_outline, size: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AssessmentLabel('Age'),
                  AssessmentTextField(
                    initialValue: assessment.patientAge,
                    onChanged: (value) => controller.update(
                      (item) => item.copyWith(patientAge: value),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AssessmentLabel('Reg No.', required: true),
                  AssessmentTextField(
                    initialValue: assessment.regNo,
                    onChanged: (value) => controller.update(
                      (item) => item.copyWith(regNo: value),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const AssessmentLabel('Visit Date', required: true),
        AssessmentTextField(
          key: const ValueKey('visit-date-field'),
          initialValue: DateFormat('dd MMM yyyy').format(assessment.visitDate),
          readOnly: true,
          suffixIcon: Icon(
            allowVisitDateChange
                ? Icons.calendar_today_outlined
                : Icons.lock_outline,
            size: 17,
          ),
          onTap: allowVisitDateChange ? () => _pickDate(context) : null,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _timeField(context, 'Time From', true)),
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 21, 12, 0),
              child: Icon(Icons.arrow_forward, size: 18),
            ),
            Expanded(child: _timeField(context, 'Time To', false)),
          ],
        ),
        const SizedBox(height: 14),
        const AssessmentLabel('Team', required: true),
        AssessmentTextField(
          initialValue: assessment.team,
          hint: 'Enter team name',
          suffixIcon: const Icon(Icons.groups_outlined, size: 18),
          onChanged: (value) =>
              controller.update((item) => item.copyWith(team: value)),
        ),
        const SizedBox(height: 14),
        const AssessmentLabel('Name of Nurse', required: true),
        AssessmentTextField(
          key: const ValueKey('visit-nurse-name'),
          initialValue: assessment.nurseName,
          hint: 'Enter nurse name',
          suffixIcon: const Icon(Icons.badge_outlined, size: 18),
          onChanged: (value) =>
              controller.update((item) => item.copyWith(nurseName: value)),
        ),
        const SizedBox(height: 14),
        const AssessmentLabel('Visit Mode'),
        _visitModeChips(),
        const SizedBox(height: 17),
        const AssessmentLabel('Visit Type'),
        AssessmentSegment(
          options: const ['NHC', 'DHC', 'GVHC', 'other'],
          selected: assessment.visitType,
          labels: const {'other': 'Other'},
          onSelected: (value) =>
              controller.update((item) => item.copyWith(visitType: value)),
        ),
      ],
    );
  }

  Widget _visitModeChips() {
    final selected = controller.assessment.visitMode;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _visitModeOptions.map((option) {
        final isSelected = selected == option.value;
        final isEmergency = option.value == 'emergency';
        final selectedColor = isEmergency ? assessmentDanger : assessmentGreen;
        return ChoiceChip(
          key: ValueKey('visit-mode-${option.value}'),
          selected: isSelected,
          showCheckmark: false,
          avatar: Icon(
            option.icon,
            size: 16,
            color: isSelected
                ? selectedColor
                : isEmergency
                ? assessmentDanger
                : assessmentMuted,
          ),
          label: Text(option.label),
          labelStyle: TextStyle(
            color: isSelected ? selectedColor : assessmentText,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
          backgroundColor: Colors.white,
          selectedColor: selectedColor.withValues(alpha: 0.09),
          side: BorderSide(
            color: isSelected ? selectedColor : assessmentBorder,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onSelected: (_) => controller.update(
            (item) => item.copyWith(visitMode: option.value),
          ),
        );
      }).toList(),
    );
  }

  Widget _timeField(BuildContext context, String label, bool from) {
    final value = from
        ? controller.assessment.timeFrom
        : controller.assessment.timeTo;
    final parsed = _parseTime(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AssessmentLabel(label, required: true),
        AssessmentTextField(
          key: ValueKey('visit-time-$from-$value'),
          initialValue: parsed == null ? value : parsed.format(context),
          readOnly: true,
          suffixIcon: const Icon(Icons.access_time, size: 17),
          onTap: () => _pickTime(context, from, parsed),
        ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.assessment.visitDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      controller.update((item) => item.copyWith(visitDate: picked));
    }
  }

  Future<void> _pickTime(
    BuildContext context,
    bool from,
    TimeOfDay? current,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    final value =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    controller.update(
      (item) =>
          from ? item.copyWith(timeFrom: value) : item.copyWith(timeTo: value),
    );
  }

  TimeOfDay? _parseTime(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final parts = trimmed.split(':');
    if (parts.length != 2) return _parseDisplayTime(trimmed);
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return _parseDisplayTime(trimmed);
    return TimeOfDay(hour: hour, minute: minute);
  }

  TimeOfDay? _parseDisplayTime(String value) {
    try {
      final parsed = DateFormat.jm().parse(value);
      return TimeOfDay(hour: parsed.hour, minute: parsed.minute);
    } catch (_) {
      return null;
    }
  }
}
