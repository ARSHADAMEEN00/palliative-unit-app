import 'package:flutter_test/flutter_test.dart';
import 'package:oruma_app/models/equipment_supply.dart';

void main() {
  test('equipment supply preserves patientId through JSON conversion', () {
    final supply = EquipmentSupply.fromJson({
      '_id': 'supply-1',
      'equipmentId': 'equipment-1',
      'equipmentUniqueId': 'WC-001',
      'equipmentName': 'Wheelchair',
      'patientId': {'_id': 'patient-1', 'name': 'Patient'},
      'patientName': 'PATIENT',
      'supplyDate': '2026-11-01T12:00:00.000Z',
      'status': 'active',
    });

    expect(supply.patientId, 'patient-1');
    expect(supply.toJson()['patientId'], 'patient-1');
  });

  test('legacy equipment supply remains valid without patientId', () {
    final supply = EquipmentSupply.fromJson({
      '_id': 'legacy-supply',
      'equipmentId': 'equipment-1',
      'equipmentUniqueId': 'WC-001',
      'equipmentName': 'Wheelchair',
      'patientName': 'LEGACY PATIENT SNAPSHOT',
      'supplyDate': '2026-11-01T12:00:00.000Z',
      'status': 'active',
    });

    expect(supply.patientId, isNull);
    expect(supply.patientName, 'LEGACY PATIENT SNAPSHOT');
  });
}
