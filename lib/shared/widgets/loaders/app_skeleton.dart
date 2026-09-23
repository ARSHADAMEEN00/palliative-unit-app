import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_colors.dart';
import 'package:oruma_app/core/theme/app_motion.dart';
import 'package:oruma_app/core/theme/app_radius.dart';
import 'package:oruma_app/core/theme/app_spacing.dart';

class AppSkeletonBox extends StatefulWidget {
  const AppSkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = AppRadius.md,
  });

  final double width;
  final double height;
  final BorderRadius borderRadius;

  @override
  State<AppSkeletonBox> createState() => _AppSkeletonBoxState();
}

class _AppSkeletonBoxState extends State<AppSkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.slow)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: AppMotion.easeInOut),
      ),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: widget.borderRadius,
        ),
      ),
    );
  }
}

class AppListSkeleton extends StatelessWidget {
  const AppListSkeleton({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: AppInsets.page,
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        return const Row(
          children: [
            AppSkeletonBox(width: 56, height: 56, borderRadius: AppRadius.md),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeletonBox(width: double.infinity, height: 16),
                  SizedBox(height: AppSpacing.xs),
                  AppSkeletonBox(width: 180, height: 13),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
