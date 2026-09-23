import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oruma_app/core/theme/app_colors.dart';
import 'package:oruma_app/core/theme/app_radius.dart';
import 'package:oruma_app/core/theme/app_shadow.dart';
import 'package:oruma_app/core/theme/app_spacing.dart';
import 'package:oruma_app/shared/widgets/buttons/app_buttons.dart';
import 'package:upgrader/upgrader.dart';

/// Checks the store version and presents an update prompt using the app's
/// design system.
class PalliativeUpgradeAlert extends UpgradeAlert {
  PalliativeUpgradeAlert({super.key, super.upgrader, required Widget child})
    : super(
        barrierDismissible: false,
        showIgnore: false,
        showLater: true,
        showReleaseNotes: true,
        child: child,
      );

  @override
  UpgradeAlertState createState() => _PalliativeUpgradeAlertState();
}

class _PalliativeUpgradeAlertState extends UpgradeAlertState {
  @override
  void showTheDialog({
    Key? key,
    required BuildContext context,
    required String? title,
    required String message,
    required String? releaseNotes,
    required bool barrierDismissible,
    required UpgraderMessages messages,
  }) {
    if (!context.mounted) return;

    unawaited(widget.upgrader.saveLastAlerted());

    final isBlocked = widget.upgrader.blocked();
    final installedVersion = widget.upgrader.currentInstalledVersion;
    final storeVersion = widget.upgrader.currentAppStoreVersion;
    final updateMessage = installedVersion != null && storeVersion != null
        ? 'Version $storeVersion is available on Google Play. '
              'You are currently using version $installedVersion.'
        : message;

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: (dialogContext) => PopScope(
          canPop: onCanPop(),
          child: _PalliativeUpgradeDialog(
            key: key,
            isBlocked: isBlocked,
            message: updateMessage,
            releaseNotes: releaseNotes,
            releaseNotesLabel:
                messages.message(UpgraderMessage.releaseNotes) ?? 'What\'s new',
            onLater: isBlocked ? null : () => onUserLater(dialogContext, true),
            onUpdate: () => onUserUpdated(dialogContext, !isBlocked),
          ),
        ),
      ).whenComplete(() => displayed = false),
    );
  }
}

class _PalliativeUpgradeDialog extends StatelessWidget {
  const _PalliativeUpgradeDialog({
    super.key,
    required this.isBlocked,
    required this.message,
    required this.releaseNotes,
    required this.releaseNotesLabel,
    required this.onLater,
    required this.onUpdate,
  });

  final bool isBlocked;
  final String message;
  final String? releaseNotes;
  final String releaseNotesLabel;
  final VoidCallback? onLater;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final notes = releaseNotes?.trim();
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      child: Semantics(
        container: true,
        namesRoute: true,
        label: isBlocked ? 'Update required' : 'Update available',
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: 440,
            maxHeight: screenHeight - (AppSpacing.lg * 2),
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.dialog,
            boxShadow: AppShadow.large,
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            padding: AppInsets.lg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: AppRadius.card,
                    ),
                    child: const Icon(
                      Icons.system_update_alt_rounded,
                      size: 34,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  isBlocked ? 'Update required' : 'A new update is ready',
                  key: const Key('upgrader.dialog.title'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: AppRadius.md,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.shop_2_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Available on Google Play',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: AppInsets.md,
                    decoration: BoxDecoration(
                      color: AppColors.surface1,
                      borderRadius: AppRadius.md,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          releaseNotesLabel,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: AppColors.text,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          notes,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                AppPrimaryButton(
                  label: 'Update now',
                  icon: Icons.download_rounded,
                  fullWidth: true,
                  onPressed: onUpdate,
                ),
                if (onLater != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppSecondaryButton(
                    label: 'Maybe later',
                    fullWidth: true,
                    onPressed: onLater,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
