enum ReportType {
  medicineStock,
  medicineSupplies,
  equipmentStock,
  equipmentDamageHistory,
  equipmentSupplies,
  socialSupport,
}

extension ReportTypeDetails on ReportType {
  String get apiSlug => switch (this) {
    ReportType.medicineStock => 'medicine-stock',
    ReportType.medicineSupplies => 'medicine-supplies',
    ReportType.equipmentStock => 'equipment-stock',
    ReportType.equipmentDamageHistory => 'equipment-damage-history',
    ReportType.equipmentSupplies => 'equipment-supplies',
    ReportType.socialSupport => 'social-support',
  };

  String get label => switch (this) {
    ReportType.medicineStock => 'Medicine Stock',
    ReportType.medicineSupplies => 'Medicine Supply',
    ReportType.equipmentStock => 'Equipment Stock',
    ReportType.equipmentDamageHistory => 'Damage History',
    ReportType.equipmentSupplies => 'Equipment Supply',
    ReportType.socialSupport => 'Social Support',
  };
}

class ReportPagination {
  const ReportPagination({
    required this.page,
    required this.limit,
    required this.totalRows,
    required this.totalPages,
  });

  final int page;
  final int limit;
  final int totalRows;
  final int totalPages;

  factory ReportPagination.fromJson(Map<String, dynamic> json) {
    return ReportPagination(
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 50,
      totalRows: (json['totalRows'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

class ReportResult {
  const ReportResult({
    required this.type,
    required this.summary,
    required this.rows,
    required this.pagination,
    required this.appliedFilters,
    required this.generatedAt,
  });

  final ReportType type;
  final Map<String, num> summary;
  final List<Map<String, dynamic>> rows;
  final ReportPagination pagination;
  final Map<String, dynamic> appliedFilters;
  final DateTime generatedAt;

  factory ReportResult.fromJson(Map<String, dynamic> json, ReportType type) {
    final rawSummary = json['summary'] as Map? ?? const {};
    return ReportResult(
      type: type,
      summary: rawSummary.map(
        (key, value) => MapEntry(key.toString(), value is num ? value : 0),
      ),
      rows: (json['rows'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(),
      pagination: ReportPagination.fromJson(
        Map<String, dynamic>.from(json['pagination'] as Map? ?? const {}),
      ),
      appliedFilters: Map<String, dynamic>.from(
        json['appliedFilters'] as Map? ?? const {},
      ),
      generatedAt:
          DateTime.tryParse(json['generatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class ReportFilters {
  const ReportFilters({
    this.search = '',
    this.from,
    this.to,
    this.sortBy = '',
    this.sortOrder = 'desc',
    this.page = 1,
    this.limit = 50,
    this.extra = const {},
  });

  final String search;
  final DateTime? from;
  final DateTime? to;
  final String sortBy;
  final String sortOrder;
  final int page;
  final int limit;
  final Map<String, String> extra;

  factory ReportFilters.currentMonth() {
    final now = DateTime.now();
    return ReportFilters(
      from: DateTime(now.year, now.month),
      to: DateTime(now.year, now.month + 1, 0),
    );
  }

  ReportFilters copyWith({
    String? search,
    DateTime? from,
    DateTime? to,
    bool clearFrom = false,
    bool clearTo = false,
    String? sortBy,
    String? sortOrder,
    int? page,
    int? limit,
    Map<String, String>? extra,
  }) {
    return ReportFilters(
      search: search ?? this.search,
      from: clearFrom ? null : from ?? this.from,
      to: clearTo ? null : to ?? this.to,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      extra: extra ?? this.extra,
    );
  }

  Map<String, String> toQuery({bool export = false}) {
    final query = <String, String>{
      if (search.trim().isNotEmpty) 'search': search.trim(),
      if (from != null) 'from': _date(from!),
      if (to != null) 'to': _date(to!),
      if (sortBy.isNotEmpty) 'sortBy': sortBy,
      'sortOrder': sortOrder,
      'page': export ? '1' : page.toString(),
      'limit': export ? '5000' : limit.toString(),
    };
    for (final entry in extra.entries) {
      if (entry.value.trim().isNotEmpty) query[entry.key] = entry.value.trim();
    }
    return query;
  }

  int get activeFilterCount {
    return (from == null ? 0 : 1) +
        (to == null ? 0 : 1) +
        extra.values.where((value) => value.trim().isNotEmpty).length;
  }

  static String _date(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
