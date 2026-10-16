import 'package:flutter_test/flutter_test.dart';
import 'package:oruma_app/models/staff_user.dart';
import 'package:oruma_app/models/volunteer.dart';
import 'package:oruma_app/models/volunteer_activity.dart';

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
}
