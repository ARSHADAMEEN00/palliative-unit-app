import 'package:flutter_test/flutter_test.dart';
import 'package:oruma_app/models/volunteer_activity.dart';
import 'package:oruma_app/models/volunteer_assignment.dart';

void main() {
  test('assignment displays only points returned by the API', () {
    final assignment = VolunteerAssignment.fromJson({
      'id': 'assignment-1',
      'taskType': 'home_visit',
      'taskId': 'task-1',
      'scheduledDate': '2026-10-20',
      'status': 'assigned',
      'pointsAwarded': 1,
      'patient': {'name': 'Patient', 'address': ''},
      'taskDetails': {'title': 'Home Visit'},
    });

    expect(assignment.pointsAwarded, 1);
    expect(assignment.pointsLabel, '+1 pt');
  });

  test('assignment does not invent points when none were awarded', () {
    final assignment = VolunteerAssignment.fromJson({
      'id': 'assignment-2',
      'taskType': 'visit_assessment',
      'taskId': 'task-2',
      'scheduledDate': '2026-10-20',
      'status': 'assigned',
      'patient': {'name': 'Patient', 'address': ''},
      'taskDetails': {'title': 'Visit Assessment'},
    });

    expect(assignment.pointsAwarded, 0);
    expect(assignment.pointsLabel, '+0 pts');
  });

  test('activity totals no longer derive points from completed work count', () {
    final activity = VolunteerActivity.fromJson({
      'totalSocialWorks': 4,
      'history': const [],
    });

    expect(activity.totalPoints, 0);
  });
}
