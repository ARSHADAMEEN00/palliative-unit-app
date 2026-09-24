import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oruma_app/features/visit_assessment/data/visit_assessment_pdf_generator.dart';
import 'package:oruma_app/features/visit_assessment/data/visit_assessment_service.dart';
import 'package:oruma_app/features/visit_assessment/domain/visit_assessment.dart';
import 'package:oruma_app/features/visit_assessment/presentation/widgets/assessment_theme.dart';
import 'package:oruma_app/features/visit_assessment/presentation/widgets/assessment_widgets.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:provider/provider.dart';

class VisitAssessmentDetailScreen extends StatelessWidget {
  const VisitAssessmentDetailScreen({
    super.key,
    required this.assessment,
    this.onEdit,
  });

  final VisitAssessment assessment;
  final VoidCallback? onEdit;

  static const _primaryLabels = <String, String>{
    'respiration': 'Respiration',
    'foodWater': 'Food & Water Intake',
    'urine': 'Urine',
    'defecation': 'Defecation',
    'sleep': 'Sleep',
    'hygiene': 'Hygiene',
    'outdoorAccess': 'Outdoor Access / Exercise',
    'sexuality': 'Sexuality',
  };

  static const _headToFootLabels = <String, String>{
    'scalpHair': 'Scalp & Hair',
    'skin': 'Skin',
    'eyeNoseMouth': 'Eye, Nose, Ear',
    'oral': 'Oral',
    'nails': 'Nails',
    'perineum': 'Perineum',
    'pressureArea': 'Pressure Area',
    'hiddenArea': 'Hidden Area',
    'musclesJoints': 'Muscles & Joints',
    'specialAttention': 'Special Attention',
  };

  static const _serviceLabels = <String, String>{
    'healthEducation': 'Health Education',
    'familyTraining': 'Family Training',
    'physiotherapy': 'Physiotherapy',
    'dayCare': 'Day Care',
    'socialSupport': 'Social Support',
    'medicineSupport': 'Medicine Support',
  };

  static const _visitPlanLabels = <String, String>{
    'DHC': 'DHC',
    'NHC': 'NHC',
    'GVHC': 'GVHC',
    'other': 'Other',
  };

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();

    return Theme(
      data: visitAssessmentLightTheme(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: assessmentText, size: 20),
            onPressed: () => Navigator.maybePop(context),
            visualDensity: VisualDensity.compact,
          ),
          title: const Text('Assessment Details'),
          centerTitle: false,
          titleTextStyle: const TextStyle(
            color: assessmentText,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
          actions: [
            if (auth.canDelete && assessment.id != null)
              IconButton(
                tooltip: 'Delete assessment',
                onPressed: () => _deleteAssessment(context),
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                visualDensity: VisualDensity.compact,
              ),
            if (onEdit != null)
              IconButton(
                tooltip: 'Edit assessment',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 20),
                visualDensity: VisualDensity.compact,
              ),
            IconButton(
              tooltip: 'Create PDF',
              onPressed: () => _createPdf(context),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
              visualDensity: VisualDensity.compact,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: _StatusChip(
                  label: assessment.isComplete ? 'Completed' : 'Draft',
                  color: assessment.isComplete
                      ? assessmentGreen
                      : const Color(0xFFE48B16),
                ),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _patientHeader(),
            const SizedBox(height: 12),
            _section(
              title: 'Visit Information',
              children: [
                _InfoGrid(
                  items: [
                    _InfoItem('Visit Date', _date(assessment.visitDate)),
                    _InfoItem(
                      'Time',
                      _range(assessment.timeFrom, assessment.timeTo),
                    ),
                    _InfoItem('Visit Type', _value(assessment.visitType)),
                    _InfoItem('Team', _value(assessment.team)),
                    _InfoItem('Nurse', _value(assessment.nurseName)),
                    _InfoItem(
                      'Submitted',
                      assessment.submittedAt == null
                          ? '—'
                          : _dateTime(assessment.submittedAt!),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            _section(
              title: 'Previous Visit Concerns',
              children: [_BodyText(_value(assessment.previousVisitConcerns))],
            ),
            const SizedBox(height: 10),
            _section(title: 'Vitals', children: [_vitalsGrid()]),
            const SizedBox(height: 10),
            _physicalExamSection(),
            const SizedBox(height: 10),
            _medicinesSection(),
            const SizedBox(height: 10),
            _clinicalNotesSection(),
            const SizedBox(height: 10),
            _carePlanSection(),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAssessment(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Assessment'),
        content: const Text(
          'Are you sure you want to delete this assessment? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Deleting assessment...')));
      }
      await VisitAssessmentService.deleteAssessment(assessment.id!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assessment deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, 'deleted');
      }
    } catch (e) {
      if (context.mounted) {
        final message = e.toString().replaceFirst(
          RegExp(r'^Exception:\s*'),
          '',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete assessment: $message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createPdf(BuildContext context) async {
    await VisitAssessmentPdfGenerator.downloadWithLanguagePicker(
      context,
      assessment,
    );
  }

  Widget _patientHeader() {
    final age = assessment.patientAge.trim();
    final details = [
      if (age.isNotEmpty) '$age Years',
      if (assessment.regNo.trim().isNotEmpty) 'Reg No. ${assessment.regNo}',
    ].join('  •  ');
    final name = assessment.patientName.trim();
    return AssessmentCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFE7D6C2),
              shape: BoxShape.circle,
            ),
            child: Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF6E4A2D),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Patient' : name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: assessmentText,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  details.isEmpty ? '—' : details,
                  style: const TextStyle(
                    color: assessmentMuted,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vitalsGrid() {
    final vitals = assessment.vitals;
    return _InfoGrid(
      items: [
        _InfoItem('Pulse', _number(vitals.pulse, suffix: ' /min')),
        _InfoItem('Pulse Rhythm', _rhythm(vitals.pulseRhythm)),
        _InfoItem('BP', _bp(vitals.bpSystolic, vitals.bpDiastolic)),
        _InfoItem('BP Position', _value(vitals.bpPosition)),
        _InfoItem('RR', _number(vitals.respiratoryRate, suffix: ' /min')),
        _InfoItem('RR Rhythm', _rhythm(vitals.respiratoryRhythm)),
        _InfoItem(
          'Temperature',
          vitals.temperature == null
              ? '—'
              : '${_trimNumber(vitals.temperature!)} ${_temperatureUnit(vitals.temperatureUnit)}',
        ),
        _InfoItem('Temp Method', _temperatureMethod(vitals.temperatureMethod)),
        _InfoItem('SpO₂', _number(vitals.spo2, suffix: ' %')),
        _InfoItem('GRBS', _number(vitals.grbs, suffix: ' mg/dl')),
        _InfoItem('Activity Level', _value(vitals.activityLevel)),
        _InfoItem('Stability', _capitalize(vitals.stability)),
      ],
    );
  }

  Widget _physicalExamSection() {
    final primary = _findingRows(_primaryLabels);
    final headToFoot = _findingRows(_headToFootLabels);
    return _section(
      title: 'Physical Examination',
      children: [
        if (primary.isEmpty && headToFoot.isEmpty)
          const _MutedText('No physical findings recorded.')
        else ...[
          if (primary.isNotEmpty) ...[
            const _SubTitle('Primary Functions'),
            const SizedBox(height: 7),
            ...primary,
          ],
          if (primary.isNotEmpty && headToFoot.isNotEmpty)
            const SizedBox(height: 12),
          if (headToFoot.isNotEmpty) ...[
            const _SubTitle('Head to Foot Examination'),
            const SizedBox(height: 7),
            ...headToFoot,
          ],
        ],
      ],
    );
  }

  List<Widget> _findingRows(Map<String, String> labels) {
    final rows = <Widget>[];
    for (final entry in labels.entries) {
      final finding = assessment.physicalExam[entry.key] ?? const ExamFinding();
      if (!_hasFinding(finding)) continue;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: _ReadOnlyRow(
            label: entry.value,
            value: _findingValue(finding),
            accentColor: finding.status == 'abnormal'
                ? assessmentDanger
                : assessmentGreen,
          ),
        ),
      );
    }
    return rows;
  }

  Widget _medicinesSection() {
    return _section(
      title: 'Medicines',
      children: [
        if (assessment.medicines.isEmpty)
          const _MutedText('No medicines recorded.')
        else
          ...assessment.medicines.asMap().entries.map(
            (entry) => _medicineCard(entry.key, entry.value),
          ),
        const SizedBox(height: 10),
        _ReadOnlyRow(
          label: 'Complementary Medicine',
          value: _complementary(assessment.complementary),
        ),
      ],
    );
  }

  Widget _medicineCard(int index, AssessmentMedicine medicine) {
    final routes = medicine.routes.toList()..sort();
    final source = routes.isEmpty ? '—' : routes.join(', ');
    return Padding(
      padding: EdgeInsets.only(
        bottom: index == assessment.medicines.length - 1 ? 0 : 8,
      ),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFA),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: assessmentBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: assessmentGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: assessmentGreenDark,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    _medicineTitle(medicine),
                    style: const TextStyle(
                      color: assessmentText,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            _InfoGrid(
              compact: true,
              items: [
                _InfoItem('Specified', _value(medicine.instructionSpecified)),
                _InfoItem('Usage', _value(medicine.instructionUsage)),
                _InfoItem('Source', source),
                _InfoItem('Duration', _value(medicine.duration)),
                _InfoItem('Remarks', _value(medicine.remarks)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _clinicalNotesSection() {
    return _section(
      title: 'Clinical Notes',
      children: [
        _ReadOnlyRow(
          label:
              'Other matters related to medicine (Other treatment, Medicine knowledge, Effect, Use Etc.)',
          value: _value(assessment.medicineRemarks),
        ),
        const SizedBox(height: 7),
        _ReadOnlyRow(
          label:
              'Nursing Diagnosis/Doctor Consult/Nursing Management/Medications',
          value: _value(assessment.nursingDiagnosis),
        ),
        const SizedBox(height: 7),
        _ReadOnlyRow(
          label: 'Doctor Consult Notes',
          value: _value(assessment.doctorConsultNotes),
        ),
        const SizedBox(height: 7),
        _ReadOnlyRow(
          label: 'Nursing Management Plan',
          value: _value(assessment.nursingManagementPlan),
        ),
      ],
    );
  }

  Widget _carePlanSection() {
    final notes = <Widget>[];
    for (final entry in _visitPlanLabels.entries) {
      final note = assessment.carePlan.visitPlanNotes[entry.key] ?? '';
      final selected = assessment.carePlan.visitPlans.contains(entry.key);
      if (!selected && note.trim().isEmpty) continue;
      notes.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: _ReadOnlyRow(label: entry.value, value: _value(note)),
        ),
      );
    }
    final services = assessment.carePlan.services
        .map((item) => _serviceLabels[item] ?? item)
        .join(', ');
    return _section(
      title: 'Care Plan',
      children: [
        const _SubTitle('Visit Type Plan'),
        const SizedBox(height: 7),
        if (notes.isEmpty)
          const _MutedText('No visit plan notes recorded.')
        else
          ...notes,
        const SizedBox(height: 9),
        _ReadOnlyRow(label: 'Services Required', value: _value(services)),
        const SizedBox(height: 7),
        _ReadOnlyRow(
          label: 'Team Meeting Discussion',
          value: _value(assessment.teamMeetingDiscussion),
        ),
      ],
    );
  }

  Widget _section({required String title, required List<Widget> children}) {
    return AssessmentCard(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: assessmentText,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  bool _hasFinding(ExamFinding finding) =>
      finding.status != 'not_assessed' ||
      finding.value.trim().isNotEmpty ||
      finding.notes.trim().isNotEmpty ||
      finding.images.isNotEmpty ||
      finding.extraValues.values.any((value) => value.trim().isNotEmpty);

  String _findingValue(ExamFinding finding) {
    final values = <String>[
      if (finding.value.trim().isNotEmpty) _labelFromToken(finding.value),
      if (finding.value.trim().isEmpty && finding.status != 'not_assessed')
        _labelFromToken(finding.status),
      for (final value in finding.extraValues.values)
        if (value.trim().isNotEmpty) _labelFromToken(value),
      if (finding.notes.trim().isNotEmpty) finding.notes.trim(),
      if (finding.images.isNotEmpty) '${finding.images.length} image(s)',
    ];
    return values.isEmpty ? '—' : values.join(' • ');
  }

  String _medicineTitle(AssessmentMedicine medicine) {
    final name = medicine.medicineName.trim();
    final strength = medicine.strength.trim();
    if (name.isEmpty && strength.isEmpty) return 'Medicine';
    if (strength.isEmpty) return name;
    if (name.isEmpty) return strength;
    return '$name, $strength';
  }

  String _date(DateTime value) => DateFormat('dd MMM yyyy').format(value);

  String _dateTime(DateTime value) =>
      DateFormat('dd MMM yyyy, h:mm a').format(value);

  String _range(String start, String end) {
    if (start.trim().isEmpty && end.trim().isEmpty) return '—';
    if (end.trim().isEmpty) return start;
    if (start.trim().isEmpty) return end;
    return '$start - $end';
  }

  String _bp(int? systolic, int? diastolic) {
    if (systolic == null && diastolic == null) return '—';
    return '${systolic ?? '—'}/${diastolic ?? '—'} mmHg';
  }

  String _number(num? value, {String suffix = ''}) =>
      value == null ? '—' : '${_trimNumber(value)}$suffix';

  String _trimNumber(num value) {
    if (value is double && value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  String _rhythm(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized == 'R' || normalized == 'REGULAR') return 'Regular';
    if (normalized == 'IR' || normalized == 'IRREGULAR') return 'Irregular';
    return _value(value);
  }

  String _temperatureUnit(String value) =>
      value.trim().toUpperCase() == 'F' ? '°F' : '°C';

  String _temperatureMethod(String value) {
    switch (value.trim().toUpperCase()) {
      case 'O':
        return 'Oral';
      case 'A':
        return 'Axillary';
      case 'R':
        return 'Rectal';
      default:
        return _value(value);
    }
  }

  String _complementary(String value) {
    switch (value.trim()) {
      case 'Ay':
        return 'Ayurveda';
      case 'H':
        return 'Homeopathy';
      case 'U':
        return 'Unani';
      case 'Sd':
        return 'Siddha';
      case 'N':
        return 'Naturopathy';
      case 'O':
        return 'Other';
      default:
        return _value(value);
    }
  }

  String _labelFromToken(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return '—';
    return clean
        .split(RegExp(r'[_\s-]+'))
        .where((part) => part.isNotEmpty)
        .map(_capitalize)
        .join(' ');
  }

  String _capitalize(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return '—';
    return clean[0].toUpperCase() + clean.substring(1);
  }

  String _value(String value) => value.trim().isEmpty ? '—' : value.trim();
}

class _InfoItem {
  const _InfoItem(this.label, this.value);

  final String label;
  final String value;
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.items, this.compact = false});

  final List<_InfoItem> items;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 3 : 2;
        final spacing = compact ? 7.0 : 8.0;
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 8 : 10,
                      vertical: compact ? 8 : 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: assessmentBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: assessmentMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.value,
                          maxLines: compact ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: assessmentText,
                            fontSize: compact ? 10 : 11,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({
    required this.label,
    required this.value,
    this.accentColor = assessmentGreen,
  });

  final String label;
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: assessmentBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: assessmentMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: assessmentText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SubTitle extends StatelessWidget {
  const _SubTitle(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: const TextStyle(
        color: assessmentText,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  const _BodyText(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: const TextStyle(
        color: assessmentText,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.45,
      ),
    );
  }
}

class _MutedText extends StatelessWidget {
  const _MutedText(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: const TextStyle(color: assessmentMuted, fontSize: 11, height: 1.4),
    );
  }
}
