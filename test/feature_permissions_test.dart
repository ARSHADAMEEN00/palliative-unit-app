import 'package:flutter_test/flutter_test.dart';
import 'package:oruma_app/services/feature_permissions.dart';

void main() {
  group('FeatureAccessPolicy', () {
    test('members cannot access server-restricted modules', () {
      for (final featureId in [
        AppFeature.nhcAssessment,
        AppFeature.nhcPdf,
        AppFeature.medicineMaster,
        AppFeature.medicineStock,
        AppFeature.medicineSupply,
      ]) {
        expect(
          FeatureAccessPolicy.roleAllows('member', featureId),
          isFalse,
          reason: '$featureId should be hidden for members',
        );
      }
    });

    test('members retain access to permitted care modules', () {
      for (final featureId in [
        AppFeature.patients,
        AppFeature.homeVisits,
        AppFeature.volunteers,
        AppFeature.socialSupport,
        AppFeature.equipment,
        AppFeature.equipmentDistribution,
      ]) {
        expect(
          FeatureAccessPolicy.roleAllows('member', featureId),
          isTrue,
          reason: '$featureId should remain available to members',
        );
      }
    });

    test('other roles continue to use unit feature permissions', () {
      expect(
        FeatureAccessPolicy.roleAllows('staff', AppFeature.medicineSupply),
        isTrue,
      );
      expect(
        FeatureAccessPolicy.roleAllows('admin', AppFeature.nhcAssessment),
        isTrue,
      );
    });
  });
}
