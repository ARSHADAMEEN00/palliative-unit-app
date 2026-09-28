import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oruma_app/widgets/damaged_seal_stamp.dart';

void main() {
  testWidgets('DamagedSealStamp renders correctly with and without date', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DamagedSealStamp(
              damagedAt: DateTime(2026, 9, 28),
              size: 110,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(DamagedSealStamp), findsOneWidget);
    expect(find.bySemanticsLabel('Damaged equipment'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: DamagedSealStamp(damagedAt: null, size: 110)),
        ),
      ),
    );

    expect(find.byType(DamagedSealStamp), findsOneWidget);
  });
}
