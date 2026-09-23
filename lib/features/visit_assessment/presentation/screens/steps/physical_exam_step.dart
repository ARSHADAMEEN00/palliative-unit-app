import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:oruma_app/features/visit_assessment/data/assessment_media_service.dart';
import 'package:oruma_app/features/visit_assessment/domain/visit_assessment.dart';
import 'package:oruma_app/features/visit_assessment/presentation/providers/visit_assessment_controller.dart';
import 'package:oruma_app/features/visit_assessment/presentation/widgets/assessment_widgets.dart';

class PhysicalExamStep extends StatelessWidget {
  const PhysicalExamStep({super.key, required this.controller});

  final VisitAssessmentController controller;

  static const _primaryEnglish = <String, String>{
    'respiration': 'Respiration',
    'foodWater': 'Food & Water Intake',
    'urine': 'Urine',
    'defecation': 'Defecation',
    'sleep': 'Sleep',
    'hygiene': 'Hygiene',
    'outdoorAccess': 'Outdoor Access',
    'sexuality': 'Sexuality',
  };

  static const _primaryMalayalam = <String, String>{
    'respiration': 'ശ്വസനം',
    'foodWater': 'അന്നപാനീയങ്ങൾ',
    'urine': 'മൂത്രം',
    'defecation': 'ശോധന',
    'sleep': 'ഉറക്കം',
    'hygiene': 'ശുചിത്വം (ശരീരം, പരിസരം)',
    'outdoorAccess': 'ഔട്ട് ഡോർ അവേഴ്സ്, വ്യായാമം',
    'sexuality': 'ലൈംഗികത',
  };

  static const _headToFootEnglish = <String, String>{
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

  static const _headToFootMalayalam = <String, String>{
    'scalpHair': 'സ്കാൽപ്പ്, മുടി',
    'skin': 'തൊലി',
    'eyeNoseMouth': 'കണ്ണ്, മുഖ്, ചെവി',
    'oral': 'വായ (പല്ല്, നാവ്, നാസി, അണ്ണാക്ക്, തൊണ്ട etc...)',
    'nails': 'നഖം',
    'perineum': 'പെരിനിയം',
    'pressureArea': 'പ്രഷർ ഏരിയ',
    'hiddenArea': 'ഹിഡൻ ഏരിയ',
    'musclesJoints': 'പേശി - സന്ധികൾ',
    'specialAttention': 'പ്രത്യേക ശ്രദ്ധ പതിയേണ്ട ഭാഗങ്ങൾ :',
  };

  static const _previousVisitPromptEnglish =
      "The difficulties/problems noted during the previous visit and their current status, the patient's main complaints / major difficulties / general condition.";

  static const _previousVisitPromptMalayalam =
      'കഴിഞ്ഞ സന്ദർശനത്തിലെഴുതിയിരുന്ന ബുദ്ധിമുട്ടുകളും അതിന്റെ ഇപ്പോഴത്തെ അവസ്ഥയും, രോഗിയുടെ പ്രധാന പരാതികൾ / പ്രധാന ബുദ്ധിമുട്ട് / പൊതു അവസ്ഥ';

  static const _dropdownFindingKeys = {
    'respiration',
    'foodWater',
    'sleep',
    'defecation',
  };

  @override
  Widget build(BuildContext context) {
    final isMalayalam = controller.isMalayalam;
    final primary = isMalayalam ? _primaryMalayalam : _primaryEnglish;
    final headToFoot = isMalayalam ? _headToFootMalayalam : _headToFootEnglish;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        AssessmentSectionTitle(
          isMalayalam ? 'ശാരീരിക പരിശോധന' : 'Physical Examination',
        ),
        const SizedBox(height: 12),
        AssessmentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isMalayalam
                    ? _previousVisitPromptMalayalam
                    : _previousVisitPromptEnglish,
                style: const TextStyle(
                  color: assessmentText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              AssessmentTextField(
                key: const ValueKey('previous-visit-concerns'),
                initialValue: controller.assessment.previousVisitConcerns,
                hint: isMalayalam
                    ? 'വിശദാംശങ്ങൾ രേഖപ്പെടുത്തുക'
                    : 'Enter the current status and main concerns',
                minLines: 4,
                maxLines: 7,
                onChanged: (value) => controller.update(
                  (assessment) =>
                      assessment.copyWith(previousVisitConcerns: value),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        _group(
          context,
          title: isMalayalam ? 'പ്രാഥമിക കാര്യങ്ങൾ' : 'Primary Functions',
          items: primary,
          isMalayalam: isMalayalam,
          initiallyExpanded: true,
        ),
        const SizedBox(height: 9),
        _group(
          context,
          title: isMalayalam
              ? 'ഹെഡ് ടു ഫൂട്ട് പരിശോധന'
              : 'Head to Foot Examination',
          items: headToFoot,
          isMalayalam: isMalayalam,
        ),
      ],
    );
  }

  Widget _group(
    BuildContext context, {
    required String title,
    required Map<String, String> items,
    required bool isMalayalam,
    bool initiallyExpanded = false,
    String? emptyMessage,
  }) {
    return AssessmentCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 13),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: const Icon(
            Icons.chevron_right,
            size: 17,
            color: assessmentMuted,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${items.length} ${isMalayalam ? 'ഇനങ്ങൾ' : 'items'}',
                style: const TextStyle(color: assessmentMuted, fontSize: 9),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: assessmentMuted,
              ),
            ],
          ),
          title: Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          children: items.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      emptyMessage ?? '',
                      style: const TextStyle(
                        color: assessmentMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ]
              : items.entries
                    .map(
                      (entry) => _finding(
                        context,
                        entry.key,
                        entry.value,
                        isMalayalam,
                      ),
                    )
                    .toList(),
        ),
      ),
    );
  }

  Widget _finding(
    BuildContext context,
    String key,
    String label,
    bool isMalayalam,
  ) {
    final finding =
        controller.assessment.physicalExam[key] ?? const ExamFinding();
    final options = _findingOptions(key, isMalayalam);
    final selectedOption = _selectedFindingOption(key, finding, options.$1);
    final secondary = _secondaryFindingOptions(key, isMalayalam);
    final derivedStatus = _statusForFindingState(
      key,
      selectedOption,
      finding.extraValues,
    );
    final displayStatus = derivedStatus == 'not_assessed'
        ? finding.status
        : derivedStatus;
    final statusColor = displayStatus == 'abnormal'
        ? assessmentDanger
        : displayStatus == 'normal'
        ? assessmentGreen
        : assessmentMuted;
    final statusText = _findingStatusText(
      key,
      finding,
      selectedOption,
      options.$2,
      secondary,
      isMalayalam,
    );
    final imageEnabled = const {
      'skin',
      'pressureArea',
      'specialAttention',
    }.contains(key);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border.all(color: assessmentBorder),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 11),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 11),
          title: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 7),
              const Icon(Icons.keyboard_arrow_down, size: 17),
            ],
          ),
          children: [
            _findingControls(
              key,
              finding,
              selectedOption,
              options,
              secondary,
              isMalayalam,
            ),
            const SizedBox(height: 10),
            AssessmentTextField(
              key: ValueKey('physical-exam-notes-$key'),
              initialValue: finding.notes,
              hint: isMalayalam
                  ? 'ആവശ്യമെങ്കിൽ ക്ലിനിക്കൽ നിരീക്ഷണം'
                  : 'Optional clinical observation',
              minLines: 2,
              maxLines: 3,
              onChanged: (notes) => controller.updateFinding(
                key,
                (value) => value.copyWith(notes: notes),
              ),
            ),
            if (imageEnabled) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AssessmentLabel(isMalayalam ? 'ഫോട്ടോ' : 'Photo'),
                  ),
                  IconButton(
                    onPressed: () => _pickImage(context, key, isMalayalam),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.add_a_photo_outlined,
                      color: assessmentGreenDark,
                      size: 20,
                    ),
                  ),
                ],
              ),
              if (finding.images.isNotEmpty)
                SizedBox(
                  height: 68,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: finding.images.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 7),
                    itemBuilder: (context, index) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: SizedBox(
                            width: 68,
                            height: 68,
                            child: AssessmentDataImage(
                              dataUrl: finding.images[index],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: InkWell(
                            onTap: () {
                              final images = [...finding.images]
                                ..removeAt(index);
                              controller.updateFinding(
                                key,
                                (value) => value.copyWith(images: images),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 11,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _findingControls(
    String key,
    ExamFinding finding,
    String selectedOption,
    (List<String>, Map<String, String>) options,
    ({
      String fieldKey,
      String label,
      List<String> options,
      Map<String, String> labels,
      bool dropdown,
    })?
    secondary,
    bool isMalayalam,
  ) {
    if (key == 'urine') {
      return _urineControls(selectedOption, options.$2);
    }

    final primary = _findingSelector(
      key: key,
      options: options.$1,
      labels: options.$2,
      selected: selectedOption,
      dropdown: _dropdownFindingKeys.contains(key),
      onSelected: (selection) => _updateFindingSelection(key, selection),
    );

    if (secondary == null) return primary;

    final secondarySelected = finding.extraValues[secondary.fieldKey] ?? '';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _findingSelector(
                key: '$key-${secondary.fieldKey}',
                options: secondary.options,
                labels: secondary.labels,
                selected: secondarySelected,
                dropdown: secondary.dropdown,
                onSelected: (selection) =>
                    _updateFindingExtra(key, secondary.fieldKey, selection),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _urineControls(String selectedOption, Map<String, String> labels) {
    const independent = 'uses_toilet_independently';
    const catheterOptions = [
      'urinary_catheter',
      'condom_catheter',
      'nephrostomy_tube',
    ];
    final catheterSelected = catheterOptions.contains(selectedOption)
        ? selectedOption
        : '';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AssessmentSegment(
            compact: true,
            options: const [independent],
            labels: labels,
            selected: selectedOption == independent ? independent : '',
            onSelected: (selection) =>
                _updateFindingSelection('urine', selection),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _findingSelector(
                key: 'urine-catheter',
                options: catheterOptions,
                labels: labels,
                selected: catheterSelected,
                dropdown: true,
                onSelected: (selection) =>
                    _updateFindingSelection('urine', selection),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _findingSelector({
    required String key,
    required List<String> options,
    required Map<String, String> labels,
    required String selected,
    required bool dropdown,
    required ValueChanged<String> onSelected,
  }) {
    if (!dropdown) {
      return AssessmentSegment(
        compact: true,
        options: options,
        labels: labels,
        selected: selected,
        dangerValue: _dangerValueForOptions(options),
        onSelected: onSelected,
      );
    }

    final selectedValue = options.contains(selected) ? selected : null;
    return DropdownButtonFormField<String>(
      key: ValueKey('physical-exam-select-$key'),
      initialValue: selectedValue,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down, size: 18),
      style: const TextStyle(
        color: assessmentText,
        fontSize: 11,
        fontWeight: FontWeight.normal,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: assessmentBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: assessmentBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: assessmentGreen),
        ),
      ),
      items: options
          .map(
            (option) => DropdownMenuItem(
              value: option,
              child: Text(
                labels[option] ?? option,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onSelected(value);
      },
    );
  }

  void _updateFindingSelection(String key, String selection) {
    controller.updateFinding(
      key,
      (value) => value.copyWith(
        status: _statusForFindingState(key, selection, value.extraValues),
        value: selection,
      ),
    );
  }

  void _updateFindingExtra(String key, String fieldKey, String selection) {
    controller.updateFinding(key, (value) {
      final extras = {...value.extraValues, fieldKey: selection};
      return value.copyWith(
        status: _statusForFindingState(key, value.value, extras),
        extraValues: extras,
      );
    });
  }

  String _findingStatusText(
    String key,
    ExamFinding finding,
    String selectedOption,
    Map<String, String> labels,
    ({
      String fieldKey,
      String label,
      List<String> options,
      Map<String, String> labels,
      bool dropdown,
    })?
    secondary,
    bool isMalayalam,
  ) {
    final pieces = <String>[];
    if (selectedOption.isNotEmpty) {
      pieces.add(labels[selectedOption] ?? finding.value);
    } else if (finding.value.isNotEmpty) {
      pieces.add(finding.value);
    }
    if (secondary != null) {
      final secondaryValue = finding.extraValues[secondary.fieldKey];
      if (secondaryValue != null && secondaryValue.isNotEmpty) {
        pieces.add(secondary.labels[secondaryValue] ?? secondaryValue);
      }
    }
    if (pieces.isNotEmpty) return pieces.join(' / ');
    if (finding.status == 'not_assessed') {
      return isMalayalam ? 'പരിശോധിച്ചിട്ടില്ല' : 'Not assessed';
    }
    if (finding.status == 'normal') {
      return isMalayalam ? 'സാധാരണം' : 'Normal';
    }
    return isMalayalam ? 'അസാധാരണം' : 'Abnormal';
  }

  String _selectedFindingOption(
    String key,
    ExamFinding finding,
    List<String> options,
  ) {
    final normalized = _normalizeFindingValue(finding.value);
    if (options.contains(normalized)) return normalized;

    final status = finding.status;
    switch (key) {
      case 'respiration':
        if (normalized == 'oxygen_cylinder') return 'oxygen_cylinder';
        if (status == 'normal' || normalized == 'normal') return 'normal';
        break;
      case 'foodWater':
        if (normalized == 'good') return 'self_feeding';
        if (normalized == 'reduced' || normalized == 'poor') {
          return 'assistance';
        }
        break;
      case 'urine':
        if (normalized == 'normal') return 'uses_toilet_independently';
        if (normalized == 'catheter') return 'urinary_catheter';
        break;
      case 'defecation':
        if (normalized == 'constipation') return 'uses_medication';
        if (normalized == 'diarrhea' || normalized == 'incontinence') {
          return 'no_defecation';
        }
        break;
      case 'sleep':
        if (normalized == 'good') return 'normal';
        if (normalized == 'disturbed' || normalized == 'insomnia') {
          return 'with_medication';
        }
        break;
      case 'scalpHair':
        if (status == 'normal' || normalized == 'normal') return 'clean';
        if (status == 'abnormal' || normalized == 'abnormal') {
          return 'not_clean';
        }
        break;
      case 'skin':
        if (status == 'normal' || normalized == 'normal') return 'soft_skin';
        if (status == 'abnormal' || normalized == 'abnormal') {
          return 'dry_skin';
        }
        break;
      case 'eyeNoseMouth':
      case 'oral':
      case 'nails':
      case 'perineum':
      case 'pressureArea':
      case 'hiddenArea':
        if (status == 'normal' || normalized == 'normal') return 'clean';
        if (status == 'abnormal' || normalized == 'abnormal') return 'unclean';
        break;
      case 'musclesJoints':
        if (status == 'normal' || normalized == 'normal') return 'no_pain';
        if (status == 'abnormal' || normalized == 'abnormal') {
          return 'pain_present';
        }
        break;
      case 'specialAttention':
        if (status == 'normal' || normalized == 'normal') return 'no';
        if (status == 'abnormal' || normalized == 'abnormal') return 'yes';
        break;
    }

    if (options.contains(status)) return status;
    return '';
  }

  String _normalizeFindingValue(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s-]+'), '_')
      .replaceAll(RegExp(r'[^a-z0-9_]+'), '');

  String _statusForFindingState(
    String key,
    String selection,
    Map<String, String> extras,
  ) {
    final secondary = _secondaryStatus(key, extras);
    if (secondary == 'abnormal') return 'abnormal';

    final main = _statusForSelection(key, selection);
    if (main != 'not_assessed') return main;
    if (secondary != 'not_assessed') return secondary;
    return 'not_assessed';
  }

  String _secondaryStatus(String key, Map<String, String> extras) {
    switch (key) {
      case 'scalpHair':
        final value = extras['scalpCondition'];
        if (value == null || value.isEmpty) return 'not_assessed';
        return value == 'no_lice' ? 'normal' : 'abnormal';
      case 'pressureArea':
      case 'hiddenArea':
        final value = extras['woundStatus'];
        if (value == null || value.isEmpty) return 'not_assessed';
        return value == 'no_wounds' ? 'normal' : 'abnormal';
      default:
        return 'not_assessed';
    }
  }

  String _statusForSelection(String key, String selection) {
    if (selection.isEmpty) return 'not_assessed';
    switch (key) {
      case 'respiration':
        return selection == 'normal' ? 'normal' : 'abnormal';
      case 'foodWater':
        return selection == 'self_feeding' ? 'normal' : 'abnormal';
      case 'urine':
        return selection == 'uses_toilet_independently' ? 'normal' : 'abnormal';
      case 'defecation':
      case 'sleep':
        return selection == 'normal' ? 'normal' : 'abnormal';
      case 'scalpHair':
        return selection == 'clean' ? 'normal' : 'abnormal';
      case 'skin':
        return selection == 'soft_skin' ? 'normal' : 'abnormal';
      case 'eyeNoseMouth':
      case 'oral':
      case 'nails':
      case 'perineum':
      case 'pressureArea':
      case 'hiddenArea':
        return selection == 'clean' ? 'normal' : 'abnormal';
      case 'musclesJoints':
        return selection == 'no_pain' ? 'normal' : 'abnormal';
      case 'specialAttention':
        return selection == 'no' ? 'normal' : 'abnormal';
      default:
        return selection == 'normal' ? 'normal' : 'abnormal';
    }
  }

  String? _dangerValueForOptions(List<String> options) {
    for (final option in const [
      'abnormal',
      'unclean',
      'pain_present',
      'yes',
      'no_defecation',
      'no_sleep',
      'over_sleep',
      'dry_skin',
      'not_clean',
    ]) {
      if (options.contains(option)) return option;
    }
    return null;
  }

  Future<void> _pickImage(
    BuildContext context,
    String key,
    bool isMalayalam,
  ) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(isMalayalam ? 'ഫോട്ടോ എടുക്കുക' : 'Take photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(
                isMalayalam
                    ? 'ഗാലറിയിൽ നിന്ന് തിരഞ്ഞെടുക്കുക'
                    : 'Choose from gallery',
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final image = await AssessmentMediaService.pickCompressedImage(source);
    if (image == null) return;
    final current =
        controller.assessment.physicalExam[key] ?? const ExamFinding();
    controller.updateFinding(
      key,
      (value) => value.copyWith(images: [...current.images, image]),
    );
  }

  (List<String>, Map<String, String>) _findingOptions(
    String key,
    bool isMalayalam,
  ) {
    switch (key) {
      case 'respiration':
        return (
          const ['normal', 'oxygen_cylinder', 'bipap_machine', 'nebulizer'],
          isMalayalam
              ? const {
                  'normal': 'സാധാരണം',
                  'oxygen_cylinder': 'ഓക്സിജൻ സിലിണ്ടർ',
                  'bipap_machine': 'BiPAP മെഷീൻ',
                  'nebulizer': 'കോൺസൻട്രേറ്റർ',
                }
              : const {
                  'normal': 'Normal',
                  'oxygen_cylinder': 'Oxygen cylinder',
                  'bipap_machine': 'BiPAP Machine',
                  'nebulizer': 'Concentrator',
                },
        );
      case 'foodWater':
        return (
          const ['self_feeding', 'tube_fed', 'assistance'],
          isMalayalam
              ? const {
                  'self_feeding': 'സ്വയം കഴിക്കുന്നു',
                  'tube_fed': 'ട്യൂബ് ഫീഡിംഗ്',
                  'assistance': 'സഹായം ആവശ്യമാണ്',
                }
              : const {
                  'self_feeding': 'Self Feeding',
                  'tube_fed': 'Tube Fed',
                  'assistance': 'Assistance',
                },
        );
      case 'urine':
        return (
          const [
            'uses_toilet_independently',
            'urinary_catheter',
            'condom_catheter',
            'nephrostomy_tube',
          ],
          isMalayalam
              ? const {
                  'uses_toilet_independently': 'സ്വയം ടോയിലെറ്റിൽ പോകും',
                  'urinary_catheter': 'യൂറിനറി കാത്തീറ്റർ',
                  'condom_catheter': 'കോണ്ടം കാത്തീറ്റർ',
                  'nephrostomy_tube': 'നെഫ്രോസ്റ്റമി ട്യൂബ്',
                }
              : const {
                  'uses_toilet_independently': 'Uses Toilet Independently',
                  'urinary_catheter': 'Urinary Catheter',
                  'condom_catheter': 'Condom Catheter',
                  'nephrostomy_tube': 'Nephrostomy Tube',
                },
        );
      case 'defecation':
        return (
          const ['normal', 'uses_medication', 'no_defecation'],
          isMalayalam
              ? const {
                  'normal': 'സാധാരണം',
                  'uses_medication': 'മരുന്ന് ഉപയോഗിക്കുന്നു',
                  'no_defecation': 'ശോധന ഇല്ല',
                }
              : const {
                  'normal': 'Normal',
                  'uses_medication': 'Uses Medication',
                  'no_defecation': 'No Defecation',
                },
        );
      case 'sleep':
        return (
          const ['normal', 'with_medication', 'no_sleep', 'over_sleep'],
          isMalayalam
              ? const {
                  'normal': 'സാധാരണ ഉറക്കം',
                  'with_medication': 'മരുന്നിന്റെ സഹായത്തോടെ',
                  'no_sleep': 'ഉറക്കം ഇല്ല',
                  'over_sleep': 'അമിത ഉറക്കം',
                }
              : const {
                  'normal': 'Normal',
                  'with_medication': 'With Medication',
                  'no_sleep': 'No Sleep',
                  'over_sleep': 'Over Sleep',
                },
        );
      case 'hygiene':
        return (
          const ['good', 'fair', 'poor'],
          isMalayalam
              ? const {'good': 'നല്ലത്', 'fair': 'ശരാശരി', 'poor': 'മോശം'}
              : const {'good': 'Good', 'fair': 'Fair', 'poor': 'Poor'},
        );
      case 'outdoorAccess':
        return (
          const ['yes', 'limited', 'no'],
          isMalayalam
              ? const {'yes': 'ഉണ്ട്', 'limited': 'പരിമിതം', 'no': 'ഇല്ല'}
              : const {'yes': 'Yes', 'limited': 'Limited', 'no': 'No'},
        );
      case 'scalpHair':
        return (
          const ['clean', 'not_clean'],
          isMalayalam
              ? const {'clean': 'വൃത്തി ഉണ്ട്', 'not_clean': 'വൃത്തി ഇല്ല'}
              : const {'clean': 'Clean', 'not_clean': 'Not Clean'},
        );
      case 'skin':
        return (
          const ['dry_skin', 'soft_skin'],
          isMalayalam
              ? const {
                  'dry_skin': 'വരണ്ട ചർമ്മം',
                  'soft_skin': 'മൃദുവായ ചർമ്മം',
                }
              : const {'dry_skin': 'Dry Skin', 'soft_skin': 'Soft Skin'},
        );
      case 'eyeNoseMouth':
      case 'oral':
      case 'nails':
      case 'perineum':
      case 'pressureArea':
      case 'hiddenArea':
        return (
          const ['clean', 'unclean'],
          isMalayalam
              ? const {'clean': 'വൃത്തി ഉണ്ട്', 'unclean': 'വൃത്തിയില്ല'}
              : const {'clean': 'Clean', 'unclean': 'Unclean'},
        );
      case 'musclesJoints':
        return (
          const ['pain_present', 'no_pain'],
          isMalayalam
              ? const {'pain_present': 'വേദന ഉണ്ട്', 'no_pain': 'വേദന ഇല്ല'}
              : const {'pain_present': 'Pain Present', 'no_pain': 'No Pain'},
        );
      case 'specialAttention':
        return (
          const ['no', 'yes'],
          isMalayalam
              ? const {'no': 'ഇല്ല', 'yes': 'ഉണ്ട്'}
              : const {'no': 'No', 'yes': 'Yes'},
        );
      default:
        return (
          const ['normal', 'abnormal'],
          isMalayalam
              ? const {'normal': 'സാധാരണം', 'abnormal': 'അസാധാരണം'}
              : const {'normal': 'Normal', 'abnormal': 'Abnormal'},
        );
    }
  }

  ({
    String fieldKey,
    String label,
    List<String> options,
    Map<String, String> labels,
    bool dropdown,
  })?
  _secondaryFindingOptions(String key, bool isMalayalam) {
    switch (key) {
      case 'scalpHair':
        return (
          fieldKey: 'scalpCondition',
          label: isMalayalam ? 'പേൻ / താരൻ' : 'Lice / Dandruff',
          options: const [
            'lice_present',
            'no_lice',
            'dandruff_present_no_lice',
            'no_dandruff_lice_present',
          ],
          labels: isMalayalam
              ? const {
                  'lice_present': 'പേൻ ഉണ്ട്',
                  'no_lice': 'പേൻ ഇല്ല',
                  'dandruff_present_no_lice': 'താരൻ ഉണ്ട് പേൻ ഇല്ല',
                  'no_dandruff_lice_present': 'താരൻ ഇല്ല പേൻ ഉണ്ട്',
                }
              : const {
                  'lice_present': 'Lice',
                  'no_lice': 'No lice',
                  'dandruff_present_no_lice': 'Dandruff Present No lice',
                  'no_dandruff_lice_present': 'No Dandruff Lice Present',
                },
          dropdown: true,
        );
      case 'pressureArea':
      case 'hiddenArea':
        return (
          fieldKey: 'woundStatus',
          label: isMalayalam ? 'മുറിവുകൾ' : 'Wounds',
          options: const ['wounds', 'no_wounds'],
          labels: isMalayalam
              ? const {'wounds': 'മുറിവുകൾ', 'no_wounds': 'മുറിവുകളില്ല'}
              : const {'wounds': 'Wounds', 'no_wounds': 'No Wounds'},
          dropdown: false,
        );
      default:
        return null;
    }
  }
}
