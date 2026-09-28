import 'package:flutter_test/flutter_test.dart';
import 'package:oruma_app/features/reports/models/report_models.dart';
import 'package:oruma_app/features/reports/pdf/report_pdf_generator.dart';
import 'package:oruma_app/features/reports/presentation/report_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('report type API slugs remain stable', () {
    expect(ReportType.medicineStock.apiSlug, 'medicine-stock');
    expect(ReportType.medicineSupplies.apiSlug, 'medicine-supplies');
    expect(ReportType.equipmentStock.apiSlug, 'equipment-stock');
    expect(
      ReportType.equipmentDamageHistory.apiSlug,
      'equipment-damage-history',
    );
    expect(ReportType.equipmentSupplies.apiSlug, 'equipment-supplies');
    expect(ReportType.socialSupport.apiSlug, 'social-support');
  });

  test('report filters serialize pagination, dates, sorting and extras', () {
    final filters = ReportFilters(
      search: 'morphine',
      from: DateTime(2026, 9, 1),
      to: DateTime(2026, 9, 30),
      sortBy: 'expiryDate',
      sortOrder: 'asc',
      page: 3,
      extra: const {'stockStatus': 'low_stock', 'expiryStatus': ''},
    );

    expect(filters.toQuery(), {
      'search': 'morphine',
      'from': '2026-09-01',
      'to': '2026-09-30',
      'sortBy': 'expiryDate',
      'sortOrder': 'asc',
      'page': '3',
      'limit': '50',
      'stockStatus': 'low_stock',
    });
    expect(filters.toQuery(export: true)['page'], '1');
    expect(filters.toQuery(export: true)['limit'], '5000');
  });

  test('report result parses summaries and pagination safely', () {
    final result = ReportResult.fromJson({
      'summary': {'records': 2, 'netQuantity': 7.5},
      'rows': [
        {'id': 'one'},
        {'id': 'two'},
      ],
      'pagination': {'page': 1, 'limit': 50, 'totalRows': 2, 'totalPages': 1},
      'appliedFilters': {'status': 'given'},
      'generatedAt': '2026-09-28T08:00:00.000Z',
    }, ReportType.medicineSupplies);

    expect(result.summary['records'], 2);
    expect(result.summary['netQuantity'], 7.5);
    expect(result.rows, hasLength(2));
    expect(result.pagination.totalRows, 2);
    expect(result.appliedFilters['status'], 'given');
  });

  test('report PDF generator creates a valid document', () async {
    final report = ReportResult.fromJson({
      'summary': {'total': 1, 'available': 1},
      'rows': [
        {
          'uniqueId': 'WC-001',
          'equipmentName': 'Wheelchair',
          'status': 'available',
          'storagePlace': 'Main store',
          'purchasedFrom': 'Supplier',
          'purchaseDate': '2026-09-01T00:00:00.000Z',
          'place': 'Town',
          'createdBy': 'Admin',
        },
      ],
      'pagination': {'page': 1, 'limit': 50, 'totalRows': 1, 'totalPages': 1},
      'appliedFilters': {},
      'generatedAt': '2026-09-28T08:00:00.000Z',
    }, ReportType.equipmentStock);

    final bytes = await ReportPdfGenerator.generate(
      definition: reportDefinitions[ReportType.equipmentStock]!,
      report: report,
      filters: const ReportFilters(),
      unitName: 'Test Palliative Unit',
      unitLocation: 'Kozhikode',
      generatedBy: 'Admin',
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
