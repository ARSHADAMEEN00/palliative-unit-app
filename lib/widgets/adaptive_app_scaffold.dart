import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_breakpoints.dart';
import 'package:oruma_app/core/theme/app_colors.dart';
import 'package:oruma_app/core/theme/app_icons.dart';
import 'package:oruma_app/core/theme/app_motion.dart';
import 'package:oruma_app/core/theme/app_radius.dart';
import 'package:oruma_app/core/theme/app_shadow.dart';
import 'package:oruma_app/core/theme/app_spacing.dart';
import 'package:oruma_app/widgets/compact_app_bottom_bar.dart';
import 'package:oruma_app/widgets/unit_brand_avatar.dart';

class AdaptiveAppScaffold extends StatelessWidget {
  const AdaptiveAppScaffold({
    super.key,
    this.scaffoldKey,
    this.appBar,
    required this.body,
    this.backgroundColor,
    this.drawer,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.currentSection,
    this.onNavigationSelected,
    this.centerBodyOnTablet = true,
    this.contentMaxWidth = 920,
    this.tabletBreakpoint = AppBreakpoints.tablet,
    this.extendBody = false,
    this.resizeToAvoidBottomInset,
  });

  final GlobalKey<ScaffoldState>? scaffoldKey;
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Color? backgroundColor;
  final Widget? drawer;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final AppBottomSection? currentSection;
  final ValueChanged<AppBottomSection>? onNavigationSelected;
  final bool centerBodyOnTablet;
  final double contentMaxWidth;
  final double tabletBreakpoint;
  final bool extendBody;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= tabletBreakpoint;
        final usesRail = isTablet && currentSection != null;
        final customBottomBar = bottomNavigationBar == null
            ? null
            : _TabletWidthFrame(
                enabled: isTablet && centerBodyOnTablet,
                maxWidth: contentMaxWidth,
                child: bottomNavigationBar!,
              );
        final customBottomSheet = bottomSheet == null
            ? null
            : _TabletWidthFrame(
                enabled: isTablet && centerBodyOnTablet,
                maxWidth: contentMaxWidth,
                child: Builder(
                  builder: (sheetContext) {
                    final mediaQuery = MediaQuery.of(sheetContext);
                    final viewPadding = MediaQuery.viewPaddingOf(sheetContext);
                    final bottomInset = mediaQuery.viewInsets.bottom > 0
                        ? 0.0
                        : viewPadding.bottom;
                    return MediaQuery(
                      data: mediaQuery.copyWith(
                        padding: mediaQuery.padding.copyWith(
                          bottom: bottomInset,
                        ),
                      ),
                      child: bottomSheet!,
                    );
                  },
                ),
              );

        return Scaffold(
          key: scaffoldKey,
          appBar: appBar,
          drawer: drawer,
          backgroundColor: backgroundColor ?? AppColors.background,
          bottomSheet: customBottomSheet,
          floatingActionButton: floatingActionButton,
          floatingActionButtonLocation: floatingActionButtonLocation,
          extendBody: extendBody,
          resizeToAvoidBottomInset: resizeToAvoidBottomInset,
          bottomNavigationBar: usesRail
              ? null
              : currentSection == null
              ? customBottomBar
              : CompactAppBottomBar(
                  current: currentSection!,
                  onSelected: onNavigationSelected ?? (_) {},
                ),
          body: usesRail
              ? Row(
                  children: [
                    _TabletNavigationRail(
                      current: currentSection!,
                      extended: constraints.maxWidth >= 1100,
                      onSelected: onNavigationSelected ?? (_) {},
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: AppColors.border,
                    ),
                    Expanded(
                      child: _TabletBodyFrame(
                        enabled: centerBodyOnTablet,
                        maxWidth: contentMaxWidth,
                        child: body,
                      ),
                    ),
                  ],
                )
              : _TabletBodyFrame(
                  enabled: isTablet && centerBodyOnTablet,
                  maxWidth: contentMaxWidth,
                  child: body,
                ),
        );
      },
    );
  }
}

class _TabletBodyFrame extends StatelessWidget {
  const _TabletBodyFrame({
    required this.enabled,
    required this.maxWidth,
    required this.child,
  });

  final bool enabled;
  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < maxWidth
            ? constraints.maxWidth
            : maxWidth;
        final framedChild = constraints.hasBoundedHeight
            ? SizedBox(
                width: width,
                height: constraints.maxHeight,
                child: child,
              )
            : SizedBox(width: width, child: child);

        return Align(alignment: Alignment.topCenter, child: framedChild);
      },
    );
  }
}

class _TabletWidthFrame extends StatelessWidget {
  const _TabletWidthFrame({
    required this.enabled,
    required this.maxWidth,
    required this.child,
  });

  final bool enabled;
  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < maxWidth
            ? constraints.maxWidth
            : maxWidth;
        return Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: SizedBox(width: width, child: child),
        );
      },
    );
  }
}

class _TabletNavigationRail extends StatelessWidget {
  const _TabletNavigationRail({
    required this.current,
    required this.extended,
    required this.onSelected,
  });

  final AppBottomSection current;
  final bool extended;
  final ValueChanged<AppBottomSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = CompactAppBottomBar.visibleItemsFor(
      CompactAppBottomBar.maybeAuth(context),
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadow.small,
      ),
      child: SizedBox(
        width: extended ? 204 : 96,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.lg),
                child: _RailBrand(extended: extended),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: extended ? AppSpacing.sm : AppSpacing.xs,
                    vertical: AppSpacing.xs,
                  ),
                  child: Column(
                    children: [
                      for (final item in items) ...[
                        _RailDestinationItem(
                          item: item,
                          selected: item.section == current,
                          extended: extended,
                          onTap: () {
                            if (item.section != current) {
                              onSelected(item.section);
                            }
                          },
                        ),
                        if (item != items.last)
                          const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailDestinationItem extends StatelessWidget {
  const _RailDestinationItem({
    required this.item,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  final AppBottomNavItem item;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedColor = Theme.of(context).colorScheme.primary;
    const inactiveColor = AppColors.textSecondary;
    final selectedBackground = selectedColor.withValues(alpha: 0.12);
    final iconColor = selected ? selectedColor : inactiveColor;
    const compactIndicatorWidth = 56.0;
    const compactIndicatorHeight = 40.0;

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: extended
          ? InkWell(
              onTap: onTap,
              borderRadius: AppRadius.button,
              child: AnimatedContainer(
                duration: AppMotion.normal,
                curve: AppMotion.easeOutCubic,
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: selected ? selectedBackground : Colors.transparent,
                  borderRadius: AppRadius.button,
                ),
                child: Row(
                  children: [
                    Icon(item.icon, size: AppIcons.large, color: iconColor),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? selectedColor : inactiveColor,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: Colors.transparent,
                    borderRadius: AppRadius.button,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: AppRadius.button,
                      hoverColor: selectedBackground,
                      highlightColor: selectedBackground,
                      splashColor: selectedColor.withValues(alpha: 0.12),
                      child: AnimatedContainer(
                        duration: AppMotion.normal,
                        curve: AppMotion.easeOutCubic,
                        width: compactIndicatorWidth,
                        height: compactIndicatorHeight,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? selectedBackground
                              : Colors.transparent,
                          borderRadius: AppRadius.button,
                        ),
                        child: Icon(
                          item.icon,
                          size: AppIcons.large,
                          color: iconColor,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTap,
                    child: AnimatedSwitcher(
                      duration: AppMotion.fast,
                      child: selected
                          ? Padding(
                              key: ValueKey(item.section),
                              padding: const EdgeInsets.only(
                                top: AppSpacing.xs,
                              ),
                              child: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: selectedColor,
                                  fontSize: 12,
                                  height: 1.15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : const SizedBox(key: ValueKey('empty'), height: 0),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _RailBrand extends StatelessWidget {
  const _RailBrand({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final auth = CompactAppBottomBar.maybeAuth(context);
    const logo = UnitBrandAvatar(
      size: 38,
      preferAppIcon: true,
      fallbackIcon: Icons.local_hospital_outlined,
    );

    if (!extended) {
      return const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.md),
        child: logo,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.lg,
      ),
      child: SizedBox(
        width: 172,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            logo,
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              fit: FlexFit.loose,
              child: Text(
                auth?.unitName ?? 'Palliative App',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
