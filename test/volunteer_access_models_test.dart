import 'package:flutter_test/flutter_test.dart';
import 'package:oruma_app/models/config.dart';
import 'package:oruma_app/models/staff_user.dart';
import 'package:oruma_app/models/volunteer.dart';
import 'package:oruma_app/models/volunteer_activity.dart';
import 'package:oruma_app/models/volunteer_availability_request.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/widgets/compact_app_bottom_bar.dart';

void main() {
  test('config parses volunteer availability time and defaults', () {
    final defaultConfig = Config.fromJson({});
    expect(defaultConfig.volunteerAvailabilityStartTime, '09:30 AM');
    expect(defaultConfig.volunteerAvailabilityEndTime, '03:30 PM');
    expect(defaultConfig.volunteerAvailabilityTimeWindow, '09:30 AM to 03:30 PM');

    final customConfig = Config.fromJson({
      'volunteerAvailabilityStartTime': '10:00 AM',
      'volunteerAvailabilityEndTime': '02:00 PM',
    });
    expect(customConfig.volunteerAvailabilityStartTime, '10:00 AM');
    expect(customConfig.volunteerAvailabilityEndTime, '02:00 PM');
    expect(customConfig.volunteerAvailabilityTimeWindow, '10:00 AM to 02:00 PM');

    final json = customConfig.toJson();
    expect(json['volunteerAvailabilityStartTime'], '10:00 AM');
    expect(json['volunteerAvailabilityEndTime'], '02:00 PM');
  });

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
      'joinedAt': '2026-01-05T08:30:00.000Z',
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
    expect(activity.joinedAt, DateTime.utc(2026, 1, 5, 8, 30));
    expect(activity.history.single.patientName, 'Patient One');
  });

  test('volunteer availability request parses contact and decision note', () {
    final request = VolunteerAvailabilityRequest.fromJson({
      'id': 'request-1',
      'status': 'approved',
      'requestedDate': '2026-10-20',
      'contactName': 'Asha',
      'phone': '9999999999',
      'address': 'Centre, Town',
      'timeSlot': '09:30 AM to 03:30 PM',
      'decisionNote': 'Please visit the unit on the day.',
      'requestedAt': '2026-10-19T10:00:00.000Z',
      'volunteer': {
        'id': 'volunteer-1',
        'name': 'Asha',
        'phone': '9999999999',
        'place': 'Centre',
        'address': 'Centre, Town',
      },
    });

    expect(request.status, 'approved');
    expect(request.requestedDate, '2026-10-20');
    expect(request.address, 'Centre, Town');
    expect(request.timeSlot, '09:30 AM to 03:30 PM');
    expect(request.decisionNote, 'Please visit the unit on the day.');
    expect(request.volunteer?.name, 'Asha');
  });

  test('My Work bottom navigation destination is volunteer-only', () {
    final volunteerSections = CompactAppBottomBar.visibleItems(
      _RoleAuthService(isVolunteer: true),
    ).map((item) => item.section);
    final staffSections = CompactAppBottomBar.visibleItems(
      _RoleAuthService(isVolunteer: false),
    ).map((item) => item.section);

    expect(volunteerSections, contains(AppBottomSection.socialWork));
    expect(staffSections, isNot(contains(AppBottomSection.socialWork)));
  });
}

class _RoleAuthService extends AuthService {
  _RoleAuthService({required this.isVolunteer});

  @override
  final bool isVolunteer;
}
