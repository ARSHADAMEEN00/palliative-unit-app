import 'package:flutter_test/flutter_test.dart';
import 'package:oruma_app/models/equipment.dart';

void main() {
  test('equipment damage fields and status are parsed from the API', () {
    final equipment = Equipment.fromJson({
      '_id': 'equipment-1',
      'uniqueId': 'WC-001',
      'serialNo': 'WC',
      'name': 'Wheelchair',
      'quantity': 1,
      'purchasedFrom': 'Supplier',
      'place': 'Town',
      'phone': '9999999999',
      'status': 'maintenance',
      'damageReason': 'Rear wheel is bent',
      'damagedAt': '2026-09-28T04:30:00.000Z',
      'damageHistory': [
        {
          '_id': 'incident-1',
          'damageReason': 'Rear wheel is bent',
          'damagedAt': '2026-08-01T00:00:00.000Z',
          'repairedAt': '2026-08-04T00:00:00.000Z',
          'repairedBy': {'name': 'Repair Admin'},
        },
        {
          '_id': 'incident-2',
          'damageReason': 'Rear wheel is bent again',
          'damagedAt': '2026-09-28T04:30:00.000Z',
        },
      ],
    });

    expect(equipment.isDamaged, isTrue);
    expect(equipment.isAvailable, isFalse);
    expect(equipment.statusLabel, 'Damaged');
    expect(equipment.damageReason, 'Rear wheel is bent');
    expect(equipment.damagedAt, DateTime.parse('2026-09-28T04:30:00.000Z'));
    expect(equipment.damageHistory, hasLength(2));
    expect(equipment.damageHistory.first.isRepaired, isTrue);
    expect(equipment.damageHistory.first.repairedBy, 'Repair Admin');
    expect(equipment.damageHistory.last.isRepaired, isFalse);
  });

  test('available equipment is not marked as damaged', () {
    final equipment = Equipment.fromJson({
      'uniqueId': 'WC-002',
      'serialNo': 'WC',
      'name': 'Wheelchair',
      'quantity': 1,
      'purchasedFrom': 'Supplier',
      'place': 'Town',
      'phone': '9999999999',
      'status': 'available',
    });

    expect(equipment.isDamaged, isFalse);
    expect(equipment.isAvailable, isTrue);
    expect(equipment.statusLabel, 'Available');
  });
}
