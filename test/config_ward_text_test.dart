import 'package:flutter_test/flutter_test.dart';
import 'package:oruma_app/models/config.dart';
import 'package:oruma_app/models/ward.dart';

void main() {
  test('ward normalization preserves text and alphanumeric names', () {
    expect(normalizeWardNumberValue('North Ward'), 'North Ward');
    expect(normalizeWardNumberValue('Ward 12A'), '12A');
    expect(formatWardLabel('Ward 12A'), 'Ward 12A');
    expect(normalizeWardNumberValue('007'), '7');
  });

  test('ward config JSON preserves a text ward name', () {
    final ward = WardConfig.fromJson({
      'number': 'Division East 2',
      'village': 'Koyilandy Municipality',
    });

    expect(ward.number, 'Division East 2');
    expect(ward.toJson()['number'], 'Division East 2');
    expect(formatWardLabel('12'), 'Ward 12');
    expect(formatWardLabel('Ward A'), 'Ward A');
    expect(formatWardLabel('1 : Pathirikkad'), 'Ward 1 : Pathirikkad');
    expect(formatWardLabel('Pathirikkad'), 'Ward Pathirikkad');
  });

  test('comma-separated ward input creates distinct ward values', () {
    expect(
      parseWardInput(
        '1 : Pathirikkad, 2 : Maraloor, 3 : Kodakkattumuri, '
        '2 : maraloor, ',
      ),
      ['1 : Pathirikkad', '2 : Maraloor', '3 : Kodakkattumuri'],
    );
  });

  test('operational ward retains its LSG local-body context', () {
    final ward = Ward.fromJson({
      'id': 'ward-1',
      'name': 'Ward 1 : Pathirikkad',
      'localBody': 'Koyilandy Municipality',
      'lsgWardValue': '1 : Pathirikkad',
      'managedByLsg': true,
    });

    expect(ward.localBody, 'Koyilandy Municipality');
    expect(ward.lsgWardValue, '1 : Pathirikkad');
    expect(ward.managedByLsg, isTrue);
    expect(ward.fullLabel, 'Koyilandy Municipality • Ward 1 : Pathirikkad');
  });
}
