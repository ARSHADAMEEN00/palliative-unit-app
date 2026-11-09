import 'package:flutter_test/flutter_test.dart';
import 'package:oruma_app/models/equipment_supply.dart';
import 'package:oruma_app/models/patient.dart';
import 'package:oruma_app/models/patient_transfer.dart';

void main() {
  test('transfer request parses populated summaries and review controls', () {
    final request = PatientTransferRequest.fromJson({
      'id': 'transfer-1',
      'patientId': 'patient-1',
      'sourceUnitId': 'unit-a',
      'destinationUnitId': 'unit-b',
      'status': 'PENDING',
      'reason': 'Relocation',
      'transferDate': '2026-11-07T00:00:00.000Z',
      'handoverSummary': 'Continue symptom monitoring.',
      'patient': {'id': 'patient-1', 'name': 'Amina', 'registerId': 'A-12'},
      'sourceUnit': {'id': 'unit-a', 'name': 'North Unit'},
      'destinationUnit': {'id': 'unit-b', 'name': 'South Unit'},
      'verificationChecklist': [
        {
          'key': 'identity_verified',
          'label': 'Identity verified',
          'required': true,
          'checked': false,
        },
      ],
      'duplicateCandidates': [
        {
          'patientId': 'possible-match',
          'name': 'Amina',
          'phoneMatch': true,
          'nameAgeMatch': false,
        },
      ],
    });

    expect(request.isPending, isTrue);
    expect(request.patient?.name, 'Amina');
    expect(request.sourceUnit?.name, 'North Unit');
    expect(request.destinationUnit?.name, 'South Unit');
    expect(request.verificationChecklist.single.required, isTrue);
    expect(request.hasPossibleDuplicate, isTrue);
  });

  test('patient exposes pending lock and unit registration history', () {
    final patient = Patient.fromJson({
      'id': 'patient-1',
      'name': 'Amina',
      'relation': 'Daughter',
      'gender': 'Female',
      'address': 'Home',
      'phone': '123',
      'age': 70,
      'place': 'Town',
      'village': 'Village',
      'plan': 'Monthly',
      'transferStatus': 'TRANSFER_PENDING',
      'currentTransferRequestId': 'transfer-1',
      'unitRegistrationHistory': [
        {
          'unitId': 'unit-a',
          'registerId': 'A-12',
          'activeFrom': '2025-01-01T00:00:00.000Z',
        },
      ],
    });

    expect(patient.transferStatus, 'TRANSFER_PENDING');
    expect(patient.currentTransferRequestId, 'transfer-1');
    expect(patient.unitRegistrationHistory.single.registerId, 'A-12');
    expect(patient.unitRegistrationHistory.single.activeFrom, isNotNull);
  });

  test('destination equipment custody preserves source ownership metadata', () {
    final supply = EquipmentSupply.fromJson({
      'id': 'custody-1',
      'equipmentId': 'asset-1',
      'equipmentUniqueId': 'BED-9',
      'equipmentName': 'Hospital bed',
      'supplyDate': '2026-10-01T00:00:00.000Z',
      'status': 'external_custody',
      'isExternalCustody': true,
      'ownerUnitId': 'unit-a',
      'ownerUnitName': 'North Unit',
      'custodyStatus': 'pending_reassignment_or_return',
    });

    expect(supply.isExternalCustody, isTrue);
    expect(supply.ownerUnitName, 'North Unit');
    expect(supply.status, 'external_custody');
  });
}
