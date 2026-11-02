import 'package:flutter_test/flutter_test.dart';
import 'package:oruma_app/models/config.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Config workingTime', () {
    test('serializes and deserializes workingTime correctly', () {
      final config = Config(
        villages: ['Kuruva'],
        diseases: ['Cancer'],
        plans: ['Weekly'],
        wards: [],
        workingDays: [1, 2, 3, 4, 5, 6],
        volunteerAvailabilityStartTime: '09:00 AM',
        volunteerAvailabilityEndTime: '04:30 PM',
        workingTime: 'Mon - Sat: 9:00am - 4:30pm',
      );

      final json = config.toJson();
      expect(json['workingTime'], 'Mon - Sat: 9:00am - 4:30pm');

      final reconstructed = Config.fromJson(json);
      expect(reconstructed.workingTime, 'Mon - Sat: 9:00am - 4:30pm');
    });

    test('handles null and empty workingTime gracefully', () {
      final config = Config.fromJson({
        'villages': [],
        'diseases': [],
        'plans': [],
      });
      expect(config.workingTime, isNull);

      final configEmpty = Config.fromJson({
        'villages': [],
        'diseases': [],
        'plans': [],
        'workingTime': '   ',
      });
      expect(configEmpty.workingTime?.trim(), isEmpty);
    });
  });

  group('AuthService unitWorkingTime', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('unitWorkingTime is null when not set in unit data', () {
      final auth = AuthService();
      expect(auth.unitWorkingTime, isNull);
    });

    test('updateUnitWorkingTime updates state and persists', () async {
      final auth = AuthService();
      await auth.updateUnitWorkingTime('Mon - Sat: 9:00am - 4:30pm');
      expect(auth.unitWorkingTime, 'Mon - Sat: 9:00am - 4:30pm');

      await auth.updateUnitWorkingTime(null);
      expect(auth.unitWorkingTime, isNull);
    });
  });
}
