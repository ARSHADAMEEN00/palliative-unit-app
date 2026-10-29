import 'package:flutter/foundation.dart';

abstract final class AdMobConfig {
  static const androidAppId = 'ca-app-pub-1082683285205223~2216251092';

  static const nativeAdUnitId = 'ca-app-pub-1082683285205223/1754758659';

  static bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
