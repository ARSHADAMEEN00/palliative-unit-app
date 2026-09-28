import 'package:oruma_app/features/reports/models/report_models.dart';
import 'package:oruma_app/services/api_config.dart';
import 'package:oruma_app/services/api_service.dart';

class ReportService {
  const ReportService._();

  static Future<ReportResult> fetch(
    ReportType type,
    ReportFilters filters, {
    bool export = false,
  }) async {
    if (!export) return _fetchPage(type, filters.toQuery());

    final first = await _fetchPage(
      type,
      filters.copyWith(page: 1, limit: 5000).toQuery(),
    );
    if (first.pagination.totalPages <= 1) return first;

    final rows = <Map<String, dynamic>>[...first.rows];
    for (var page = 2; page <= first.pagination.totalPages; page += 1) {
      final next = await _fetchPage(
        type,
        filters.copyWith(page: page, limit: 5000).toQuery(),
      );
      rows.addAll(next.rows);
    }

    return ReportResult(
      type: first.type,
      summary: first.summary,
      rows: rows,
      pagination: ReportPagination(
        page: 1,
        limit: rows.length,
        totalRows: rows.length,
        totalPages: 1,
      ),
      appliedFilters: first.appliedFilters,
      generatedAt: first.generatedAt,
    );
  }

  static Future<ReportResult> _fetchPage(
    ReportType type,
    Map<String, String> query,
  ) async {
    final uri = Uri.parse(
      '${ApiConfig.reportsEndpoint}/${type.apiSlug}',
    ).replace(queryParameters: query);
    final result = await ApiService.get<Map<String, dynamic>>(uri.toString());
    if (result.isSuccess && result.data != null) {
      return ReportResult.fromJson(result.data!, type);
    }
    throw Exception(result.error ?? 'Failed to load ${type.label} report');
  }
}
