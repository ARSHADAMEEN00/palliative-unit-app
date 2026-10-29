import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:oruma_app/config/admob_config.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/services/mobile_ads_service.dart';

class PalliativeNativeAd extends StatefulWidget {
  const PalliativeNativeAd({
    super.key,
    required this.header,
    this.includeBottomSafeArea = false,
  });

  final Widget header;
  final bool includeBottomSafeArea;

  @override
  State<PalliativeNativeAd> createState() => _PalliativeNativeAdState();
}

class _PalliativeNativeAdState extends State<PalliativeNativeAd> {
  NativeAd? _nativeAd;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Future<void> _loadAd() async {
    if (!AdMobConfig.isSupportedPlatform) return;
    if (!await MobileAdsService.prepareForAds() || !mounted) return;

    late final NativeAd ad;
    ad = NativeAd(
      adUnitId: AdMobConfig.nativeAdUnitId,
      // Care context must never be used for behavioural ad targeting.
      request: const AdRequest(nonPersonalizedAds: true),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: AppColors.surface,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: AppColors.textInverse,
          backgroundColor: AppColors.primary,
          size: 13,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: AppColors.text,
          backgroundColor: AppColors.surface,
          size: 15,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: AppColors.textSecondary,
          backgroundColor: AppColors.surface,
          size: 12,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: AppColors.textMuted,
          backgroundColor: AppColors.surface,
          size: 11,
        ),
      ),
      listener: NativeAdListener(
        onAdLoaded: (loadedAd) {
          if (!mounted) {
            loadedAd.dispose();
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (failedAd, error) {
          debugPrint('Native ad failed to load: $error');
          failedAd.dispose();
          if (identical(_nativeAd, failedAd)) _nativeAd = null;
        },
      ),
    );

    _nativeAd = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _nativeAd;
    final showLoadedAd = _loaded && ad != null;
    if (!showLoadedAd) return const SizedBox.shrink();

    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        top: false,
        bottom: widget.includeBottomSafeArea,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                widget.header,
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 400,
                    height: 100,
                    child: ClipRRect(
                      borderRadius: AppRadius.md,
                      child: AdWidget(ad: ad),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
