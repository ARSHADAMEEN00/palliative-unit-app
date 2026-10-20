import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oruma_app/models/volunteer_availability_request.dart';
import 'package:oruma_app/volunteer_availability_requests_admin_page.dart';

void main() {
  testWidgets('approval dialog closes cleanly after entering a note', (
    tester,
  ) async {
    String? result;
    const request = VolunteerAvailabilityRequest(
      id: 'request-1',
      requestedDate: '2026-10-22',
      contactName: 'Asha',
      phone: '9999999999',
      address: 'Centre, Town',
      status: 'pending',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showDialog<String>(
                  context: context,
                  builder: (_) => const VolunteerAvailabilityReviewDialog(
                    request: request,
                    approving: true,
                    dateLabel: 'Thursday, 22 October 2026',
                  ),
                );
              },
              child: const Text('Open review'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open review'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      'Please visit the unit on the day.',
    );
    await tester.tap(find.text('Confirm approval'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(result, 'Please visit the unit on the day.');
    expect(find.text('Approve availability?'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
