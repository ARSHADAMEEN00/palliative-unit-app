import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oruma_app/core/theme/app_theme.dart';
import 'package:oruma_app/homscreen.dart';
import 'package:oruma_app/models/about_us.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:provider/provider.dart';

class _HomePreviewAuthService extends AuthService {
  _HomePreviewAuthService(
    this.previewRole, {
    this.volunteerApproved = true,
    this.aboutUsAvailable = true,
    this.canAccessEquipmentOverride,
    this.canAccessEquipmentDistributionOverride,
    this.canAccessMedicineSupplyOverride,
    this.canAccessMedicineMasterOverride,
    this.canAccessNHCOverride,
  });

  final String previewRole;
  final bool volunteerApproved;
  final bool aboutUsAvailable;
  final bool? canAccessEquipmentOverride;
  final bool? canAccessEquipmentDistributionOverride;
  final bool? canAccessMedicineSupplyOverride;
  final bool? canAccessMedicineMasterOverride;
  final bool? canAccessNHCOverride;

  @override
  String? get role => previewRole;
  @override
  bool get isAdmin => previewRole == 'admin';
  @override
  bool get isStaff => previewRole == 'staff';
  @override
  bool get isMember => previewRole == 'member';
  @override
  bool get isVolunteer => previewRole == 'volunteer';
  @override
  bool get isVolunteerApproved => volunteerApproved;
  @override
  bool get isVolunteerPending => isVolunteer && !volunteerApproved;
  @override
  bool get isAccessBlocked => false;
  @override
  bool get isFirstLogin => false;
  @override
  bool get isTrialUnit => false;
  @override
  bool get hasAboutUs => aboutUsAvailable;
  @override
  String? get unitSupportQr => 'https://example.com/support-qr.png';
  @override
  bool get canCreate => !isVolunteer;
  @override
  bool get canAccessPatients => true;
  @override
  bool get canAccessHomeVisits => true;
  @override
  bool get canAccessSocialSupport => true;
  @override
  bool get canAccessVolunteers => true;
  @override
  bool get canAccessEquipment =>
      canAccessEquipmentOverride ?? (!isMember && !isVolunteer);
  @override
  bool get canAccessEquipmentDistribution =>
      canAccessEquipmentDistributionOverride ?? (!isMember && !isVolunteer);
  @override
  bool get canAccessMedicineSupply =>
      canAccessMedicineSupplyOverride ?? (!isMember && !isVolunteer);
  @override
  bool get canAccessMedicineMaster =>
      canAccessMedicineMasterOverride ?? (!isMember && !isVolunteer);
  @override
  bool get canAccessNHC => canAccessNHCOverride ?? (isAdmin || isStaff);
  @override
  bool get canAccessReports => true;
  @override
  String get unitName => 'Compassion Care';
  @override
  String get unitLocation => 'Kozhikode';
  @override
  String? get unitSupportName => 'Compassion Care help desk';
  @override
  String? get unitSupportPhone => '+91 98765 43210';
  @override
  String? get unitSupportPhoneDial => '+919876543210';
  @override
  String? get unitSupportEmail => 'help@compassion.example';
  @override
  Map<String, dynamic>? get user => {
    'name': switch (previewRole) {
      'admin' => 'Anita Rao',
      'staff' => 'Meera Nair',
      'member' => 'Joseph Thomas',
      _ => 'Arun Menon',
    },
    'email': 'preview@example.com',
  };

  @override
  Future<void> fetchUserProfile() async {}
}

Future<void> _pumpHome(
  WidgetTester tester,
  String role, {
  bool volunteerApproved = true,
  bool aboutUsAvailable = true,
  bool storyAvailable = true,
  bool? canAccessEquipment,
  bool? canAccessEquipmentDistribution,
  bool? canAccessMedicineSupply,
  bool? canAccessMedicineMaster,
  bool? canAccessNHC,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthService>.value(
      value: _HomePreviewAuthService(
        role,
        volunteerApproved: volunteerApproved,
        aboutUsAvailable: aboutUsAvailable,
        canAccessEquipmentOverride: canAccessEquipment,
        canAccessEquipmentDistributionOverride: canAccessEquipmentDistribution,
        canAccessMedicineSupplyOverride: canAccessMedicineSupply,
        canAccessMedicineMasterOverride: canAccessMedicineMaster,
        canAccessNHCOverride: canAccessNHC,
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: Homescreen(
          aboutUsLoader: ({bool refresh = false}) async => storyAvailable
              ? const AboutUsData(
                  hasAboutUs: true,
                  title: 'Care that stays close',
                  content:
                      'We support patients and families throughout their care.',
                  rawContent:
                      'We support patients and families throughout their care.',
                  unitName: 'Compassion Care',
                )
              : const AboutUsData(
                  hasAboutUs: false,
                  title: 'Our Story',
                  content: '',
                  rawContent: '',
                  unitName: 'Compassion Care',
                ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  for (final roleAndLabels in <(String, List<String>)>[
    ('admin', const ['Home visit', 'Social support', 'Equipment supply']),
    ('staff', const ['Home visit', 'Social support', 'Equipment supply']),
    ('member', const ['Social support', 'Volunteers', 'Reports']),
  ]) {
    testWidgets('${roleAndLabels.$1} quick actions use two rows', (
      tester,
    ) async {
      await _pumpHome(tester, roleAndLabels.$1);

      final firstTop = tester.getTopLeft(find.text(roleAndLabels.$2[0])).dy;
      final secondTop = tester.getTopLeft(find.text(roleAndLabels.$2[1])).dy;
      final thirdTop = tester.getTopLeft(find.text(roleAndLabels.$2[2])).dy;

      expect(secondTop, greaterThan(firstTop));
      expect(thirdTop, firstTop);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('admin home includes all three dashboard sections', (
    tester,
  ) async {
    await _pumpHome(tester, 'admin');

    expect(find.text('Compassion Care'), findsOneWidget);
    expect(find.byTooltip('Open menu'), findsOneWidget);
    expect(find.byTooltip('Show QR'), findsOneWidget);
    expect(find.byTooltip('Notifications'), findsOneWidget);
    expect(find.byTooltip('Quick add'), findsOneWidget);
    expect(find.text('Our Story'), findsOneWidget);
    expect(find.text('Patients'), findsWidgets);
    expect(find.text('Visit\nAssessment'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('Needs your attention'), findsOneWidget);
    final quickActionsTitle = tester.widget<Text>(find.text('Quick actions'));
    final attentionTitle = tester.widget<Text>(
      find.text('Needs your attention'),
    );
    expect(attentionTitle.style?.fontSize, quickActionsTitle.style?.fontSize);
    expect(
      attentionTitle.style?.fontWeight,
      quickActionsTitle.style?.fontWeight,
    );
    expect(attentionTitle.style?.color, quickActionsTitle.style?.color);
    expect(find.text('Equipment distributed'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Medicine'), findsOneWidget);
    expect(find.text('Visits'), findsOneWidget);
    expect(find.text('NHC'), findsOneWidget);
    expect(find.text('Alerts'), findsNothing);
    expect(find.text('Profile'), findsNothing);
    final metricHover = tester.widget<InkWell>(
      find.ancestor(
        of: find.text('Visit\nAssessment'),
        matching: find.byType(InkWell),
      ),
    );
    final activityHover = tester.widget<InkWell>(
      find.ancestor(
        of: find.text('Equipment distributed'),
        matching: find.byType(InkWell),
      ),
    );
    expect(metricHover.hoverColor, const Color(0x08000000));
    expect(activityHover.hoverColor, const Color(0x08000000));
    expect(tester.takeException(), isNull);
  });

  testWidgets('staff home shows priority work and latest notifications', (
    tester,
  ) async {
    await _pumpHome(tester, 'staff');

    expect(find.text('Compassion Care'), findsOneWidget);
    expect(find.text('Visit\nAssessment'), findsOneWidget);
    expect(find.text('Latest notifications'), findsOneWidget);
    expect(find.text('Medicine'), findsOneWidget);
    expect(find.text('Visits'), findsOneWidget);
    expect(find.text('NHC'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('member home hides an empty notification section', (
    tester,
  ) async {
    await _pumpHome(tester, 'member');

    expect(find.text('Compassion Care'), findsOneWidget);
    expect(find.text('Home visits'), findsOneWidget);
    expect(find.text('Social support'), findsOneWidget);
    expect(find.text('Latest notifications'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Patients'), findsWidgets);
    expect(find.text('Visits'), findsOneWidget);
    expect(find.text('Medicine'), findsNothing);
    expect(find.text('NHC'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('volunteer home shows availability and task tabs', (
    tester,
  ) async {
    await _pumpHome(tester, 'volunteer');

    expect(find.text('Compassion Care'), findsOneWidget);
    expect(find.text('Our Story'), findsOneWidget);
    expect(find.text('Share\navailability'), findsOneWidget);
    expect(find.text('My tasks'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('My Work'), findsOneWidget);
    expect(find.text('Patients'), findsWidgets);
    expect(find.text('Visits'), findsOneWidget);
    expect(find.text('Medicine'), findsNothing);
    expect(find.text('NHC'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new volunteer home shows the Our Story content', (tester) async {
    await _pumpHome(
      tester,
      'volunteer',
      volunteerApproved: false,
      aboutUsAvailable: false,
    );

    expect(find.text('Approval is pending'), findsOneWidget);
    expect(find.text('WAITING FOR REVIEW'), findsOneWidget);
    expect(find.text('Compassion Care help desk'), findsOneWidget);
    expect(find.text('+91 98765 43210'), findsOneWidget);
    expect(find.text('help@compassion.example'), findsOneWidget);
    expect(find.text('Our Story'), findsNWidgets(2));
    expect(find.text('Care that stays close'), findsOneWidget);
    expect(
      find.text('We support patients and families throughout their care.'),
      findsOneWidget,
    );
    final storyLink = tester.widget<InkWell>(
      find.ancestor(of: find.text('Our Story'), matching: find.byType(InkWell)),
    );
    final approvalTitle = tester.widget<Text>(find.text('Approval is pending'));
    expect(approvalTitle.style?.fontSize, 22);
    expect(storyLink.onTap, isNotNull);

    await tester.tap(
      find.ancestor(of: find.text('Our Story'), matching: find.byType(InkWell)),
    );
    await tester.pumpAndSettle();
    expect(find.text('About Our Unit'), findsOneWidget);
    expect(find.text('Care that stays close'), findsOneWidget);
    expect(
      find.text('We support patients and families throughout their care.'),
      findsOneWidget,
    );
    expect(find.text('Unable to Load Story'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending volunteer hides Our Story when content is empty', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      'volunteer',
      volunteerApproved: false,
      aboutUsAvailable: false,
      storyAvailable: false,
    );

    expect(find.text('Approval is pending'), findsOneWidget);
    expect(find.text('Our Story'), findsNothing);
    expect(find.text('Care that stays close'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'member home shows Equipment when equipment permission is granted',
    (tester) async {
      await _pumpHome(
        tester,
        'member',
        canAccessEquipment: true,
      );

      expect(find.text('Equipment'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'member home shows Equipment supply when equipmentDistribution permission is granted',
    (tester) async {
      await _pumpHome(
        tester,
        'member',
        canAccessEquipmentDistribution: true,
      );

      expect(find.text('Equipment supply'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'member home shows both Equipment and Equipment supply when both are granted',
    (tester) async {
      await _pumpHome(
        tester,
        'member',
        canAccessEquipment: true,
        canAccessEquipmentDistribution: true,
      );

      expect(find.text('Equipment'), findsOneWidget);
      expect(find.text('Equipment supply'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'volunteer home shows Equipment and Reports when permissions are granted',
    (tester) async {
      await _pumpHome(
        tester,
        'volunteer',
        canAccessEquipment: true,
      );

      expect(find.text('Equipment'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

