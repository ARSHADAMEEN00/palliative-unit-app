import 'package:flutter_test/flutter_test.dart';
import 'package:oruma_app/models/equipment_supply.dart';
import 'package:oruma_app/models/medicine_supply.dart';

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
    expect(supply.localBody, isNull);
    expect(supply.ward, isNull);
  });

  test('equipment supply parses its historical local body and ward', () {
    final supply = EquipmentSupply.fromJson({
      '_id': 'supply-2',
      'equipmentId': 'equipment-1',
      'equipmentUniqueId': 'WC-001',
      'equipmentName': 'Wheelchair',
      'localBody': 'Municipality A',
      'wardId': {
        '_id': 'ward-1',
        'name': 'Ward 1',
        'localBody': 'Municipality A',
      },
      'supplyDate': '2026-11-01T12:00:00.000Z',
      'status': 'active',
    });

    expect(supply.wardId, 'ward-1');
    expect(supply.localBody, 'Municipality A');
    expect(supply.ward?.label, 'Ward 1');
  });

  test('medicine supply parses persisted location snapshots', () {
    final supply = MedicineSupply.fromJson({
      '_id': 'medicine-supply-1',
      'patientId': {'_id': 'patient-1', 'name': 'Patient'},
      'medicineId': {'_id': 'medicine-1', 'name': 'Tablet'},
      'givenByStaff': {'_id': 'staff-1', 'name': 'Nurse'},
      'givenAt': '2026-11-01T12:00:00.000Z',
      'qtyGiven': 10,
      'localBody': 'Municipality A',
      'wardId': {
        '_id': 'ward-1',
        'name': 'Ward 1',
        'localBody': 'Municipality A',
      },
    });

    expect(supply.wardId, 'ward-1');
    expect(supply.localBody, 'Municipality A');
    expect(supply.ward?.fullLabel, 'Municipality A • Ward 1');
  });
}
