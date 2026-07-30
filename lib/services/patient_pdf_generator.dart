import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:oruma_app/models/patient.dart';
import 'package:oruma_app/models/patient_details.dart';
import 'package:oruma_app/models/medicine_supply_activity.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Generates a comprehensive multi-page patient report PDF.
/// Pages are created dynamically — sections flow onto new pages only when the
/// current page runs out of space.
class PatientPdfGenerator {
  const PatientPdfGenerator._();

  // ─── Layout constants ─────────────────────────────────────────────────────
  // Keep the drawing layout in 150 DPI A4 coordinates, then rasterise the
  // recorded canvas at 4x so the PDF embeds 600 DPI A4 pages for printing.
  static const double _pw = 1240.0;
  static const double _ph = 1754.0;
  static const double _rasterScale = 4.0;
  static int get _rasterW => (_pw * _rasterScale).round();
  static int get _rasterH => (_ph * _rasterScale).round();
  static const String _fontFamily = 'NotoSansMalayalam';
  static const List<String> _fontFallbacks = <String>['Roboto', 'Arial'];
  static const double _marginL = 56.0;
  static const double _marginR = 56.0;
  static const double _contentW = 1128.0; // _pw - _marginL - _marginR
  static const double _headerBottom = 190.0;
  static const double _footerH = 80.0; // reserved at bottom of every page
  static const double _maxContentY = _ph - _footerH;
  static const double _contentStart = _headerBottom + 32.0;

  // ─── Typography spacing ───────────────────────────────────────────────────
  static const double _sectionGap = 36.0; // gap above each section title
  static const double _afterTitleGap = 14.0; // gap below section title divider
  static const double _defaultRowH = 54.0;
  static const double _tableRowH = 54.0;
  static const double _tableHeaderH = 50.0;

  // ─── Colours ──────────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF185FA5);
  static const Color _primaryLight = Color(0xFFE6F1FB);
  static const Color _ink = Color(0xFF1A2233);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFD1DFF0);
  static const Color _headerBg = Color(0xFF185FA5);
  static const Color _altRow = Color(0xFFF0F6FC);

  // ─── Org info ─────────────────────────────────────────────────────────────
  static const String _orgName = 'CareNest';
  static const String _orgSub = 'Palliative Care Management';

  // ═══════════════════════════════════════════════════════════════════════════
  // Public API
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<Uint8List> generate(
    PatientDetails details, {
    PatientReportBrand? brand,
  }) async {
    final reportBrand = brand ?? const PatientReportBrand();
    final logoBytes = await _loadLogo(reportBrand.logoSource);
    ui.Image? logo;
    if (logoBytes != null) logo = await _decodeImage(logoBytes);

    final writer = _PageWriter(logo, reportBrand);
    await writer.start();

    final p = details.patient;

    // ── Patient banner (always starts on page 1 right after the header) ───
    writer.y = _paintPatientBanner(writer.canvas, p, writer.y);
    writer.y += 32;

    // ── Section A – Personal Information ──────────────────────────────────
    await _renderInfoSection(writer, 'A', 'Personal Information', [
      _Row('Register ID', _v(p.registerId)),
      _Row('Full Name', _displayName(p.name)),
      _Row('Phone', _v(p.phone)),
      _Row('Caregiver / Relation', _v(p.relation)),
      _Row('Caregiver Phone', _v(p.phone2)),
      if (p.volunteerName?.trim().isNotEmpty == true)
        _Row('Volunteer Name', _v(p.volunteerName)),
      if (p.volunteerContact?.trim().isNotEmpty == true)
        _Row('Volunteer Contact', _v(p.volunteerContact)),
      _Row('Gender', _v(p.gender)),
      _Row('Age', '${p.age} years'),
    ], firstSection: true);

    // ── Section B – Location & Address ────────────────────────────────────
    await _renderInfoSection(writer, 'B', 'Location & Address', [
      _Row('Address', _v(p.address), height: 80), // taller for multi-line
      _Row('Place', _v(p.place)),
      _Row('Village', _v(p.village)),
      _Row('Ward Number', _v(p.ward)),
    ]);

    // ── Section C – Medical Details ───────────────────────────────────────
    await _renderInfoSection(writer, 'C', 'Medical Details', [
      _Row(
        'Conditions',
        p.disease.isEmpty ? 'No conditions recorded' : p.disease.join(', '),
      ),
      _Row('Care Plan', _v(p.plan)),
    ]);

    // ── Section D – Record Information ────────────────────────────────────
    await _renderInfoSection(writer, 'D', 'Record Information', [
      _Row('Registration Date', _fmtDate(p.registrationDate)),
      if (p.isDead) _Row('Date of Death', _fmtDate(p.dateOfDeath)),
      _Row('Last Updated', _fmtDateTime(p.updatedAt)),
    ]);

    // ── Section E – Home Visits ───────────────────────────────────────────
    const hvCols = <String>[
      '#',
      'Date',
      'Type',
      'Team',
      'Address',
      'Notes',
      'Recorded By',
    ];
    final hvWidths = _scaleWidths([44, 130, 100, 170, 230, 230, 200]);
    await _renderTableSection(
      writer,
      'E',
      'Home Visits (${details.homeVisits.length})',
      hvCols,
      hvWidths,
      details.homeVisits.asMap().entries.map((e) {
        final v = e.value;
        return _TRow([
          '${e.key + 1}',
          _fmtVisitDate(v.visitDate),
          _visitModeLabel(v.visitMode),
          _v(v.team),
          _v(v.address),
          _v(v.notes),
          _v(v.createdBy),
        ]);
      }).toList(),
      'No home visits recorded',
    );

    // ── Section F – Equipment Distributed ────────────────────────────────
    const eqCols = <String>[
      '#',
      'Equipment',
      'ID',
      'Distributed',
      'Exp. Return',
      'Returned',
      'Receiver',
      'Status',
    ];
    final eqWidths = _scaleWidths([40, 210, 140, 115, 115, 115, 200, 120]);
    await _renderTableSection(
      writer,
      'F',
      'Equipment Distributed (${details.equipmentSupplies.length})',
      eqCols,
      eqWidths,
      details.equipmentSupplies.asMap().entries.map((e) {
        final s = e.value;
        return _TRow(
          [
            '${e.key + 1}',
            _v(s.equipmentName),
            _v(s.equipmentUniqueId),
            _fmtDate(s.supplyDate),
            s.returnDate != null ? _fmtDate(s.returnDate) : '—',
            s.actualReturnDate != null ? _fmtDate(s.actualReturnDate) : '—',
            s.receiverName != null
                ? '${_v(s.receiverName)}\n${_v(s.receiverPhone)}'
                : _v(s.careOf),
            _equipStatusLabel(s.status),
          ],
          statusColIndex: 7,
          statusValue: s.status,
        );
      }).toList(),
      'No equipment distributed',
    );

    // ── Section G – Medicine Supply Activity ──────────────────────────────
    final medicineActivities = MedicineSupplyActivity.fromSupplies(
      details.medicineSupplies,
    );
    const medCols = <String>[
      '#',
      'Date',
      'Activity',
      'Medicine',
      'Qty',
      'Batch',
      'Supply',
      'Expiry',
      'Stock',
    ];
    final medWidths = _scaleWidths([40, 125, 105, 210, 80, 140, 125, 125, 178]);
    await _renderTableSection(
      writer,
      'G',
      'Medicine Activity History (${medicineActivities.length})',
      medCols,
      medWidths,
      medicineActivities.asMap().entries.map((e) {
        final activity = e.value;
        final medicine = [
          activity.medicineName,
          if (activity.medicineCode.trim().isNotEmpty)
            activity.medicineCode.trim(),
        ].join('\n');
        return _TRow(
          [
            '${e.key + 1}',
            _fmtDate(activity.date),
            activity.eventLabel,
            medicine,
            activity.quantityLabel,
            _v(activity.batchNumber),
            _fmtDate(activity.supplyDate),
            _fmtDate(activity.expiryDate),
            _v(activity.stockLabel),
          ],
          statusColIndex: 2,
          statusValue: activity.statusValue,
        );
      }).toList(),
      'No medicine activity recorded',
    );

    // ── Section H – Social Support ───────────────────────────────────────
    const supportCols = <String>[
      '#',
      'Date',
      'Support',
      'Volunteer',
      'Contact',
      'Note',
    ];
    final supportWidths = _scaleWidths([40, 130, 230, 220, 160, 265]);
    await _renderTableSection(
      writer,
      'H',
      'Social Support (${details.socialSupports.length})',
      supportCols,
      supportWidths,
      details.socialSupports.asMap().entries.map((e) {
        final s = e.value;
        return _TRow([
          '${e.key + 1}',
          _fmtDate(s.givenAt),
          _v(s.supportTypesLabel),
          _v(s.volunteerName),
          _v(s.volunteerContact),
          _v(s.note),
        ]);
      }).toList(),
      'No social support recorded',
    );

    final pageBytes = await writer.finish();
    logo?.dispose();

    // Pack rasterised page images into a PDF document
    final doc = pw.Document();
    for (final bytes in pageBytes) {
      final img = pw.MemoryImage(bytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Image(img, fit: pw.BoxFit.fill),
          ),
        ),
      );
    }
    return doc.save();
  }

  static String fileName(Patient patient) {
    final name = patient.name
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final id = patient.registerId?.trim().replaceAll('/', '-') ?? 'pt';
    final date = DateFormat('yyyyMMdd').format(DateTime.now());
    return 'patient_report_${name.isEmpty ? id : name.toLowerCase()}_$date.pdf';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Section renderers (use _PageWriter, trigger page breaks when needed)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Renders an info-grid section. Keeps the entire section together on one
  /// page — if it doesn't fit, starts a fresh page first.
  static Future<void> _renderInfoSection(
    _PageWriter w,
    String letter,
    String title,
    List<_Row> rows, {
    bool firstSection = false,
  }) async {
    if (!firstSection) w.y += _sectionGap;

    // Total height of title badge + gap + all rows
    final rowsH = rows.fold<double>(
      0,
      (s, r) => s + (r.height ?? _defaultRowH),
    );
    final needed = 38.0 + _afterTitleGap + rowsH;

    if (!w.hasSpace(needed)) await w.newPage();

    w.y = _paintSectionTitle(w.canvas, letter, title, w.y);
    w.y += _afterTitleGap;
    w.y = _paintInfoGrid(w.canvas, rows, w.y);
  }

  /// Renders a table section. Rows spill onto additional pages automatically:
  /// a new page gets the same table header (with "continued" marker) and
  /// continues where the previous page left off.
  static Future<void> _renderTableSection(
    _PageWriter w,
    String letter,
    String title,
    List<String> cols,
    List<double> widths,
    List<_TRow> rows,
    String emptyMsg,
  ) async {
    w.y += _sectionGap;

    // Minimum height: title + gap + header row + at least one data row (or empty state)
    final minH =
        38.0 +
        _afterTitleGap +
        _tableHeaderH +
        (rows.isEmpty ? 80.0 : _tableRowH);
    if (!w.hasSpace(minH)) await w.newPage();

    w.y = _paintSectionTitle(w.canvas, letter, title, w.y);
    w.y += _afterTitleGap;

    if (rows.isEmpty) {
      w.y = _paintEmptyState(w.canvas, emptyMsg, w.y);
      return;
    }

    final tableW = widths.fold<double>(0, (s, v) => s + v);
    double tableTopY = w.y;
    w.y = _paintTableHeader(w.canvas, cols, widths, w.y);

    for (var i = 0; i < rows.length; i++) {
      if (!w.hasSpace(_tableRowH)) {
        // Close the current chunk of the table with a border
        _drawTableBorder(w.canvas, tableTopY, w.y, tableW);
        // Start a new page and re-draw the header (marked as continued)
        await w.newPage();
        tableTopY = w.y;
        w.y = _paintTableHeader(w.canvas, cols, widths, w.y);
      }
      final row = rows[i];
      w.y = _paintTableRow(
        w.canvas,
        row.cells,
        widths,
        w.y,
        alt: i.isOdd,
        statusColIndex: row.statusColIndex,
        statusValue: row.statusValue,
      );
    }
    _drawTableBorder(w.canvas, tableTopY, w.y, tableW);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Low-level painters (work on a raw Canvas)
  // ═══════════════════════════════════════════════════════════════════════════

  static void _paintPageHeader(
    Canvas c,
    ui.Image? logo,
    int page,
    PatientReportBrand brand,
  ) {
    c.drawRect(
      const Rect.fromLTWH(0, 0, _pw, _headerBottom),
      Paint()..color = _headerBg,
    );

    const logoSize = 84.0;
    const logoX = _marginL;
    const logoY = (_headerBottom - logoSize) / 2;
    if (logo != null) {
      c.save();
      c.clipPath(
        Path()..addOval(const Rect.fromLTWH(logoX, logoY, logoSize, logoSize)),
      );
      c.drawImageRect(
        logo,
        Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
        const Rect.fromLTWH(logoX, logoY, logoSize, logoSize),
        Paint(),
      );
      c.restore();
      c.drawCircle(
        const Offset(logoX + logoSize / 2, logoY + logoSize / 2),
        logoSize / 2,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    _text(
      c,
      brand.orgName,
      const Rect.fromLTWH(160, 38, 600, 52),
      size: 40,
      weight: FontWeight.w800,
      color: Colors.white,
    );
    _text(
      c,
      brand.orgSub,
      const Rect.fromLTWH(160, 92, 500, 30),
      size: 22,
      color: Colors.white.withValues(alpha: 0.82),
    );
    _text(
      c,
      brand.phoneLine,
      const Rect.fromLTWH(160, 126, 700, 28),
      size: 19,
      color: Colors.white.withValues(alpha: 0.72),
    );

    _text(
      c,
      'PATIENT REPORT',
      const Rect.fromLTWH(860, 38, 330, 42),
      size: 28,
      weight: FontWeight.w900,
      color: Colors.white,
      align: TextAlign.right,
    );
    _text(
      c,
      'Generated: ${DateFormat('dd MMM yyyy, h:mm a').format(DateTime.now())}',
      const Rect.fromLTWH(760, 86, 430, 26),
      size: 17,
      color: Colors.white.withValues(alpha: 0.72),
      align: TextAlign.right,
    );
    _text(
      c,
      'Page $page',
      const Rect.fromLTWH(760, 116, 430, 26),
      size: 18,
      weight: FontWeight.w700,
      color: Colors.white.withValues(alpha: 0.85),
      align: TextAlign.right,
    );
  }

  static double _paintPatientBanner(Canvas c, Patient p, double y) {
    const bannerH = 134.0;
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(_marginL, y, _contentW, bannerH),
        const Radius.circular(18),
      ),
      Paint()..color = _primaryLight,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(_marginL, y, 8, bannerH),
        const Radius.circular(18),
      ),
      Paint()..color = _primary,
    );

    const avatarR = 48.0;
    final avatarCx = _marginL + 38.0;
    final avatarCy = y + bannerH / 2;
    c.drawCircle(
      Offset(avatarCx, avatarCy),
      avatarR,
      Paint()..color = _primary,
    );

    final initial = p.name.trim().isEmpty
        ? '?'
        : p.name.trim()[0].toUpperCase();
    _centeredText(
      c,
      initial,
      Rect.fromLTWH(
        avatarCx - avatarR,
        avatarCy - avatarR,
        avatarR * 2,
        avatarR * 2,
      ),
      size: 38,
      weight: FontWeight.w900,
      color: Colors.white,
    );

    _text(
      c,
      _displayName(p.name),
      Rect.fromLTWH(avatarCx + avatarR + 16, y + 16, 680, 46),
      size: 34,
      weight: FontWeight.w800,
      color: _ink,
    );

    final secondary = <String>[
      if (p.registerId?.isNotEmpty == true) 'ID ${p.registerId}',
      if (p.gender.isNotEmpty) p.gender,
      '${p.age} years',
    ].join('   •   ');
    _text(
      c,
      secondary,
      Rect.fromLTWH(avatarCx + avatarR + 16, y + 62, 680, 28),
      size: 20,
      color: _muted,
    );

    if (p.disease.isNotEmpty) {
      _text(
        c,
        p.disease.take(5).join('   '),
        Rect.fromLTWH(avatarCx + avatarR + 16, y + 96, 680, 26),
        size: 18,
        weight: FontWeight.w700,
        color: _primary,
      );
    }

    final statusLabel = p.isDead ? 'Passed Away' : 'Active';
    final statusColor = p.isDead ? Colors.red.shade700 : Colors.green.shade700;
    const pillW = 150.0;
    const pillH = 40.0;
    final pillRect = Rect.fromLTWH(
      _marginL + _contentW - pillW - 16,
      y + (bannerH - pillH) / 2,
      pillW,
      pillH,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(pillRect, const Radius.circular(99)),
      Paint()..color = statusColor.withValues(alpha: 0.12),
    );
    _centeredText(
      c,
      statusLabel,
      pillRect,
      size: 18,
      weight: FontWeight.w800,
      color: statusColor,
    );

    return y + bannerH;
  }

  static double _paintSectionTitle(
    Canvas c,
    String letter,
    String title,
    double y,
  ) {
    const badgeSize = 38.0;
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(_marginL, y, badgeSize, badgeSize),
        const Radius.circular(10),
      ),
      Paint()..color = _primary,
    );
    _centeredText(
      c,
      letter,
      Rect.fromLTWH(_marginL, y, badgeSize, badgeSize),
      size: 22,
      weight: FontWeight.w900,
      color: Colors.white,
    );
    _text(
      c,
      title,
      Rect.fromLTWH(_marginL + badgeSize + 12, y + 5, 800, 30),
      size: 26,
      weight: FontWeight.w800,
      color: _primary,
    );
    c.drawLine(
      Offset(_marginL + badgeSize + 12, y + badgeSize),
      Offset(_pw - _marginR, y + badgeSize),
      Paint()
        ..color = _border
        ..strokeWidth = 1.5,
    );
    return y + badgeSize;
  }

  static double _paintInfoGrid(Canvas c, List<_Row> rows, double y) {
    const labelW = 250.0;
    const valueX = _marginL + labelW + 20;

    var curY = y;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowH = row.height ?? _defaultRowH;
      if (i.isOdd) {
        c.drawRect(
          Rect.fromLTWH(_marginL, curY, _contentW, rowH),
          Paint()..color = _altRow,
        );
      }
      _centeredText(
        c,
        row.label,
        Rect.fromLTWH(_marginL + 16, curY, labelW - 16, rowH),
        size: 18,
        weight: FontWeight.w600,
        color: _muted,
        align: TextAlign.left,
      );
      _centeredText(
        c,
        row.value,
        Rect.fromLTWH(valueX, curY, _pw - valueX - _marginR, rowH),
        size: 18,
        weight: FontWeight.w700,
        color: _ink,
        align: TextAlign.left,
      );
      curY += rowH;
    }
    c.drawLine(
      Offset(_marginL, curY),
      Offset(_pw - _marginR, curY),
      Paint()
        ..color = _border
        ..strokeWidth = 1.2,
    );
    return curY;
  }

  static double _paintEmptyState(Canvas c, String message, double y) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(_marginL, y, _contentW, 68),
        const Radius.circular(12),
      ),
      Paint()..color = const Color(0xFFF3F4F6),
    );
    _text(
      c,
      message,
      Rect.fromLTWH(_marginL, y + 18, _contentW, 36),
      size: 20,
      color: _muted,
      align: TextAlign.center,
    );
    return y + 80;
  }

  static double _paintTableHeader(
    Canvas c,
    List<String> cols,
    List<double> widths,
    double y,
  ) {
    final tableW = widths.fold<double>(0, (s, w) => s + w);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(_marginL, y, tableW, _tableHeaderH),
        const Radius.circular(10),
      ),
      Paint()..color = _primary,
    );
    var x = _marginL;
    for (var i = 0; i < cols.length; i++) {
      _centeredText(
        c,
        cols[i],
        Rect.fromLTWH(x + 4, y, widths[i] - 8, _tableHeaderH),
        size: 16,
        weight: FontWeight.w800,
        color: Colors.white,
      );
      x += widths[i];
    }
    return y + _tableHeaderH;
  }

  static double _paintTableRow(
    Canvas c,
    List<String> cells,
    List<double> widths,
    double y, {
    bool alt = false,
    int? statusColIndex,
    String? statusValue,
  }) {
    final tableW = widths.fold<double>(0, (s, w) => s + w);
    if (alt) {
      c.drawRect(
        Rect.fromLTWH(_marginL, y, tableW, _tableRowH),
        Paint()..color = _altRow,
      );
    }
    var x = _marginL;
    for (var i = 0; i < cells.length; i++) {
      if (i == statusColIndex && statusValue != null) {
        const pillH = 32.0;
        final pillW = widths[i] - 20;
        final pillRect = Rect.fromLTWH(
          x + 10,
          y + (_tableRowH - pillH) / 2,
          pillW,
          pillH,
        );
        _paintStatusPill(c, cells[i], statusValue, pillRect);
      } else {
        _centeredText(
          c,
          cells[i],
          Rect.fromLTWH(x + 8, y, widths[i] - 16, _tableRowH),
          size: 15,
          color: _ink,
          align: TextAlign.left,
        );
      }
      if (i < cells.length - 1) {
        c.drawLine(
          Offset(x + widths[i], y),
          Offset(x + widths[i], y + _tableRowH),
          Paint()
            ..color = _border
            ..strokeWidth = 1.0,
        );
      }
      x += widths[i];
    }
    c.drawLine(
      Offset(_marginL, y + _tableRowH),
      Offset(_marginL + tableW, y + _tableRowH),
      Paint()
        ..color = _border
        ..strokeWidth = 0.8,
    );
    return y + _tableRowH;
  }

  static void _drawTableBorder(
    Canvas c,
    double topY,
    double bottomY,
    double tableW,
  ) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(_marginL, topY, tableW, bottomY - topY),
        const Radius.circular(10),
      ),
      Paint()
        ..color = _border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  static void _paintStatusPill(
    Canvas c,
    String label,
    String status,
    Rect rect,
  ) {
    final color = _statusColor(status);
    c.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(99)),
      Paint()..color = color.withValues(alpha: 0.12),
    );
    _centeredText(
      c,
      label,
      rect,
      size: 14,
      weight: FontWeight.w800,
      color: color,
    );
  }

  static void _paintPageFooter(Canvas c, PatientReportBrand brand) {
    const footerY = _ph - 60.0;
    c.drawLine(
      const Offset(_marginL, footerY),
      const Offset(_pw - _marginR, footerY),
      Paint()
        ..color = _border
        ..strokeWidth = 1.2,
    );
    _text(
      c,
      brand.pageFooter,
      Rect.fromLTWH(_marginL, footerY + 10, _contentW, 28),
      size: 16,
      color: _muted,
      align: TextAlign.center,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Text utilities
  // ═══════════════════════════════════════════════════════════════════════════

  /// Draws text top-aligned from the top-left of [rect].
  static void _text(
    Canvas c,
    String text,
    Rect rect, {
    double size = 18,
    FontWeight weight = FontWeight.w500,
    Color color = _ink,
    TextAlign align = TextAlign.left,
    double lineHeight = 1.2,
  }) {
    final pb =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: align,
              maxLines: 3,
              ellipsis: '\u2026',
            ),
          )
          ..pushStyle(
            ui.TextStyle(
              fontSize: size,
              fontWeight: weight,
              color: color,
              height: lineHeight,
              fontFamily: _fontFamily,
              fontFamilyFallback: _fontFallbacks,
            ),
          )
          ..addText(text.isEmpty ? ' ' : text);
    final para = pb.build()..layout(ui.ParagraphConstraints(width: rect.width));
    c.drawParagraph(para, rect.topLeft);
  }

  /// Draws text that is both horizontally and VERTICALLY centred within [rect].
  static void _centeredText(
    Canvas c,
    String text,
    Rect rect, {
    double size = 18,
    FontWeight weight = FontWeight.w500,
    Color color = _ink,
    TextAlign align = TextAlign.center,
  }) {
    final pb =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: align,
              maxLines: 2,
              ellipsis: '\u2026',
            ),
          )
          ..pushStyle(
            ui.TextStyle(
              fontSize: size,
              fontWeight: weight,
              color: color,
              height: 1.15,
              fontFamily: _fontFamily,
              fontFamilyFallback: _fontFallbacks,
            ),
          )
          ..addText(text.isEmpty ? ' ' : text);
    final para = pb.build()..layout(ui.ParagraphConstraints(width: rect.width));
    final dy = ((rect.height - para.height) / 2).clamp(0.0, rect.height);
    c.drawParagraph(para, Offset(rect.left, rect.top + dy));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Asset helpers
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<Uint8List?> _loadLogo(String? source) async {
    final dataUrlLogo = _decodeDataUrlImage(source);
    if (dataUrlLogo != null) return dataUrlLogo;

    try {
      final data = await rootBundle.load('assets/logo/logo.png');
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  static Uint8List? _decodeDataUrlImage(String? source) {
    if (source == null || !source.startsWith('data:image/')) return null;
    final commaIndex = source.indexOf(',');
    if (commaIndex < 0) return null;
    try {
      return base64Decode(source.substring(commaIndex + 1));
    } catch (_) {
      return null;
    }
  }

  static Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  /// Scales raw widths proportionally so their sum equals exactly [_contentW].
  static List<double> _scaleWidths(List<double> raw) {
    final sum = raw.fold<double>(0, (s, w) => s + w);
    final scale = _contentW / sum;
    return raw.map((w) => w * scale).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Value helpers
  // ═══════════════════════════════════════════════════════════════════════════

  static String _v(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Not recorded' : value.trim();

  static String _displayName(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s*,\s*'), ', ');
    return normalized
        .split(RegExp(r'\s+'))
        .map((w) {
          if (w.isEmpty) return w;
          return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
        })
        .join(' ');
  }

  static String _fmtDate(DateTime? d) =>
      d == null ? '—' : DateFormat('dd MMM yyyy').format(d.toLocal());

  static String _fmtDateTime(DateTime? d) =>
      d == null ? '—' : DateFormat('dd MMM yyyy, h:mm a').format(d.toLocal());

  static String _fmtVisitDate(String value) {
    final d = DateTime.tryParse(value);
    return d == null ? _v(value) : _fmtDate(d);
  }

  static String _visitModeLabel(String mode) => switch (mode) {
    'new' => 'New',
    'monthly' => 'Planned',
    'emergency' => 'Emergency',
    'dhc_visit' => 'DHC',
    'vhc_visit' => 'VHC',
    _ => mode.replaceAll('_', ' ').toUpperCase(),
  };

  static String _equipStatusLabel(String status) => switch (status) {
    'active' => 'Active',
    'returned' => 'Returned',
    'lost' => 'Lost',
    _ => status,
  };

  static Color _statusColor(String status) => switch (status) {
    'active' || 'given' => Colors.green.shade700,
    'returned' => Colors.blueGrey.shade700,
    'lost' || 'cancelled' => Colors.red.shade700,
    'partially_given' => Colors.orange.shade700,
    'emergency' => Colors.red,
    'monthly' => Colors.blue,
    _ => Colors.grey.shade700,
  };
}

class PatientReportBrand {
  const PatientReportBrand({
    this.name,
    this.subtitle,
    this.supportPhone,
    this.contactPhone,
    this.logoSource,
  });

  final String? name;
  final String? subtitle;
  final String? supportPhone;
  final String? contactPhone;
  final String? logoSource;

  String get orgName => _clean(name) ?? PatientPdfGenerator._orgName;

  String get orgSub => _clean(subtitle) ?? PatientPdfGenerator._orgSub;

  String get phoneLine {
    final phones = <String>[];
    for (final phone in [_clean(supportPhone), _clean(contactPhone)]) {
      if (phone != null && !phones.contains(phone)) phones.add(phone);
    }
    if (phones.isEmpty) {
      return 'Support contact not configured';
    }
    return phones.join('   |   ');
  }

  String get pageFooter => '$orgName - Confidential Patient Report';

  static String? _clean(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}

// ─── Page writer ─────────────────────────────────────────────────────────────

/// Manages a sequence of canvas pages. Callers paint content by accessing
/// [canvas] and [y]. Call [hasSpace] before painting; call [newPage] to
/// start a fresh page.
class _PageWriter {
  final ui.Image? _logo;
  final PatientReportBrand _brand;
  final List<Uint8List> _pages = [];

  late ui.PictureRecorder _recorder;
  late Canvas _canvas;
  int _pageIndex = 0;

  _PageWriter(this._logo, this._brand);

  Canvas get canvas => _canvas;
  double y = PatientPdfGenerator._contentStart;

  /// Whether [needed] pixels are still available on the current page.
  bool hasSpace(double needed) =>
      y + needed <= PatientPdfGenerator._maxContentY;

  /// Initialise page 1.
  Future<void> start() => newPage();

  /// Flush the current page to [_pages] and begin a new blank page.
  Future<void> newPage() async {
    if (_pageIndex > 0) await _flush();
    _pageIndex++;
    _recorder = ui.PictureRecorder();
    _canvas = Canvas(
      _recorder,
      Rect.fromLTWH(
        0,
        0,
        PatientPdfGenerator._rasterW.toDouble(),
        PatientPdfGenerator._rasterH.toDouble(),
      ),
    );
    _canvas.drawColor(Colors.white, BlendMode.src);
    _canvas.scale(
      PatientPdfGenerator._rasterScale,
      PatientPdfGenerator._rasterScale,
    );
    PatientPdfGenerator._paintPageHeader(_canvas, _logo, _pageIndex, _brand);
    y = PatientPdfGenerator._contentStart;
  }

  /// Rasterise the current page and collect it.
  Future<void> _flush() async {
    PatientPdfGenerator._paintPageFooter(_canvas, _brand);
    final picture = _recorder.endRecording();
    final img = await picture.toImage(
      PatientPdfGenerator._rasterW,
      PatientPdfGenerator._rasterH,
    );
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    picture.dispose();
    _pages.add(bytes!.buffer.asUint8List());
  }

  /// Flush the last page and return all page byte arrays.
  Future<List<Uint8List>> finish() async {
    await _flush();
    return _pages;
  }
}

// ─── Data helpers ─────────────────────────────────────────────────────────────

/// A label-value row for info grids. [height] overrides the default row height.
class _Row {
  final String label;
  final String value;
  final double? height;
  const _Row(this.label, this.value, {this.height});
}

/// A data row for tables. [statusColIndex] and [statusValue] identify the
/// column (if any) that should be rendered as a coloured status pill.
class _TRow {
  final List<String> cells;
  final int? statusColIndex;
  final String? statusValue;
  const _TRow(this.cells, {this.statusColIndex, this.statusValue});
}
