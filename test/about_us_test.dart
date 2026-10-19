import 'package:flutter_test/flutter_test.dart';
import 'package:oruma_app/models/about_us.dart';

void main() {
  group('AboutUs Models Test', () {
    test('AboutUsData parses JSON with tags correctly', () {
      final json = {
        'has_about_us': true,
        'title': 'മനസ്സിനെ കേൾക്കാം, കരുതലോടെ ചേർത്തുപിടിക്കാം',
        'content': 'ഈ കഴിഞ്ഞ ഒരു വർഷത്തിൽ 120-ലധികം രോഗികളെ പരിചരിച്ചു.',
        'raw_content':
            'ഈ കഴിഞ്ഞ ഒരു വർഷത്തിൽ {{patient_count}}-ലധികം രോഗികളെ പരിചരിച്ചു.',
        'unit_name': 'ഒരുമ പാലിയേറ്റീവ് കെയർ',
        'updated_at': '2026-10-19T10:00:00.000Z',
        'updated_by_name': 'Admin User',
        'available_tags': [
          {
            'tag': '{{patient_count}}',
            'name': 'patient_count',
            'label': 'Total Patients',
            'description': 'Total registered patients',
            'currentValue': '120',
          },
          {
            'tag': '{{unit_name}}',
            'name': 'unit_name',
            'label': 'Unit Name',
            'description': 'Name of the palliative unit',
            'currentValue': 'ഒരുമ പാലിയേറ്റീവ് കെയർ',
          },
        ],
        'tag_values': {
          'patient_count': '120',
          'unit_name': 'ഒരുമ പാലിയേറ്റീവ് കെയർ',
        },
      };

      final data = AboutUsData.fromJson(json);

      expect(data.hasAboutUs, isTrue);
      expect(
        data.title,
        equals('മനസ്സിനെ കേൾക്കാം, കരുതലോടെ ചേർത്തുപിടിക്കാം'),
      );
      expect(data.content, contains('120-ലധികം'));
      expect(data.rawContent, contains('{{patient_count}}'));
      expect(data.unitName, equals('ഒരുമ പാലിയേറ്റീവ് കെയർ'));
      expect(data.updatedByName, equals('Admin User'));
      expect(data.availableTags.length, equals(2));
      expect(data.availableTags.first.tag, equals('{{patient_count}}'));
      expect(data.availableTags.first.currentValue, equals('120'));
      expect(data.tagValues['patient_count'], equals('120'));
    });

    test('AboutUsData handles empty state properly', () {
      final json = {'has_about_us': false, 'content': '', 'raw_content': ''};

      final data = AboutUsData.fromJson(json);
      expect(data.hasAboutUs, isFalse);
      expect(data.title, AboutUsData.defaultTitle);
      expect(data.content, isEmpty);
      expect(data.rawContent, isEmpty);
    });
  });
}
