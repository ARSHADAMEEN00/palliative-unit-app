import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_colors.dart';
import 'package:oruma_app/core/theme/app_icons.dart';
import 'package:oruma_app/core/theme/app_motion.dart';
import 'package:oruma_app/core/theme/app_radius.dart';
import 'package:oruma_app/core/theme/app_shadow.dart';
import 'package:oruma_app/core/theme/app_spacing.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:provider/provider.dart';

enum AppBottomSection { home, medicine, patients, homeVisit, nhc }

class AppBottomNavItem {
  const AppBottomNavItem(this.section, this.icon, this.label);

  final AppBottomSection section;
  final IconData icon;
  final String label;
}

class CompactAppBottomBar extends StatelessWidget {
  const CompactAppBottomBar({
    super.key,
    required this.current,
    required this.onSelected,
  });

  final AppBottomSection current;
  final ValueChanged<AppBottomSection> onSelected;

  static const items = <AppBottomNavItem>[
    AppBottomNavItem(AppBottomSection.home, Icons.home_outlined, 'Home'),
    AppBottomNavItem(
      AppBottomSection.medicine,
      Icons.medication_outlined,
      'Medicine',
    ),
    AppBottomNavItem(
      AppBottomSection.patients,
      Icons.people_outline,
      'Patients',
    ),
    AppBottomNavItem(
      AppBottomSection.homeVisit,
      Icons.home_work_outlined,
      'Visits',
    ),
    AppBottomNavItem(AppBottomSection.nhc, Icons.assignment_outlined, 'NHC'),
  ];

  static List<AppBottomNavItem> visibleItems(AuthService auth) {
    return items.where((item) {
      if (item.section == AppBottomSection.medicine &&
          !auth.canAccessMedicineSupply) {
        return false;
      }
      if (item.section == AppBottomSection.patients &&
          !auth.canAccessPatients) {
        return false;
      }
      if (item.section == AppBottomSection.homeVisit &&
          !auth.canAccessHomeVisits) {
        return false;
      }
      if (item.section == AppBottomSection.nhc && !auth.canAccessNHC) {
        return false;
      }
      return true;
    }).toList();
  }

  static List<AppBottomNavItem> visibleItemsFor(AuthService? auth) {
    return auth == null ? items : visibleItems(auth);
  }

  static AuthService? maybeAuth(BuildContext context) {
    try {
      return context.watch<AuthService>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = visibleItemsFor(maybeAuth(context));

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.92),
            border: const Border(top: BorderSide(color: AppColors.border)),
            boxShadow: AppShadow.small,
          ),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.only(
              left: AppSpacing.sm,
              right: AppSpacing.sm,
              bottom: AppSpacing.xs,
            ),
            child: SizedBox(
              height: 72,
              child: Row(
                children: items.map((item) {
                  final selected = current == item.section;
                  return Expanded(
                    child: _BottomNavTile(
                      item: item,
                      selected: selected,
                      onTap: () => onSelected(item.section),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavTile extends StatelessWidget {
  const _BottomNavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppBottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: AppRadius.card,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: AppRadius.card,
                    hoverColor: AppColors.surface2.withValues(alpha: 0.78),
                    highlightColor: AppColors.primary.withValues(alpha: 0.06),
                    splashColor: AppColors.primary.withValues(alpha: 0.08),
                    child: AnimatedContainer(
                      duration: AppMotion.normal,
                      curve: AppMotion.easeOutCubic,
                      width: double.infinity,
                      height: 58,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primaryLight.withValues(alpha: 0.72)
                            : Colors.transparent,
                        borderRadius: AppRadius.card,
                        border: selected
                            ? Border.all(
                                color: AppColors.primary.withValues(
                                  alpha: 0.08,
                                ),
                              )
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            item.icon,
                            size: AppIcons.large,
                            color: color,
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: color,
                                fontSize: 11,
                                height: 1.05,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
