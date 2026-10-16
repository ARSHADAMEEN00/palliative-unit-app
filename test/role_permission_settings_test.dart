import 'package:flutter_test/flutter_test.dart';
import 'package:oruma_app/services/staff_service.dart';

void main() {
  test('role settings keep subscribed modules separate from role defaults', () {
    final settings = RolePermissionSettings.fromJson({
      'allModuleIds': ['patients', 'home_visits', 'medicine_stock'],
      'subscribedModuleIds': ['patients', 'home_visits'],
      'rolePermissions': {
        'admin': ['patients', 'home_visits'],
        'staff': ['patients'],
        'member': <String>[],
        'user': ['patients'],
      },
    });

    expect(settings.allModuleIds, [
      'patients',
      'home_visits',
      'medicine_stock',
    ]);
    expect(settings.subscribedModuleIds, {'patients', 'home_visits'});
    expect(settings.rolePermissions['staff'], {'patients'});
    expect(settings.rolePermissions['member'], isEmpty);
    expect(settings.rolePermissions['user'], {'patients'});
  });
}
