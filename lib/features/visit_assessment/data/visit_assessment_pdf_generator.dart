import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:oruma_app/features/visit_assessment/domain/visit_assessment.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class VisitAssessmentPdfGenerator {
  const VisitAssessmentPdfGenerator._();

  // Render at 225 DPI: clear enough for print while keeping generation fast
  // and avoiding the memory spikes caused by the former 600 DPI pages.
  static const double _pageWidth = 1240;
  static const double _pageHeight = 1754;
  static const double _rasterScale = 1.5;
  static int get _rasterWidth => (_pageWidth * _rasterScale).round();
  static int get _rasterHeight => (_pageHeight * _rasterScale).round();
  static const String _fontFamily = 'NotoSansMalayalam';
  static const List<String> _fontFallbacks = <String>['Roboto', 'Arial'];
  static const Color _blue = Color(0xFF083F88);
  static const Color _ink = Color(0xFF111827);
  static const Color _softBlue = Color(0x14083F88);

  static const _primaryLabels = <String, String>{
    'respiration': 'ശ്വാസം',
    'foodWater': 'അന്നപാനീയങ്ങൾ',
    'urine': 'മൂത്രം',
    'defecation': 'ശോധന',
    'sleep': 'ഉറക്കം',
    'hygiene': 'ശുചിത്വം (ശരീരം, പരിസരം)',
    'outdoorAccess': 'ഔട്ട് ഡോർ അവേഴ്സ്, വ്യായാമം',
    'sexuality': 'ലൈംഗികത',
  };

  static const _headToFootLabels = <String, String>{
    'scalpHair': 'സ്കാൽപ്പ്, മുടി',
    'skin': 'തൊലി',
    'eyeNoseMouth': 'കണ്ണ്, മൂക്ക്, ചെവി',
    'oral': 'വായ (പല്ല്, നാവ്, നാസി, അണ്ണാക്ക്, തൊണ്ട തുടങ്ങിയവ)',
    'nails': 'നഖം',
    'perineum': 'പെരിനിയം',
    'pressureArea': 'പ്രഷർ ഏരിയ',
    'hiddenArea': 'ഹിഡൻ ഏരിയ',
    'musclesJoints': 'പേശി - സന്ധികൾ',
    'specialAttention': 'പ്രത്യേക ശ്രദ്ധ പതിയേണ്ട ഭാഗങ്ങൾ',
  };

  static const _visitPlanLabels = <String, String>{
    'DHC': 'DHC',
    'NHC': 'NHC',
    'GVHC': 'GVHC',
    'other': 'മറ്റുള്ളവ',
  };

  static const _serviceLabels = <String, String>{
    'healthEducation': 'ആരോഗ്യ വിദ്യാഭ്യാസം',
    'familyTraining': 'കുടുംബ പരിശീലനം',
    'physiotherapy': 'ഫിസിയോതെറാപ്പി',
    'dayCare': 'ഡേ കെയർ',
    'socialSupport': 'സാമൂഹിക പിന്തുണ',
    'medicineSupport': 'മരുന്ന് സഹായം',
  };

  static const _visitModeLabels = <String, String>{
    'new': 'പുതിയ',
    'monthly': 'ആസൂത്രിത',
    'emergency': 'അടിയന്തര',
    'dhc_visit': 'DHC',
    'vhc_visit': 'VHC',
  };

  static const _malayalamTokenLabels = <String, String>{
    'normal': 'സാധാരണം',
    'abnormal': 'അസാധാരണം',
    'self_feeding': 'സ്വയം കഴിക്കുന്നു',
    'tube_fed': 'ട്യൂബ് ഫീഡിംഗ്',
    'assistance': 'സഹായം ആവശ്യമാണ്',
    'uses_toilet_independently': 'സ്വയം ടോയ്‌ലറ്റിൽ പോകും',
    'urinary_catheter': 'യൂറിനറി കാത്തീറ്റർ',
    'condom_catheter': 'കോണ്ടം കാത്തീറ്റർ',
    'nephrostomy_tube': 'നെഫ്രോസ്റ്റമി ട്യൂബ്',
    'uses_medication': 'മരുന്ന് ഉപയോഗിക്കുന്നു',
    'no_defecation': 'ശോധന ഇല്ല',
    'with_medication': 'മരുന്നിന്റെ സഹായത്തോടെ',
    'no_sleep': 'ഉറക്കം ഇല്ല',
    'over_sleep': 'അമിത ഉറക്കം',
    'good': 'നല്ലത്',
    'fair': 'ശരാശരി',
    'poor': 'മോശം',
    'yes': 'ഉണ്ട്',
    'limited': 'പരിമിതം',
    'no': 'ഇല്ല',
    'clean': 'വൃത്തി ഉണ്ട്',
    'not_clean': 'വൃത്തി ഇല്ല',
    'unclean': 'വൃത്തിയില്ല',
    'dry_skin': 'വരണ്ട ചർമ്മം',
    'soft_skin': 'മൃദുവായ ചർമ്മം',
    'pain_present': 'വേദന ഉണ്ട്',
    'no_pain': 'വേദന ഇല്ല',
    'oxygen_cylinder': 'ഓക്സിജൻ സിലിണ്ടർ',
    'bipap_machine': 'BiPAP മെഷീൻ',
    'nebulizer': 'കോൺസൻട്രേറ്റർ',
    'lice_present': 'പേൻ ഉണ്ട്',
    'no_lice': 'പേൻ ഇല്ല',
    'dandruff_present_no_lice': 'താരൻ ഉണ്ട്, പേൻ ഇല്ല',
    'no_dandruff_lice_present': 'താരൻ ഇല്ല, പേൻ ഉണ്ട്',
    'wounds': 'മുറിവുകൾ',
    'no_wounds': 'മുറിവുകളില്ല',
  };

  static Future<Uint8List> generate(VisitAssessment assessment) async {
    final pageOne = await _renderPage(
      (canvas) => _paintPageOne(canvas, assessment),
    );
    final pageTwo = await _renderPage(
      (canvas) => _paintPageTwo(canvas, assessment),
    );

    final document = pw.Document(
      compress: false,
      version: PdfVersion.pdf_1_4,
      title: 'Palliative visit assessment',
      creator: 'Palliative App',
    );
    for (final pageBytes in [pageOne, pageTwo]) {
      final image = pw.MemoryImage(pageBytes);
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Image(image, fit: pw.BoxFit.fill),
          ),
        ),
      );
    }
    return document.save();
  }

  static String fileName(VisitAssessment assessment) {
    final patient = assessment.patientName
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final name = patient.isEmpty ? 'patient' : patient.toLowerCase();
    final date = DateFormat('yyyyMMdd').format(assessment.visitDate);
    return 'visit_assessment_${name}_$date.pdf';
  }

  static Future<Uint8List> _renderPage(
    void Function(Canvas canvas) painter,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, _rasterWidth.toDouble(), _rasterHeight.toDouble()),
    );
    canvas.drawColor(Colors.white, BlendMode.src);
    canvas.scale(_rasterScale, _rasterScale);
    painter(canvas);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(_rasterWidth, _rasterHeight);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    picture.dispose();
    final raster = img.Image.fromBytes(
      width: _rasterWidth,
      height: _rasterHeight,
      bytes: byteData!.buffer,
      bytesOffset: byteData.offsetInBytes,
      rowStride: _rasterWidth * 4,
      order: img.ChannelOrder.rgba,
    );
    return img.encodeJpg(raster, quality: 90, chroma: img.JpegChroma.yuv444);
  }

  static void _paintPageOne(Canvas canvas, VisitAssessment assessment) {
    final paint = _stroke(1.7);
    _text(
      canvas,
      'പാലിയേറ്റീവ് കെയർ',
      const Rect.fromLTWH(175, 95, 420, 44),
      size: 34,
      weight: FontWeight.w800,
      letterSpacing: 1.2,
    );

    final header = RRect.fromRectAndRadius(
      const Rect.fromLTWH(115, 132, 1010, 150),
      const Radius.circular(16),
    );
    canvas.drawRRect(header, paint);
    final visitTypeBox = RRect.fromRectAndRadius(
      const Rect.fromLTWH(865, 90, 260, 36),
      const Radius.circular(14),
    );
    canvas.drawRRect(visitTypeBox, paint);
    canvas.drawLine(const Offset(940, 90), const Offset(940, 126), paint);
    _text(
      canvas,
      assessment.visitType.isEmpty ? 'NHC' : assessment.visitType,
      const Rect.fromLTWH(875, 95, 58, 25),
      size: 25,
      weight: FontWeight.w800,
      align: TextAlign.center,
    );
    _fitText(
      canvas,
      '${_visitModeLabel(assessment.visitMode)} സന്ദർശനം',
      const Rect.fromLTWH(952, 96, 158, 24),
      size: 17,
      weight: FontWeight.w700,
      align: TextAlign.center,
    );

    _headerField(
      canvas,
      label: 'പേര് :',
      value: assessment.patientName,
      labelX: 135,
      valueX: 220,
      y: 154,
      width: 430,
    );
    _headerField(
      canvas,
      label: 'വയസ്സ് :',
      value: assessment.patientAge,
      labelX: 650,
      valueX: 705,
      y: 154,
      width: 100,
    );
    _headerField(
      canvas,
      label: 'രജി. നമ്പർ :',
      value: assessment.regNo,
      labelX: 790,
      valueX: 895,
      y: 154,
      width: 175,
    );
    _headerField(
      canvas,
      label: 'തീയതി :',
      value: _date(assessment.visitDate),
      labelX: 135,
      valueX: 215,
      y: 210,
      width: 230,
    );
    _headerField(
      canvas,
      label: 'സമയം :',
      value: assessment.timeFrom,
      labelX: 520,
      valueX: 650,
      y: 210,
      width: 120,
    );
    _headerField(
      canvas,
      label: 'വരെ :',
      value: assessment.timeTo,
      labelX: 775,
      valueX: 825,
      y: 210,
      width: 130,
    );
    _headerField(
      canvas,
      label: 'ടീം :',
      value: assessment.team,
      labelX: 135,
      valueX: 215,
      y: 250,
      width: 350,
    );

    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(115, 292, 1025, 1445),
      const Radius.circular(16),
    );
    canvas.drawRRect(body, paint);

    const prompt =
        'കഴിഞ്ഞ സന്ദർശനത്തിലെഴുതിയിരുന്ന ബുദ്ധിമുട്ടുകളും അതിന്റെ ഇപ്പോഴത്തെ അവസ്ഥയും, രോഗിയുടെ പ്രധാന പരാതികൾ / പ്രധാന ബുദ്ധിമുട്ട് / പൊതു അവസ്ഥ';
    _text(
      canvas,
      prompt,
      const Rect.fromLTWH(140, 315, 960, 52),
      size: 18,
      weight: FontWeight.w700,
      lineHeight: 1.22,
    );
    _fitText(
      canvas,
      assessment.previousVisitConcerns,
      const Rect.fromLTWH(140, 370, 960, 80),
      size: 20,
      color: _ink,
      lineHeight: 1.25,
    );

    double y = 480;
    _underlinedText(
      canvas,
      'പ്രാഥമിക കാര്യങ്ങൾ',
      Offset(140, y),
      size: 24,
      width: 230,
    );
    y += 48;
    y = _examRows(canvas, _primaryLabels, assessment, y, rowHeight: 69);
    y += 10;
    _text(
      canvas,
      'ഹെഡ് ടു ഫൂട്ട് പരിശോധന',
      Rect.fromLTWH(140, y, 300, 30),
      size: 21,
      weight: FontWeight.w800,
    );
    y += 44;
    _examRows(canvas, _headToFootLabels, assessment, y, rowHeight: 58);
  }

  static double _examRows(
    Canvas canvas,
    Map<String, String> labels,
    VisitAssessment assessment,
    double startY, {
    required double rowHeight,
  }) {
    var y = startY;
    for (final entry in labels.entries) {
      final finding = assessment.physicalExam[entry.key] ?? const ExamFinding();
      _text(
        canvas,
        entry.value,
        Rect.fromLTWH(140, y, 330, rowHeight - 8),
        size: entry.value.length > 30 ? 16 : 20,
        weight: FontWeight.w700,
        lineHeight: 1.18,
      );
      _text(canvas, ':', Rect.fromLTWH(480, y, 18, 22), size: 20);
      _fitText(
        canvas,
        _findingValue(finding),
        Rect.fromLTWH(510, y - 3, 600, rowHeight - 6),
        size: 19,
        color: _ink,
        lineHeight: 1.18,
      );
      y += rowHeight;
    }
    return y;
  }

  static void _paintPageTwo(Canvas canvas, VisitAssessment assessment) {
    final paint = _stroke(1.7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(65, 62, 1110, 1628),
        const Radius.circular(18),
      ),
      paint,
    );

    _paintVitals(canvas, assessment);
    _paintMedicines(canvas, assessment);
    _paintClinicalNotes(canvas, assessment);
    _paintPlan(canvas, assessment);
    _paintSignatureArea(canvas, assessment);
  }

  static void _paintVitals(Canvas canvas, VisitAssessment assessment) {
    final vitals = assessment.vitals;
    _lineField(
      canvas,
      label: 'Pulse',
      value: _number(vitals.pulse),
      x: 105,
      y: 110,
      lineWidth: 105,
      suffix: '/ Mt. ${_rhythm(vitals.pulseRhythm)}',
    );
    _lineField(
      canvas,
      label: 'BP',
      value: _bpValue(vitals.bpSystolic, vitals.bpDiastolic),
      x: 380,
      y: 110,
      lineWidth: 120,
      suffix: 'U/L: ${_position(vitals.bpPosition)}',
    );
    _text(canvas, '↔', const Rect.fromLTWH(620, 101, 42, 28), size: 26);
    _text(canvas, '↕', const Rect.fromLTWH(690, 85, 28, 56), size: 26);
    _lineField(
      canvas,
      label: 'RR',
      value: _number(vitals.respiratoryRate),
      x: 765,
      y: 110,
      lineWidth: 120,
      suffix: '/Mt. ${_rhythm(vitals.respiratoryRhythm)}',
    );
    _lineField(
      canvas,
      label: 'TEMP',
      value: _number(vitals.temperature),
      x: 105,
      y: 155,
      lineWidth: 110,
      suffix:
          '${_temperatureUnit(vitals.temperatureUnit)} (${_temperatureMethodCode(vitals.temperatureMethod)})',
    );
    _lineField(
      canvas,
      label: 'SPO2',
      value: _number(vitals.spo2),
      x: 420,
      y: 155,
      lineWidth: 120,
      suffix: '%',
    );
    _lineField(
      canvas,
      label: 'GRBS',
      value: _number(vitals.grbs),
      x: 690,
      y: 155,
      lineWidth: 125,
      suffix: 'Mg/dl',
    );

    _text(
      canvas,
      'പ്രവർത്തന നില :',
      const Rect.fromLTWH(105, 200, 135, 26),
      size: 16,
    );
    var x = 245.0;
    for (final level in ['I', 'II', 'III', 'IV', 'V']) {
      final selected = vitals.activityLevel == level;
      if (selected) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - 8, 196, 36, 30),
            const Radius.circular(4),
          ),
          Paint()..color = _softBlue,
        );
      }
      _text(
        canvas,
        level,
        Rect.fromLTWH(x, 200, 38, 22),
        size: 18,
        weight: selected ? FontWeight.w900 : FontWeight.w600,
      );
      x += 42;
    }
    _checkboxLabel(
      canvas,
      label: 'സ്ഥിരം',
      checked: vitals.stability.toLowerCase() == 'stable',
      x: 500,
      y: 201,
    );
    _checkboxLabel(
      canvas,
      label: 'അസ്ഥിരം',
      checked: vitals.stability.toLowerCase() == 'unstable',
      x: 680,
      y: 201,
    );
  }

  static void _paintMedicines(Canvas canvas, VisitAssessment assessment) {
    const tableX = 92.0;
    const tableY = 285.0;
    const tableW = 1056.0;
    const headerOne = 47.0;
    const headerTwo = 39.0;
    const footerH = 48.0;
    const tableH = 520.0;
    final rowCount = assessment.medicines.length < 9
        ? 9
        : assessment.medicines.length;
    final rowH = (tableH - headerOne - headerTwo - footerH) / rowCount;
    final border = _stroke(1.4);

    _text(
      canvas,
      'സ്ഥിരമായി കഴിക്കുന്ന മരുന്നുകൾ (മരുന്നലർജി)',
      const Rect.fromLTWH(tableX + 18, tableY - 37, 600, 28),
      size: 19,
      weight: FontWeight.w800,
    );

    canvas.drawRect(Rect.fromLTWH(tableX, tableY, tableW, tableH), border);
    final columns = <double>[
      tableX,
      tableX + 55,
      tableX + 430,
      tableX + 515,
      tableX + 610,
      tableX + 650,
      tableX + 690,
      tableX + 730,
      tableX + 770,
      tableX + 915,
      tableX + tableW,
    ];
    for (var i = 1; i < columns.length - 1; i++) {
      final x = columns[i];
      final isSubColumn = i == 3 || i == 5 || i == 6 || i == 7;
      final startY = isSubColumn ? tableY + headerOne : tableY;
      canvas.drawLine(
        Offset(x, startY),
        Offset(x, tableY + tableH - footerH),
        border,
      );
    }
    canvas.drawLine(
      Offset(tableX, tableY + headerOne),
      Offset(tableX + tableW, tableY + headerOne),
      border,
    );
    canvas.drawLine(
      Offset(tableX, tableY + headerOne + headerTwo),
      Offset(tableX + tableW, tableY + headerOne + headerTwo),
      border,
    );
    for (var i = 0; i <= rowCount; i++) {
      final y = tableY + headerOne + headerTwo + rowH * i;
      canvas.drawLine(Offset(tableX, y), Offset(tableX + tableW, y), border);
    }

    _centerText(
      canvas,
      'ക്രമ\nനമ്പർ',
      Rect.fromLTRB(columns[0], tableY, columns[1], tableY + headerOne),
      size: 14,
    );
    _centerText(
      canvas,
      'മരുന്ന്, ശക്തി',
      Rect.fromLTRB(columns[1], tableY, columns[2], tableY + headerOne),
      size: 17,
    );
    _centerText(
      canvas,
      'ഉപയോഗക്രമ',
      Rect.fromLTRB(columns[2], tableY, columns[4], tableY + headerOne),
      size: 13,
    );
    _centerText(
      canvas,
      'നിർദിഷ്ടം',
      Rect.fromLTRB(
        columns[2],
        tableY + headerOne,
        columns[3],
        tableY + headerOne + headerTwo,
      ),
      size: 12,
    );
    _centerText(
      canvas,
      'ഉപയോഗം',
      Rect.fromLTRB(
        columns[3],
        tableY + headerOne,
        columns[4],
        tableY + headerOne + headerTwo,
      ),
      size: 12,
    );
    _centerText(
      canvas,
      'സ്രോതസ്സ്',
      Rect.fromLTRB(columns[4], tableY, columns[8], tableY + headerOne),
      size: 13,
    );
    for (var i = 0; i < 4; i++) {
      _centerText(
        canvas,
        ['P', 'G', 'S', 'O'][i],
        Rect.fromLTRB(
          columns[4 + i],
          tableY + headerOne,
          columns[5 + i],
          tableY + headerOne + headerTwo,
        ),
        size: 16,
      );
    }
    _centerText(
      canvas,
      'കാലാവധി',
      Rect.fromLTRB(columns[8], tableY, columns[9], tableY + headerOne),
      size: 15,
    );
    _centerText(
      canvas,
      'റിമാർക്സ്',
      Rect.fromLTRB(columns[9], tableY, columns[10], tableY + headerOne),
      size: 15,
    );

    final medicines = assessment.medicines;
    for (var index = 0; index < rowCount; index++) {
      final y = tableY + headerOne + headerTwo + rowH * index;
      _centerText(
        canvas,
        '${index + 1}',
        Rect.fromLTRB(columns[0], y, columns[1], y + rowH),
        size: 13,
        color: index < medicines.length ? _ink : _blue,
      );
      if (index >= medicines.length) continue;
      final medicine = medicines[index];
      _fitText(
        canvas,
        _medicineTitle(medicine),
        Rect.fromLTRB(columns[1] + 6, y + 3, columns[2] - 6, y + rowH - 3),
        size: 14,
        color: _ink,
        align: TextAlign.center,
      );
      _fitText(
        canvas,
        medicine.instructionSpecified,
        Rect.fromLTRB(columns[2] + 5, y + 3, columns[3] - 5, y + rowH - 3),
        size: 13,
        color: _ink,
        align: TextAlign.center,
      );
      _fitText(
        canvas,
        medicine.instructionUsage,
        Rect.fromLTRB(columns[3] + 5, y + 3, columns[4] - 5, y + rowH - 3),
        size: 13,
        color: _ink,
        align: TextAlign.center,
      );
      for (var routeIndex = 0; routeIndex < 4; routeIndex++) {
        final route = ['P', 'G', 'S', 'O'][routeIndex];
        if (medicine.routes.contains(route)) {
          _centerText(
            canvas,
            '✓',
            Rect.fromLTRB(
              columns[4 + routeIndex],
              y,
              columns[5 + routeIndex],
              y + rowH,
            ),
            size: 16,
            color: _ink,
          );
        }
      }
      _fitText(
        canvas,
        medicine.duration,
        Rect.fromLTRB(columns[8] + 6, y + 3, columns[9] - 6, y + rowH - 3),
        size: 13,
        color: _ink,
        align: TextAlign.center,
      );
      _fitText(
        canvas,
        medicine.remarks,
        Rect.fromLTRB(columns[9] + 6, y + 3, columns[10] - 6, y + rowH - 3),
        size: 13,
        color: _ink,
        align: TextAlign.center,
      );
    }

    final footerY = tableY + tableH - footerH;
    _text(
      canvas,
      'കോംപ്ലിമെന്ററി',
      Rect.fromLTWH(tableX + 18, footerY + 13, 150, 24),
      size: 18,
      weight: FontWeight.w800,
    );
    _text(
      canvas,
      'Rx :  Nil   /   Ay   /   H   /   U   /   Sd   /   N   /   O',
      Rect.fromLTWH(tableX + 185, footerY + 13, 520, 24),
      size: 18,
    );
    final selected = _complementaryCode(assessment.complementary);
    if (selected.isNotEmpty) {
      final selectedX = _complementaryX(selected);
      if (selectedX != null) {
        _text(
          canvas,
          '✓',
          Rect.fromLTWH(tableX + selectedX, footerY + 8, 24, 28),
          size: 20,
          color: _ink,
          weight: FontWeight.w800,
        );
      }
    }
  }

  static void _paintClinicalNotes(Canvas canvas, VisitAssessment assessment) {
    const x = 92.0;
    const tableBottom = 285.0 + 520.0;
    final medY = tableBottom + 18;
    _text(
      canvas,
      'മരുന്ന് സംബന്ധിച്ച് മറ്റു കാര്യങ്ങൾ (മരുന്ന് ചികിത്സ, മരുന്നറിവ്, ഫലം, ഉപയോഗങ്ങൾ തുടങ്ങിയവ) :',
      Rect.fromLTWH(x, medY, 980, 30),
      size: 18,
      weight: FontWeight.w700,
    );
    _fitText(
      canvas,
      assessment.medicineRemarks,
      Rect.fromLTWH(x + 20, medY + 38, 1030, 68),
      size: 17,
      color: _ink,
      lineHeight: 1.2,
    );

    final nursingY = medY + 122;
    _text(
      canvas,
      'നഴ്സിംഗ് രോഗനിർണയം / ഡോക്ടർ കൺസൾട്ട് / നഴ്സിംഗ് മാനേജ്മെന്റ് / മരുന്നുകൾ :',
      Rect.fromLTWH(x, nursingY, 1040, 36),
      size: 19,
      weight: FontWeight.w500,
    );
    final combined = [
      if (assessment.nursingDiagnosis.trim().isNotEmpty)
        'നഴ്സിംഗ് രോഗനിർണയം: ${assessment.nursingDiagnosis.trim()}',
      if (assessment.doctorConsultNotes.trim().isNotEmpty)
        'ഡോക്ടർ കൺസൾട്ട്: ${assessment.doctorConsultNotes.trim()}',
      if (assessment.nursingManagementPlan.trim().isNotEmpty)
        'നഴ്സിംഗ് മാനേജ്മെന്റ്: ${assessment.nursingManagementPlan.trim()}',
    ].join('\n');
    _fitText(
      canvas,
      combined,
      Rect.fromLTWH(x + 20, nursingY + 48, 1030, 132),
      size: 18,
      color: _ink,
      lineHeight: 1.25,
    );
  }

  static void _paintPlan(Canvas canvas, VisitAssessment assessment) {
    const planX = 105.0;
    const planY = 1132.0;
    const planW = 580.0;
    const rowH = 44.0;
    final border = _stroke(1.4);

    canvas.save();
    canvas.translate(planX - 30, planY + 135);
    canvas.rotate(-1.5708);
    _text(
      canvas,
      'പദ്ധതി',
      const Rect.fromLTWH(0, 0, 110, 28),
      size: 22,
      weight: FontWeight.w900,
      letterSpacing: 2,
    );
    canvas.restore();

    canvas.drawRect(Rect.fromLTWH(planX, planY, planW, rowH * 4), border);
    canvas.drawLine(
      Offset(planX + 112, planY),
      Offset(planX + 112, planY + rowH * 4),
      border,
    );
    for (var i = 1; i < 4; i++) {
      final y = planY + rowH * i;
      canvas.drawLine(Offset(planX, y), Offset(planX + planW, y), border);
    }

    var row = 0;
    for (final entry in _visitPlanLabels.entries) {
      final y = planY + rowH * row;
      _text(
        canvas,
        entry.value,
        Rect.fromLTWH(planX + 12, y + 9, 88, 24),
        size: 22,
        weight: FontWeight.w600,
      );
      final selected = assessment.carePlan.visitPlans.contains(entry.key);
      final note = assessment.carePlan.visitPlanNotes[entry.key] ?? '';
      final value = note.trim().isNotEmpty
          ? note
          : selected
          ? '✓'
          : '';
      _fitText(
        canvas,
        value,
        Rect.fromLTWH(planX + 125, y + 8, planW - 138, rowH - 12),
        size: 16,
        color: _ink,
        align: TextAlign.center,
      );
      row++;
    }

    const serviceX = 708.0;
    const serviceY = 1132.0;
    const serviceW = 415.0;
    const serviceRowH = 42.0;
    const serviceColW = serviceW / 2;
    canvas.drawRect(
      Rect.fromLTWH(serviceX, serviceY, serviceW, serviceRowH * 3),
      border,
    );
    canvas.drawLine(
      Offset(serviceX + serviceColW, serviceY),
      Offset(serviceX + serviceColW, serviceY + serviceRowH * 3),
      border,
    );
    for (var i = 1; i < 3; i++) {
      final y = serviceY + serviceRowH * i;
      canvas.drawLine(
        Offset(serviceX, y),
        Offset(serviceX + serviceW, y),
        border,
      );
    }
    final serviceOrder = [
      'healthEducation',
      'familyTraining',
      'physiotherapy',
      'dayCare',
      'socialSupport',
      'medicineSupport',
    ];
    for (var i = 0; i < serviceOrder.length; i++) {
      final row = i ~/ 2;
      final col = i % 2;
      final rect = Rect.fromLTWH(
        serviceX + col * serviceColW,
        serviceY + row * serviceRowH,
        serviceColW,
        serviceRowH,
      );
      final selected = assessment.carePlan.services.contains(serviceOrder[i]);
      _text(
        canvas,
        selected ? '✓' : '',
        Rect.fromLTWH(rect.left + 8, rect.top + 7, 26, 24),
        size: 17,
        color: _ink,
      );
      _centerText(
        canvas,
        _serviceLabels[serviceOrder[i]]!,
        Rect.fromLTWH(
          rect.left + 26,
          rect.top + 5,
          rect.width - 34,
          rect.height - 10,
        ),
        size: 15,
      );
    }
    _text(
      canvas,
      'തുടർ പരിചരണത്തിന് ആവശ്യമുള്ള ടിക് ചെയ്യുക',
      const Rect.fromLTWH(serviceX, serviceY + 140, 420, 28),
      size: 18,
      weight: FontWeight.w700,
    );

    _text(
      canvas,
      'ടീം മീറ്റിംഗ് ചർച്ച :',
      const Rect.fromLTWH(planX, 1345, 315, 28),
      size: 20,
      weight: FontWeight.w500,
    );
    _fitText(
      canvas,
      assessment.teamMeetingDiscussion,
      const Rect.fromLTWH(planX + 305, 1340, 810, 95),
      size: 18,
      color: _ink,
      lineHeight: 1.2,
    );
  }

  static void _paintSignatureArea(Canvas canvas, VisitAssessment assessment) {
    _lineField(
      canvas,
      label: 'നഴ്സിന്റെ പേര്:',
      value: assessment.nurseName,
      x: 90,
      y: 1584,
      lineWidth: 265,
      valueWidth: 260,
      size: 22,
    );
    _lineField(
      canvas,
      label: 'ഒപ്പ് :',
      value: '',
      x: 560,
      y: 1584,
      lineWidth: 330,
      valueWidth: 260,
      size: 22,
    );
  }

  static void _headerField(
    Canvas canvas, {
    required String label,
    required String value,
    required double labelX,
    required double valueX,
    required double y,
    required double width,
  }) {
    _fitText(
      canvas,
      label,
      Rect.fromLTWH(labelX, y, valueX - labelX - 8, 26),
      size: 17,
    );
    _fitText(
      canvas,
      value,
      Rect.fromLTWH(valueX, y - 2, width, 30),
      size: 19,
      color: _ink,
    );
  }

  static void _lineField(
    Canvas canvas, {
    required String label,
    required String value,
    required double x,
    required double y,
    required double lineWidth,
    String suffix = '',
    double valueWidth = 120,
    double size = 19,
  }) {
    final labelWidth = _measure(label, size: size).width + 8;
    _text(canvas, label, Rect.fromLTWH(x, y, labelWidth, 28), size: size);
    final lineStart = x + labelWidth;
    final lineY = y + size + 4;
    canvas.drawLine(
      Offset(lineStart, lineY),
      Offset(lineStart + lineWidth, lineY),
      _stroke(1.2),
    );
    _fitText(
      canvas,
      value,
      Rect.fromLTWH(lineStart + 4, y - 1, valueWidth, 28),
      size: size - 1,
      color: _ink,
    );
    if (suffix.isNotEmpty) {
      _text(
        canvas,
        suffix,
        Rect.fromLTWH(lineStart + lineWidth + 8, y, 190, 28),
        size: size,
      );
    }
  }

  static void _checkboxLabel(
    Canvas canvas, {
    required String label,
    required bool checked,
    required double x,
    required double y,
  }) {
    final labelWidth = _measure(label, size: 18).width + 8;
    _text(canvas, label, Rect.fromLTWH(x, y, labelWidth, 24), size: 18);
    final box = Rect.fromLTWH(x + labelWidth, y - 2, 23, 23);
    canvas.drawRect(box, _stroke(1.2));
    if (checked) {
      _text(
        canvas,
        '✓',
        Rect.fromLTWH(box.left + 2, box.top - 4, 22, 28),
        size: 22,
        color: _ink,
        weight: FontWeight.w800,
      );
    }
  }

  static void _underlinedText(
    Canvas canvas,
    String text,
    Offset offset, {
    required double size,
    required double width,
  }) {
    _text(
      canvas,
      text,
      Rect.fromLTWH(offset.dx, offset.dy, width + 40, 32),
      size: size,
      weight: FontWeight.w800,
    );
    canvas.drawLine(
      Offset(offset.dx, offset.dy + size + 6),
      Offset(offset.dx + width, offset.dy + size + 6),
      _stroke(1.2),
    );
  }

  static void _centerText(
    Canvas canvas,
    String text,
    Rect rect, {
    double size = 16,
    Color color = _blue,
    FontWeight weight = FontWeight.w600,
  }) {
    _fitText(
      canvas,
      text,
      rect,
      size: size,
      color: color,
      weight: weight,
      align: TextAlign.center,
      lineHeight: 1.12,
    );
  }

  static void _text(
    Canvas canvas,
    String text,
    Rect rect, {
    double size = 18,
    Color color = _blue,
    FontWeight weight = FontWeight.w500,
    TextAlign align = TextAlign.left,
    double lineHeight = 1.15,
    double letterSpacing = 0,
  }) {
    if (text.isEmpty) return;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: weight,
          height: lineHeight,
          letterSpacing: letterSpacing,
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallbacks,
        ),
      ),
      textAlign: align,
      textDirection: ui.TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout(minWidth: rect.width, maxWidth: rect.width);
    final dy = align == TextAlign.center
        ? rect.top + (rect.height - painter.height) / 2
        : rect.top;
    painter.paint(canvas, Offset(rect.left, dy));
  }

  static void _fitText(
    Canvas canvas,
    String text,
    Rect rect, {
    double size = 18,
    Color color = _blue,
    FontWeight weight = FontWeight.w500,
    double lineHeight = 1.18,
    TextAlign align = TextAlign.left,
  }) {
    final clean = text.trim();
    if (clean.isEmpty) return;
    var fontSize = size;
    TextPainter painter;
    while (true) {
      painter = TextPainter(
        text: TextSpan(
          text: clean,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: weight,
            height: lineHeight,
            fontFamily: _fontFamily,
            fontFamilyFallback: _fontFallbacks,
          ),
        ),
        textAlign: align,
        textDirection: ui.TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout(minWidth: rect.width, maxWidth: rect.width);
      if (painter.height <= rect.height || fontSize <= 7) break;
      fontSize -= 0.5;
    }
    canvas.save();
    canvas.clipRect(rect);
    final dy = align == TextAlign.center
        ? rect.top + (rect.height - painter.height) / 2
        : rect.top;
    painter.paint(canvas, Offset(rect.left, dy));
    canvas.restore();
  }

  static Size _measure(String text, {required double size}) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w500,
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallbacks,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    return painter.size;
  }

  static Paint _stroke(double width) => Paint()
    ..color = _blue
    ..style = PaintingStyle.stroke
    ..strokeWidth = width;

  static String _date(DateTime value) => DateFormat('dd/MM/yyyy').format(value);

  static String _visitModeLabel(String value) {
    final key = value.trim();
    if (key.isEmpty) return _visitModeLabels['new']!;
    return _visitModeLabels[key] ?? key.toUpperCase();
  }

  static String _number(num? value) {
    if (value == null) return '';
    if (value is double && value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  static String _bpValue(int? systolic, int? diastolic) {
    if (systolic == null && diastolic == null) return '';
    return '${systolic ?? ''}/${diastolic ?? ''}';
  }

  static String _position(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return '';
    return clean;
  }

  static String _rhythm(String value) {
    final clean = value.trim().toUpperCase();
    if (clean == 'R' || clean == 'REGULAR') return 'R/R';
    if (clean == 'IR' || clean == 'IRREGULAR') return 'Ir/R';
    return value;
  }

  static String _temperatureUnit(String value) =>
      value.trim().toUpperCase() == 'F' ? '°F' : '°C';

  static String _temperatureMethodCode(String value) {
    final clean = value.trim().toUpperCase();
    if (clean == 'ORAL') return 'O';
    if (clean == 'AXILLARY') return 'A';
    if (clean == 'RECTAL') return 'R';
    if (['O', 'A', 'R'].contains(clean)) return clean;
    return clean.isEmpty ? 'O/A/R' : clean;
  }

  static String _findingValue(ExamFinding finding) {
    final pieces = <String>[];
    if (finding.value.trim().isNotEmpty) {
      pieces.add(_labelFromToken(finding.value));
    } else if (finding.status != 'not_assessed') {
      pieces.add(_labelFromToken(finding.status));
    }
    for (final value in finding.extraValues.values) {
      if (value.trim().isNotEmpty) pieces.add(_labelFromToken(value));
    }
    if (finding.notes.trim().isNotEmpty) pieces.add(finding.notes.trim());
    if (finding.images.isNotEmpty) {
      pieces.add('${finding.images.length} ചിത്രം');
    }
    return pieces.join(' - ');
  }

  static String _medicineTitle(AssessmentMedicine medicine) {
    final name = medicine.medicineName.trim();
    final strength = medicine.strength.trim();
    if (name.isEmpty) return strength;
    if (strength.isEmpty) return name;
    return '$name, $strength';
  }

  static String _labelFromToken(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return '';
    final token = clean
        .toLowerCase()
        .replaceAll(RegExp(r'[\s-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final malayalamLabel = _malayalamTokenLabels[token];
    if (malayalamLabel != null) return malayalamLabel;
    return clean
        .split(RegExp(r'[_\s-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  static String _complementaryCode(String value) {
    final clean = value.trim();
    const allowed = {'Nil', 'Ay', 'H', 'U', 'Sd', 'N', 'O'};
    if (allowed.contains(clean)) return clean;
    return '';
  }

  static double? _complementaryX(String value) {
    switch (value) {
      case 'Nil':
        return 236;
      case 'Ay':
        return 298;
      case 'H':
        return 359;
      case 'U':
        return 415;
      case 'Sd':
        return 475;
      case 'N':
        return 542;
      case 'O':
        return 598;
      default:
        return null;
    }
  }
}
