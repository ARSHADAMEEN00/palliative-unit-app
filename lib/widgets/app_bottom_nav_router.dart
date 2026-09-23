import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_colors.dart';
import 'package:oruma_app/core/theme/app_motion.dart';
import 'package:oruma_app/patient_list_page.dart';
import 'package:oruma_app/features/visit_assessment/presentation/screens/visit_assessment_visit_picker_screen.dart';
import 'package:oruma_app/home_visit_list_page.dart';
import 'package:oruma_app/homscreen.dart';
import 'package:oruma_app/medicine_supply_list_page.dart';
import 'package:oruma_app/services/feature_permissions.dart';
import 'package:oruma_app/widgets/compact_app_bottom_bar.dart';
import 'package:oruma_app/widgets/feature_permission_gate.dart';
import 'package:oruma_app/widgets/module_theme.dart';

class AppBottomNavRouter {
  AppBottomNavRouter._();

  static bool _transitionInProgress = false;
  static const _transitionDuration = AppMotion.page;

  static void handle(
    BuildContext context, {
    required AppBottomSection current,
    required AppBottomSection target,
  }) {
    if (current == target || _transitionInProgress) return;

    final featureId = _featureForSection(target);
    if (featureId != null &&
        !FeaturePermissionMiddleware.ensure(
          context,
          featureId,
          moduleName: _moduleNameForSection(target),
        )) {
      return;
    }

    final page = switch (target) {
      AppBottomSection.home => const Homescreen(),
      AppBottomSection.medicine => const ModuleTheme(
        palette: ModulePalettes.medicineSupply,
        child: MedicineSupplyListPage(),
      ),
      AppBottomSection.patients => const ModuleTheme(
        palette: ModulePalettes.patients,
        child: PatientListPage(),
      ),
      AppBottomSection.homeVisit => const ModuleTheme(
        palette: ModulePalettes.homeVisits,
        child: HomeVisitListPage(),
      ),
      AppBottomSection.nhc => const VisitAssessmentVisitPickerScreen(),
    };

    _open(context, page, forward: target.index > current.index);
  }

  static String? _featureForSection(AppBottomSection section) {
    return switch (section) {
      AppBottomSection.home => null,
      AppBottomSection.medicine => AppFeature.medicineSupply,
      AppBottomSection.patients => AppFeature.patients,
      AppBottomSection.homeVisit => AppFeature.homeVisits,
      AppBottomSection.nhc => AppFeature.nhcAssessment,
    };
  }

  static String _moduleNameForSection(AppBottomSection section) {
    return switch (section) {
      AppBottomSection.home => 'Home',
      AppBottomSection.medicine => 'Medicine Supply',
      AppBottomSection.patients => 'Patients',
      AppBottomSection.homeVisit => 'Home Visits',
      AppBottomSection.nhc => 'Visit Assessment',
    };
  }

  static void _open(
    BuildContext context,
    Widget page, {
    required bool forward,
  }) {
    _transitionInProgress = true;
    final route = PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: _transitionDuration,
      reverseTransitionDuration: _transitionDuration,
      pageBuilder: (_, _, _) =>
          ColoredBox(color: AppColors.background, child: page),
      transitionsBuilder: (_, animation, _, child) {
        final slideAnimation =
            Tween<Offset>(
              begin: Offset(forward ? 1 : -1, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: AppMotion.easeInOut),
            );
        return ClipRect(
          child: SlideTransition(position: slideAnimation, child: child),
        );
      },
    );

    Navigator.of(context).pushReplacement(route);

    Future<void>.delayed(_transitionDuration, () {
      _transitionInProgress = false;
    });
  }
}
