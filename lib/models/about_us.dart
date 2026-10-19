class AboutUsTag {
  final String tag;
  final String name;
  final String label;
  final String description;
  final String currentValue;

  const AboutUsTag({
    required this.tag,
    required this.name,
    required this.label,
    required this.description,
    required this.currentValue,
  });

  static const List<AboutUsTag> defaultTags = [
    AboutUsTag(
      tag: '{{unit_name}}',
      name: 'unit_name',
      label: 'Unit Name',
      description: 'Name of the palliative unit',
      currentValue: 'Unit Name',
    ),
    AboutUsTag(
      tag: '{{patient_count}}',
      name: 'patient_count',
      label: 'Patient Count',
      description: 'Total registered patients',
      currentValue: '120',
    ),
    AboutUsTag(
      tag: '{{active_patient_count}}',
      name: 'active_patient_count',
      label: 'Active Patients',
      description: 'Patients currently under care',
      currentValue: '95',
    ),
    AboutUsTag(
      tag: '{{volunteer_count}}',
      name: 'volunteer_count',
      label: 'Volunteer Count',
      description: 'Total volunteers',
      currentValue: '48',
    ),
    AboutUsTag(
      tag: '{{visit_count}}',
      name: 'visit_count',
      label: 'Total Visits',
      description: 'Total home visits completed',
      currentValue: '350',
    ),
    AboutUsTag(
      tag: '{{visits_this_month}}',
      name: 'visits_this_month',
      label: 'Visits This Month',
      description: 'Home visits in the current month',
      currentValue: '28',
    ),
    AboutUsTag(
      tag: '{{start_date}}',
      name: 'start_date',
      label: 'Start Date',
      description: 'Date the unit started',
      currentValue: '1 August 2025',
    ),
    AboutUsTag(
      tag: '{{years_of_service}}',
      name: 'years_of_service',
      label: 'Years of Service',
      description: 'Years since the unit started',
      currentValue: '1',
    ),
    AboutUsTag(
      tag: '{{equipment_count}}',
      name: 'equipment_count',
      label: 'Equipment Items',
      description: 'Medical equipment items',
      currentValue: '65',
    ),
    AboutUsTag(
      tag: '{{location}}',
      name: 'location',
      label: 'Location',
      description: 'Unit location / panchayat',
      currentValue: 'Location',
    ),
  ];

  factory AboutUsTag.fromJson(Map<String, dynamic> json) {
    return AboutUsTag(
      tag: json['tag']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      currentValue:
          json['currentValue']?.toString() ??
          json['sampleValue']?.toString() ??
          '',
    );
  }

  Map<String, dynamic> toJson() => {
    'tag': tag,
    'name': name,
    'label': label,
    'description': description,
    'currentValue': currentValue,
  };
}

class AboutUsData {
  static const defaultTitle = 'മനസ്സിനെ കേൾക്കാം, കരുതലോടെ ചേർത്തുപിടിക്കാം';

  final bool hasAboutUs;
  final String title;
  final String content;
  final String rawContent;
  final String unitName;
  final DateTime? updatedAt;
  final String? updatedByName;
  final List<AboutUsTag> availableTags;
  final Map<String, String> tagValues;

  const AboutUsData({
    required this.hasAboutUs,
    required this.title,
    required this.content,
    required this.rawContent,
    required this.unitName,
    this.updatedAt,
    this.updatedByName,
    this.availableTags = const [],
    this.tagValues = const {},
  });

  factory AboutUsData.fromJson(Map<String, dynamic> json) {
    DateTime? updatedDate;
    if (json['updated_at'] != null) {
      updatedDate = DateTime.tryParse(json['updated_at'].toString());
    }

    final tagsList = <AboutUsTag>[];
    if (json['available_tags'] is List) {
      for (final item in json['available_tags']) {
        if (item is Map<String, dynamic>) {
          tagsList.add(AboutUsTag.fromJson(item));
        } else if (item is Map) {
          tagsList.add(AboutUsTag.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    final valuesMap = <String, String>{};
    if (json['tag_values'] is Map) {
      json['tag_values'].forEach((k, v) {
        valuesMap[k.toString()] = v?.toString() ?? '';
      });
    }

    return AboutUsData(
      hasAboutUs: json['has_about_us'] == true || json['hasAboutUs'] == true,
      title: json['title']?.toString().trim().isNotEmpty == true
          ? json['title'].toString().trim()
          : defaultTitle,
      content: json['content']?.toString() ?? json['preview']?.toString() ?? '',
      rawContent:
          json['raw_content']?.toString() ?? json['content']?.toString() ?? '',
      unitName: json['unit_name']?.toString() ?? '',
      updatedAt: updatedDate,
      updatedByName: json['updated_by_name']?.toString(),
      availableTags: tagsList,
      tagValues: valuesMap,
    );
  }

  Map<String, dynamic> toJson() => {
    'has_about_us': hasAboutUs,
    'title': title,
    'content': content,
    'raw_content': rawContent,
    'unit_name': unitName,
    'updated_at': updatedAt?.toIso8601String(),
    'updated_by_name': updatedByName,
  };
}
