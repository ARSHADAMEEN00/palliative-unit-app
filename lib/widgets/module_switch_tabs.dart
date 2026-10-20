import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_motion.dart';
import 'package:oruma_app/core/theme/app_radius.dart';

class ModuleSwitchTabs extends StatelessWidget {
  const ModuleSwitchTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.color,
    required this.onSelected,
    this.icons,
  });

  final List<String> labels;
  final List<IconData>? icons;
  final int selectedIndex;
  final Color color;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.md,
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(labels.length, (index) {
          final selected = selectedIndex == index;
          return Flexible(
            fit: FlexFit.loose,
            child: InkWell(
              onTap: selected ? null : () => onSelected(index),
              borderRadius: AppRadius.sm,
              child: AnimatedContainer(
                duration: AppMotion.fast,
                curve: AppMotion.easeOutCubic,
                height: 25,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? color : Colors.transparent,
                  borderRadius: AppRadius.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icons != null) ...[
                      Icon(
                        icons![index],
                        size: 13,
                        color: selected ? Colors.white : color,
                      ),
                      const SizedBox(width: 3.5),
                    ],
                    Flexible(
                      child: Text(
                        labels[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(
                          color: selected ? Colors.white : color,
                          fontSize: 11,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
