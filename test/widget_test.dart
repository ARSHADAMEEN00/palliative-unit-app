import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oruma_app/models/patient.dart';
import 'package:oruma_app/medicine_list_page.dart';
import 'package:oruma_app/patient_details_page.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('patient details shows the phase 2 sections', (tester) async {
    const patient = Patient(
      name: 'RASIYA,KALLINGAL',
      relation: 'Daughter',
      gender: 'Female',
      address: 'Kallingal House',
      phone: '9744407173',
      phone2: '9961104085',
      age: 54,
      place: 'Village',
      village: 'Village',
      ward: '12',
      disease: ['HTN', 'DM'],
      plan: 'Monthly care',
      registerId: '23/26',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthService(),
        child: const MaterialApp(home: PatientDetailsPage(patient: patient)),
      ),
    );
    await tester.pump();

    expect(find.text('Patient Details'), findsOneWidget);
    expect(find.text('Rasiya, Kallingal'), findsWidgets);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Medical'), findsOneWidget);
    expect(find.text('Home Visits (0)'), findsOneWidget);
    expect(find.text('Equipment (0)'), findsOneWidget);
    expect(find.text('Assessment (0)'), findsOneWidget);
    expect(find.text('Medicines (0)'), findsOneWidget);

    await tester.drag(find.byType(NestedScrollView), const Offset(0, -220));
    await tester.pumpAndSettle();
    expect(find.text('Medical'), findsOneWidget);

    await tester.tap(find.text('Medical'));
    await tester.pumpAndSettle();
    expect(find.text('Medical details'), findsOneWidget);
    expect(find.text('Monthly care'), findsOneWidget);

    await tester.tap(find.text('Home Visits (0)'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load home visits'), findsOneWidget);
  });

  testWidgets('medicine form reveals optional details progressively', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MedicineFormPage()));

    expect(find.text('Medicine code'), findsOneWidget);
    expect(find.text('Generic / scientific name'), findsOneWidget);
    expect(find.text('Dosage strength'), findsOneWidget);
    expect(find.text('Net Content'), findsOneWidget);
    expect(find.text('Additional details'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -480));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More details'));
    await tester.pumpAndSettle();

    expect(find.text('Additional details'), findsOneWidget);
    expect(find.text('Barcode'), findsOneWidget);
    expect(find.text('Brand names'), findsOneWidget);
  });
}
