import 'package:flutter_test/flutter_test.dart';
import 'package:oruma_app/services/ad_eligibility.dart';

bool shouldShow({
  String? role,
  String? subscriptionStatus,
  bool authenticated = true,
  bool accessBlocked = false,
}) => AdEligibility.shouldShowAds(
  isAuthenticated: authenticated,
  isAccessBlocked: accessBlocked,
  role: role,
  subscriptionStatus: subscriptionStatus,
);

void main() {
  group('ad eligibility', () {
    test('volunteer and public accounts always show ads', () {
      for (final role in ['volunteer', 'public']) {
        expect(shouldShow(role: role, subscriptionStatus: 'active'), isTrue);
        expect(shouldShow(role: role, subscriptionStatus: 'trial'), isTrue);
        expect(shouldShow(role: role), isTrue);
      }
    });

    test('paid staff roles hide ads only for an active subscription', () {
      for (final role in ['admin', 'staff', 'member']) {
        expect(shouldShow(role: role, subscriptionStatus: 'active'), isFalse);
        expect(shouldShow(role: role, subscriptionStatus: 'trial'), isTrue);
        expect(shouldShow(role: role, subscriptionStatus: 'past_due'), isTrue);
        expect(shouldShow(role: role, subscriptionStatus: 'cancelled'), isTrue);
      }
    });

    test('unknown subscription status does not flash ads to staff roles', () {
      for (final role in ['admin', 'staff', 'member']) {
        expect(shouldShow(role: role), isFalse);
      }
    });

    test(
      'logged-out, blocked, superadmin and unknown roles do not show ads',
      () {
        expect(
          shouldShow(
            role: 'volunteer',
            subscriptionStatus: 'trial',
            authenticated: false,
          ),
          isFalse,
        );
        expect(
          shouldShow(
            role: 'public',
            subscriptionStatus: 'trial',
            accessBlocked: true,
          ),
          isFalse,
        );
        expect(
          shouldShow(role: 'superadmin', subscriptionStatus: 'trial'),
          isFalse,
        );
        expect(shouldShow(role: 'other', subscriptionStatus: 'trial'), isFalse);
      },
    );
  });
}
