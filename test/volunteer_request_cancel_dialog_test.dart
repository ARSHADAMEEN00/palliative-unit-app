import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oruma_app/core/localization/volunteer_request_messages.dart';
import 'package:oruma_app/models/volunteer_availability_request.dart';
import 'package:oruma_app/volunteer_availability_requests_admin_page.dart';

void main() {
  group('VolunteerRequestMessages', () {
    test('provides Malayalam task-specific positive message for Home Visit', () {
      final msg = VolunteerRequestMessages.getPositiveMessage(taskType: 'home_visit');
      expect(msg.contains('ഹോം കെയർ സന്ദർശനത്തിനുള്ള'), isTrue);
      expect(msg.contains('നിലവിൽ റദ്ദാക്കുന്നു'), isTrue);
      expect(msg.contains('❤️'), isTrue);
    });

    test('provides Malayalam task-specific positive message for Social Support', () {
      final msg = VolunteerRequestMessages.getPositiveMessage(taskType: 'social_support');
      expect(msg.contains('സോഷ്യൽ സപ്പോർട്ടിനായുള്ള'), isTrue);
      expect(msg.contains('നിലവിൽ റദ്ദാക്കുന്നു'), isTrue);
    });

    test('provides English fallback when requested', () {
      final msg = VolunteerRequestMessages.getPositiveMessage(
        taskType: 'home_visit',
        locale: 'en',
      );
      expect(msg.contains('Home Care Visit'), isTrue);
    });

    test('returns neutral color for cancelled and declined statuses', () {
      expect(VolunteerRequestMessages.isNeutralStatus('cancelled'), isTrue);
      expect(VolunteerRequestMessages.isNeutralStatus('declined'), isTrue);
      expect(VolunteerRequestMessages.isNeutralStatus('accepted'), isFalse);
    });
  });

  group('VolunteerRequestCancelDialog', () {
    testWidgets('captures cancellation reason and returns it on confirm', (
      tester,
    ) async {
      String? result;
      const request = VolunteerAvailabilityRequest(
        id: 'request-101',
        requestedDate: '2026-10-24',
        contactName: 'Ameen',
        phone: '8606409313',
        address: 'osperb',
        status: 'approved',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showDialog<String>(
                    context: context,
                    builder: (_) => const VolunteerRequestCancelDialog(
                      request: request,
                      dateLabel: 'Saturday, 24 October 2026',
                    ),
                  );
                },
                child: const Text('Open Cancel Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Cancel Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel Request?'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField),
        'Scheduled unit vehicle is undergoing maintenance.',
      );

      await tester.tap(find.text('Confirm Cancel'));
      await tester.pumpAndSettle();

      expect(result, 'Scheduled unit vehicle is undergoing maintenance.');
      expect(find.text('Cancel Request?'), findsNothing);
    });

    testWidgets('allows cancellation with empty optional reason', (
      tester,
    ) async {
      String? result;
      const request = VolunteerAvailabilityRequest(
        id: 'request-102',
        requestedDate: '2026-10-24',
        contactName: 'Ameen',
        phone: '8606409313',
        address: 'osperb',
        status: 'approved',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showDialog<String>(
                    context: context,
                    builder: (_) => const VolunteerRequestCancelDialog(
                      request: request,
                      dateLabel: 'Saturday, 24 October 2026',
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm Cancel'));
      await tester.pumpAndSettle();

      expect(result, '');
    });
  });
}
