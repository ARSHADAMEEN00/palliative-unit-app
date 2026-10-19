import 'package:flutter_test/flutter_test.dart';
import 'package:oruma_app/models/staff_user.dart';
import 'package:oruma_app/models/volunteer.dart';
import 'package:oruma_app/models/volunteer_activity.dart';
import 'package:oruma_app/models/volunteer_home_visit_request.dart';

void main() {
  test('volunteer application status and email are parsed', () {
    final volunteer = Volunteer.fromJson({
      '_id': 'volunteer-1',
      'name': 'Asha',
      'email': 'asha@example.com',
      'phone': '9999999999',
      'village': 'Town',
      'ward': '03',
      'place': 'Centre',
      'applicationStatus': 'pending',
    });

    expect(volunteer.email, 'asha@example.com');
    expect(volunteer.applicationStatus, 'pending');
    expect(volunteer.ward, '3');
  });

  test('staff explicit module permissions are distinguishable from legacy', () {
    final configured = StaffUser.fromJson({
      '_id': 'staff-1',
      'name': 'Nurse',
      'email': 'nurse@example.com',
      'role': 'staff',
      'permittedModuleIds': ['patients', 'home_visits'],
    });
    final legacy = StaffUser.fromJson({
      '_id': 'staff-2',
      'name': 'Legacy',
      'email': 'legacy@example.com',
      'role': 'staff',
    });

    expect(configured.hasExplicitModulePermissions, isTrue);
    expect(configured.permittedModuleIds, ['patients', 'home_visits']);
    expect(legacy.hasExplicitModulePermissions, isFalse);
  });

  test('volunteer activity parses achievement and history', () {
    final activity = VolunteerActivity.fromJson({
      'totalSocialWorks': 12,
      'achievementTier': 'Silver',
      'nextTierAt': 25,
      'history': [
        {
          'id': 'work-1',
          'givenAt': '2026-10-16T05:00:00.000Z',
          'supportTypes': ['medicine'],
          'patientName': 'Patient One',
        },
      ],
    });

    expect(activity.totalSocialWorks, 12);
    expect(activity.achievementTier, 'Silver');
    expect(activity.history.single.patientName, 'Patient One');
  });

  test('home visit volunteer request parses visit and volunteer details', () {
    final request = VolunteerHomeVisitRequest.fromJson({
      'id': 'request-1',
      'status': 'pending',
      'requestedAt': '2026-10-19T10:00:00.000Z',
      'homeVisit': {
        'id': 'visit-1',
        'patientName': 'Abdul Rahman',
        'address': 'Rahma Manzil, Mundakkode',
        'visitDate': '2026-10-20',
        'visitMode': 'monthly',
      },
      'volunteer': {
        'id': 'volunteer-1',
        'name': 'Asha',
        'phone': '9999999999',
        'place': 'Centre',
      },
    });

    expect(request.status, 'pending');
    expect(request.homeVisit?.id, 'visit-1');
    expect(request.homeVisit?.address, 'Rahma Manzil, Mundakkode');
    expect(request.volunteer?.name, 'Asha');
  });
}
