import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:oruma_app/config/admob_config.dart';

abstract final class MobileAdsService {
  static Future<bool>? _preparation;

  static Future<bool> prepareForAds() {
    if (!AdMobConfig.isSupportedPlatform) return Future.value(false);
    return _preparation ??= _prepare();
  }

  static Future<bool> _prepare() async {
    await _requestConsentUpdate();

    try {
      if (!await ConsentInformation.instance.canRequestAds()) return false;
      await MobileAds.instance.initialize();
      return true;
    } catch (error) {
      debugPrint('Could not initialize Google Mobile Ads: $error');
      return false;
    }
  }

  static Future<void> _requestConsentUpdate() async {
    final completer = Completer<void>();

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          await ConsentForm.loadAndShowConsentFormIfRequired((error) {
            if (error != null) {
              debugPrint('Ad consent form error: ${error.message}');
            }
          });
          if (!completer.isCompleted) completer.complete();
        },
        (error) {
          debugPrint('Ad consent information error: ${error.message}');
          if (!completer.isCompleted) completer.complete();
        },
      );
      await completer.future;
    } catch (error) {
      debugPrint('Could not update ad consent: $error');
    }
  }

  static Future<bool> privacyOptionsRequired() async {
    if (!AdMobConfig.isSupportedPlatform) return false;
    try {
      final status = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
      return status == PrivacyOptionsRequirementStatus.required;
    } catch (error) {
      debugPrint('Could not read ad privacy options status: $error');
      return false;
    }
  }

  static Future<void> showPrivacyOptions() async {
    if (!AdMobConfig.isSupportedPlatform) return;
    await ConsentForm.showPrivacyOptionsForm((error) {
      if (error != null) {
        debugPrint('Could not show ad privacy options: ${error.message}');
      }
    });
  }
}
