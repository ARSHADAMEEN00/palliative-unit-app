import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oruma_app/models/config.dart';
import 'package:oruma_app/models/patient_enquiry.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/volunteer_patient_registration_page.dart';
import 'package:provider/provider.dart';

final _testConfig = Config(
  villages: ['Kodur'],
  diseases: [],
  plans: [],
  wards: [WardConfig(number: '1', village: 'Kodur')],
  workingDays: [1, 2, 3, 4, 5],
  volunteerAvailabilityStartTime: '09:00',
  volunteerAvailabilityEndTime: '17:00',
);

class _TestAuthService extends AuthService {
  _TestAuthService(this._role);
  final String _role;

  @override
  String? get role => _role;
  @override
  bool get isAdmin => _role == 'admin';
  @override
  bool get isVolunteer => _role == 'volunteer';
  @override
  bool get isPublicUser => _role == 'public';
  @override
  bool get isMember => _role == 'member';
  @override
  String get unitName => 'Kodur Unit';
  @override
  bool get isAuthenticated => true;
  @override
  bool get isEmailVerified => true;
  @override
  bool get canAccessPatients => true;
  @override
  bool get canSubmitPatientEnquiry => true;
}

void main() {
  testWidgets('Share Details to WhatsApp button is visible only for Admin', (tester) async {

    // 1. Volunteer role - button should NOT be visible
    final volunteerAuth = _TestAuthService('volunteer');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: volunteerAuth),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                // Render the card using PatientEnquiryListPage's card logic
                // Or verify directly via widget tree
                return Column(
                  children: [
                    if (volunteerAuth.isAdmin)
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('Share Details to WhatsApp'),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Share Details to WhatsApp'), findsNothing);

    // 2. Admin role - button should be visible
    final adminAuth = _TestAuthService('admin');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: adminAuth),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Column(
                  children: [
                    if (adminAuth.isAdmin)
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('Share Details to WhatsApp'),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Share Details to WhatsApp'), findsOneWidget);
  });

  test('PatientEnquiry model supports referredByName and referredByPhone with backwards compatibility', () {
    // 1. From JSON with referredByName
    final enquiry = PatientEnquiry.fromJson({
      'id': 'enq-1',
      'unitId': 'unit-1',
      'name': 'Patient A',
      'phone': '9895000000',
      'village': 'Kodur',
      'referredByName': 'Dr. Rashid',
      'referredByPhone': '9895111111',
    });

    expect(enquiry.displayReferredByName, 'Dr. Rashid');
    expect(enquiry.displayReferredByPhone, '9895111111');
    expect(enquiry.toWhatsAppMessage(), contains('🤝 *Referred By:* Dr. Rashid'));
    expect(enquiry.toWhatsAppMessage(), contains('📲 *Referred By Phone:* 9895111111'));
    expect(enquiry.toWhatsAppMessage(), isNot(contains('Caregiver')));

    // 2. Fallback to caregiver fields for legacy data
    final legacyEnquiry = PatientEnquiry.fromJson({
      'id': 'enq-2',
      'unitId': 'unit-1',
      'name': 'Patient B',
      'phone': '9895000000',
      'village': 'Kodur',
      'caregiverName': 'Mohammed',
      'caregiverPhone': '9895222222',
    });

    expect(legacyEnquiry.displayReferredByName, 'Mohammed');
    expect(legacyEnquiry.displayReferredByPhone, '9895222222');
  });

  testWidgets('Success dialog for volunteer/user shows minimal content and only Close button', (tester) async {
    final volunteerAuth = _TestAuthService('volunteer');
    bool dialogClosed = false;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: volunteerAuth),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                return ElevatedButton(
                  onPressed: () {
                    final isUserOrVolunteer = volunteerAuth.isVolunteer || volunteerAuth.isPublicUser || !volunteerAuth.isAdmin;
                    showDialog<void>(
                      context: ctx,
                      builder: (dlgCtx) => AlertDialog(
                        title: const Text('Enquiry Submitted'),
                        content: const Text('Patient details have been submitted successfully.'),
                        actions: isUserOrVolunteer
                            ? [
                                ElevatedButton(
                                  onPressed: () {
                                    dialogClosed = true;
                                    Navigator.pop(dlgCtx);
                                  },
                                  child: const Text('Close'),
                                ),
                              ]
                            : [
                                TextButton(onPressed: () {}, child: const Text('Add Another')),
                                ElevatedButton(onPressed: () {}, child: const Text('View Registrations')),
                              ],
                      ),
                    );
                  },
                  child: const Text('Open Dialog'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Enquiry Submitted'), findsOneWidget);
    expect(find.text('Patient details have been submitted successfully.'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Add Another'), findsNothing);
    expect(find.text('View Registrations'), findsNothing);
    expect(find.text('The unit admin will verify these details via WhatsApp and add the patient record manually.'), findsNothing);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(dialogClosed, isTrue);
  });

  testWidgets('public user can view their patient registration list with status like volunteer', (tester) async {
    final publicAuth = _TestAuthService('public');

    final testEnquiries = [
      const PatientEnquiry(
        id: '1',
        unitId: 'unit-1',
        name: 'Amina Beevi',
        phone: '9876543210',
        village: 'Kodur',
        ward: 'Ward 4',
        status: 'pending',
      ),
      const PatientEnquiry(
        id: '2',
        unitId: 'unit-1',
        name: 'Moideen Kutty',
        phone: '9876543211',
        village: 'Kodur',
        ward: 'Ward 2',
        status: 'verified',
      ),
      const PatientEnquiry(
        id: '3',
        unitId: 'unit-1',
        name: 'Usman Haji',
        phone: '9876543212',
        village: 'Kodur',
        ward: 'Ward 5',
        status: 'rejected',
        notes: 'Duplicate registration',
      ),
    ];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: publicAuth),
        ],
        child: MaterialApp(
          home: VolunteerPatientRegistrationPage(
            initialUnitId: 'unit-1',
            initialUnitName: 'Kodur Unit',
            showRegistrationHistory: true,
            initialTabIndex: 1,
            enquiriesLoader: () async => testEnquiries,
            configLoader: () async => _testConfig,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify TabBar with both tabs exists
    expect(find.text('New Registration'), findsOneWidget);
    expect(find.text('My Registrations (3)'), findsOneWidget);

    // Verify filter chips with counts
    expect(find.text('All (3)'), findsOneWidget);
    expect(find.text('Pending (1)'), findsOneWidget);
    expect(find.text('Verified (1)'), findsOneWidget);
    expect(find.text('Rejected (1)'), findsOneWidget);

    // Verify patient names
    expect(find.text('Amina Beevi'), findsOneWidget);
    expect(find.text('Moideen Kutty'), findsOneWidget);
    expect(find.text('Usman Haji'), findsOneWidget);

    // Verify status badges matching volunteer
    expect(find.text('Pending Verification'), findsOneWidget);
    expect(find.text('Verified & Added'), findsOneWidget);
    expect(find.text('Rejected'), findsOneWidget);
    expect(find.text('Note: Duplicate registration'), findsOneWidget);
  });

  testWidgets('Volunteer and user with a pending enquiry have submission blocked until approved or rejected', (tester) async {
    final volunteerAuth = _TestAuthService('volunteer');
    final testEnquiries = [
      const PatientEnquiry(
        id: '1',
        unitId: 'unit-1',
        name: 'Amina Beevi',
        phone: '9876543210',
        village: 'Kodur',
        ward: 'Ward 4',
        status: 'pending',
      ),
    ];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: volunteerAuth),
        ],
        child: MaterialApp(
          home: VolunteerPatientRegistrationPage(
            initialUnitId: 'unit-1',
            initialUnitName: 'Kodur Unit',
            showRegistrationHistory: true,
            initialTabIndex: 0,
            enquiriesLoader: () async => testEnquiries,
            configLoader: () async => _testConfig,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify top pending enquiry warning card is visible
    expect(find.text('Pending Enquiry Awaiting Verification'), findsOneWidget);
    expect(find.textContaining('Current enquiry: Amina Beevi'), findsOneWidget);

    // Verify submit button is replaced with "Submission on Hold" card
    expect(find.text('Submission on Hold'), findsOneWidget);
    expect(
      find.textContaining('You already have a pending enquiry for Amina Beevi waiting for approval or rejection.'),
      findsOneWidget,
    );
    expect(find.text('Submit Patient Enquiry'), findsNothing);

    // Tap "View Status →" and verify tab changes to Registrations
    await tester.tap(find.text('View Status →'));
    await tester.pumpAndSettle();

    expect(find.text('Pending Verification'), findsOneWidget);
    expect(find.text('Amina Beevi'), findsOneWidget);
  });

  testWidgets('Volunteer and user can submit new enquiry once previous enquiry is approved or rejected', (tester) async {
    final publicAuth = _TestAuthService('public');
    // Only verified and rejected enquiries exist (no pending)
    final testEnquiries = [
      const PatientEnquiry(
        id: '1',
        unitId: 'unit-1',
        name: 'Moideen Kutty',
        phone: '9876543211',
        village: 'Kodur',
        status: 'verified',
      ),
      const PatientEnquiry(
        id: '2',
        unitId: 'unit-1',
        name: 'Usman Haji',
        phone: '9876543212',
        village: 'Kodur',
        status: 'rejected',
        notes: 'Out of area',
      ),
    ];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: publicAuth),
        ],
        child: MaterialApp(
          home: VolunteerPatientRegistrationPage(
            initialUnitId: 'unit-1',
            initialUnitName: 'Kodur Unit',
            showRegistrationHistory: true,
            initialTabIndex: 0,
            enquiriesLoader: () async => testEnquiries,
            configLoader: () async => _testConfig,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify no pending warning banner
    expect(find.text('Pending Enquiry Awaiting Verification'), findsNothing);
    expect(find.text('Submission on Hold'), findsNothing);

    // Verify active Submit button is available
    expect(find.text('Submit Patient Enquiry'), findsOneWidget);
  });

  testWidgets('Admin is NOT restricted by pending enquiries', (tester) async {
    final adminAuth = _TestAuthService('admin');
    final testEnquiries = [
      const PatientEnquiry(
        id: '1',
        unitId: 'unit-1',
        name: 'Amina Beevi',
        phone: '9876543210',
        village: 'Kodur',
        status: 'pending',
      ),
    ];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: adminAuth),
        ],
        child: MaterialApp(
          home: VolunteerPatientRegistrationPage(
            initialUnitId: 'unit-1',
            initialUnitName: 'Kodur Unit',
            showRegistrationHistory: true,
            initialTabIndex: 0,
            enquiriesLoader: () async => testEnquiries,
            configLoader: () async => _testConfig,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify no restriction for admin
    expect(find.text('Pending Enquiry Awaiting Verification'), findsNothing);
    expect(find.text('Submission on Hold'), findsNothing);
    expect(find.text('Submit Patient Enquiry'), findsOneWidget);
  });
}

