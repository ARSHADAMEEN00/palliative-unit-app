import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/widgets/palliative_native_ad.dart';
import 'package:provider/provider.dart';

class HomeNativeAdDock extends StatelessWidget {
  const HomeNativeAdDock({super.key, this.includeBottomSafeArea = false});

  final bool includeBottomSafeArea;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.shouldShowAds) return const SizedBox.shrink();

    return PalliativeNativeAd(
      includeBottomSafeArea: includeBottomSafeArea,
      header: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              _messageFor(auth),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _messageFor(AuthService auth) {
    if (auth.isVolunteer || auth.isPublicUser) {
      return 'This free account is supported by ads.';
    }
    if (auth.isAdmin) {
      return 'Subscribe from Profile → Billing & Plan to remove ads from staff and administration accounts.';
    }
    return 'Your unit is using the ad-supported plan. Ask the unit administrator to subscribe and remove ads from staff accounts.';
  }
}
