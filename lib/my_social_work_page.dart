import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/models/volunteer_activity.dart';
import 'package:oruma_app/services/volunteer_application_service.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';

class MySocialWorkPage extends StatefulWidget {
  const MySocialWorkPage({super.key, this.initialActivity});

  final VolunteerActivity? initialActivity;

  @override
  State<MySocialWorkPage> createState() => _MySocialWorkPageState();
}

class _MySocialWorkPageState extends State<MySocialWorkPage> {
  VolunteerActivity? _activity;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _activity = widget.initialActivity;
    if (_activity == null) _loadActivity();
  }

  Future<void> _loadActivity() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final activity = await VolunteerApplicationService.getMyActivity();
      if (!mounted) return;
      setState(() => _activity = activity);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveAppScaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Social Work'),
        actions: [
          IconButton(
            tooltip: 'Refresh activity',
            onPressed: _loading ? null : _loadActivity,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      contentMaxWidth: 760,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final activity = _activity;
    if (_loading && activity == null) {
      return const AppListSkeleton(itemCount: 5);
    }
    if (activity == null) {
      return AppEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Activity unavailable',
        message: _error ?? 'Your social-work history could not be loaded.',
        action: AppPrimaryButton(
          label: 'Try again',
          icon: Icons.refresh_rounded,
          onPressed: _loadActivity,
        ),
      );
    }

    final timeline = _buildTimeline(activity);
    return RefreshIndicator(
      onRefresh: _loadActivity,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          AppInsets.screenHorizontal(context),
          AppSpacing.md,
          AppInsets.screenHorizontal(context),
          AppSpacing.xxl,
        ),
        children: [
          _buildSummary(activity),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Activity timeline',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Every contribution and level milestone, newest first.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (var index = 0; index < timeline.length; index++)
            _buildTimelineEntry(
              timeline[index],
              isLast: index == timeline.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildSummary(VolunteerActivity activity) {
    final tierColor = _levelColor(activity.achievementTier);
    final nextTierAt = activity.nextTierAt;
    final progress = _levelProgress(activity);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: _levelSurfaceColor(activity.achievementTier),
      borderColor: tierColor.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: tierColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.achievementTier,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: tierColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${activity.totalSocialWorks} ${activity.totalSocialWorks == 1 ? 'social work' : 'social works'} completed',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: progress,
              color: tierColor,
              backgroundColor: tierColor.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            nextTierAt == null
                ? 'You reached the highest volunteer level.'
                : '${nextTierAt - activity.totalSocialWorks} more to reach ${_nextLevel(activity.achievementTier)}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineEntry(_SocialTimelineEntry entry, {required bool isLast}) {
    final color = entry.isMilestone
        ? _levelColor(entry.level!)
        : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (!isLast)
            Positioned(
              left: 17,
              top: 34,
              bottom: -AppSpacing.sm,
              child: Container(
                width: 2,
                color: AppColors.borderStrong,
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: entry.isMilestone
                      ? color
                      : color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 3),
                ),
                child: Icon(
                  entry.isMilestone
                      ? Icons.workspace_premium_rounded
                      : Icons.volunteer_activism_outlined,
                  color: entry.isMilestone ? Colors.white : color,
                  size: 17,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: entry.isMilestone
                    ? _buildMilestoneCard(entry, color)
                    : _buildActivityCard(entry.activity!),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneCard(_SocialTimelineEntry entry, Color color) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      backgroundColor: _levelSurfaceColor(entry.level!),
      borderColor: color.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.level == 'New Volunteer'
                ? 'Joined as a New Volunteer'
                : 'Level up · ${entry.level}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            entry.level == 'New Volunteer'
                ? 'Your volunteer journey started.'
                : 'You reached ${entry.level} level.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildDate(entry.date, color),
        ],
      ),
    );
  }

  Widget _buildActivityCard(VolunteerActivityItem activity) {
    final title = activity.supportTypes.isEmpty
        ? 'Social work'
        : activity.supportTypes.map(_supportTypeLabel).join(', ');
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            [activity.patientName, activity.place]
                .where((value) => value != null && value.trim().isNotEmpty)
                .join(' · '),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (activity.note?.trim().isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              activity.note!.trim(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          _buildDate(activity.givenAt, AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _buildDate(DateTime date, Color color) {
    return Row(
      children: [
        Icon(Icons.calendar_today_outlined, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          DateFormat('d MMM yyyy').format(date.toLocal()),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }

  List<_SocialTimelineEntry> _buildTimeline(VolunteerActivity activity) {
    final chronological = [...activity.history]
      ..sort((a, b) => a.givenAt.compareTo(b.givenAt));
    final entries = <_SocialTimelineEntry>[
      for (final item in activity.history)
        _SocialTimelineEntry.activity(item),
    ];
    final joinedAt = activity.joinedAt ??
        (chronological.isEmpty ? DateTime.now() : chronological.first.givenAt);
    entries.add(
      _SocialTimelineEntry.milestone('New Volunteer', joinedAt),
    );

    const milestones = <(String, int)>[
      ('Bronze', 1),
      ('Silver', 10),
      ('Gold', 25),
      ('Platinum', 50),
    ];
    for (final milestone in milestones) {
      if (chronological.length < milestone.$2) continue;
      entries.add(
        _SocialTimelineEntry.milestone(
          milestone.$1,
          chronological[milestone.$2 - 1].givenAt,
        ),
      );
    }

    entries.sort((a, b) {
      final dateOrder = b.date.compareTo(a.date);
      if (dateOrder != 0) return dateOrder;
      if (a.isMilestone == b.isMilestone) return 0;
      return a.isMilestone ? -1 : 1;
    });
    return entries;
  }

  double _levelProgress(VolunteerActivity activity) {
    final total = activity.totalSocialWorks;
    return switch (activity.achievementTier.toLowerCase()) {
      'platinum' => 1,
      'gold' => ((total - 25) / 25).clamp(0, 1).toDouble(),
      'silver' => ((total - 10) / 15).clamp(0, 1).toDouble(),
      'bronze' => ((total - 1) / 9).clamp(0, 1).toDouble(),
      _ => total.clamp(0, 1).toDouble(),
    };
  }

  String _nextLevel(String level) {
    return switch (level.toLowerCase()) {
      'new volunteer' => 'Bronze',
      'bronze' => 'Silver',
      'silver' => 'Gold',
      'gold' => 'Platinum',
      _ => 'Platinum',
    };
  }

  String _supportTypeLabel(String type) {
    return switch (type) {
      'ration_kit' => 'Ration kit',
      'vegetables' => 'Vegetables',
      'medicine' => 'Medicine',
      _ => type.replaceAll('_', ' '),
    };
  }
}

class _SocialTimelineEntry {
  const _SocialTimelineEntry._({
    required this.date,
    this.activity,
    this.level,
  });

  factory _SocialTimelineEntry.activity(VolunteerActivityItem activity) {
    return _SocialTimelineEntry._(date: activity.givenAt, activity: activity);
  }

  factory _SocialTimelineEntry.milestone(String level, DateTime date) {
    return _SocialTimelineEntry._(date: date, level: level);
  }

  final DateTime date;
  final VolunteerActivityItem? activity;
  final String? level;

  bool get isMilestone => level != null;
}

Color _levelColor(String tier) {
  return switch (tier.toLowerCase()) {
    'platinum' => const Color(0xFF536878),
    'gold' => const Color(0xFFB7791F),
    'silver' => const Color(0xFF64748B),
    'bronze' => const Color(0xFF9A5B35),
    _ => AppColors.primary,
  };
}

Color _levelSurfaceColor(String tier) {
  return switch (tier.toLowerCase()) {
    'platinum' => const Color(0xFFEEF4F6),
    'gold' => const Color(0xFFFFF7DC),
    'silver' => const Color(0xFFF1F5F9),
    'bronze' => const Color(0xFFFFF3EA),
    _ => const Color(0xFFEEF4FF),
  };
}
