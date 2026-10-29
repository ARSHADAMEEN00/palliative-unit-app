abstract final class AdEligibility {
  static bool shouldShowAds({
    required bool isAuthenticated,
    required bool isAccessBlocked,
    required String? role,
    required String? subscriptionStatus,
  }) {
    if (!isAuthenticated || isAccessBlocked) return false;

    final normalizedRole = role?.trim().toLowerCase();
    if (normalizedRole == 'volunteer' || normalizedRole == 'public') {
      return true;
    }

    if (normalizedRole != 'admin' &&
        normalizedRole != 'staff' &&
        normalizedRole != 'member') {
      return false;
    }

    final normalizedStatus = subscriptionStatus?.trim().toLowerCase();
    if (normalizedStatus == null || normalizedStatus.isEmpty) {
      // Wait for the profile/subscription response instead of briefly showing
      // an ad to a paid unit while its status is still unknown.
      return false;
    }

    return normalizedStatus != 'active';
  }
}
