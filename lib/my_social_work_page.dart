import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/models/volunteer_activity.dart';
import 'package:oruma_app/services/volunteer_application_service.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';
import 'package:oruma_app/widgets/app_bottom_nav_router.dart';
import 'package:oruma_app/widgets/compact_app_bottom_bar.dart';

class VolunteerStage {
  const VolunteerStage({
    required this.name,
    required this.minPoints,
    required this.icon,
    required this.description,
  });

  final String name;
  final int minPoints;
  final IconData icon;
  final String description;
}

const List<VolunteerStage> kVolunteerStages = [
  VolunteerStage(
    name: 'New Volunteer',
    minPoints: 0,
    icon: Icons.flag_rounded,
    description: 'Starting milestone for every dedicated community volunteer.',
  ),
  VolunteerStage(
    name: 'Bronze',
    minPoints: 10,
    icon: Icons.military_tech_rounded,
    description: 'Unlocked by completing your first home visit or social work.',
  ),
  VolunteerStage(
    name: 'Silver',
    minPoints: 100,
    icon: Icons.workspace_premium_rounded,
    description: 'Active contributor delivering continuous care in the field.',
  ),
  VolunteerStage(
    name: 'Gold',
    minPoints: 250,
    icon: Icons.emoji_events_rounded,
    description: 'Dedicated pillar of community support with high impact.',
  ),
  VolunteerStage(
    name: 'Platinum',
    minPoints: 500,
    icon: Icons.diamond_rounded,
    description: 'Highest milestone honoring exceptional dedication to patients.',
  ),
];

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
    _loadActivity();
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
      currentSection: AppBottomSection.socialWork,
      onNavigationSelected: (section) {
        AppBottomNavRouter.handle(
          context,
          current: AppBottomSection.socialWork,
          target: section,
        );
      },
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
            'Every contribution, earned points, and level milestone.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
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
    final currentStageIdx = _currentStageIndex(
      activity.achievementTier,
      activity.totalPoints,
    );
    final isMaxTier = currentStageIdx >= kVolunteerStages.length - 1;
    final nextStage = isMaxTier ? null : kVolunteerStages[currentStageIdx + 1];
    final progress = _levelProgress(activity);
    final pointsNeeded = nextStage == null
        ? 0
        : (nextStage.minPoints - activity.totalPoints).clamp(0, 99999);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: _levelSurfaceColor(activity.achievementTier),
      borderColor: tierColor.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Avatar + Tier + HIGHLIGHTED TOTAL SCORE
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      tierColor.withValues(alpha: 0.22),
                      tierColor.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: tierColor.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  _stageIcon(activity.achievementTier),
                  color: tierColor,
                  size: 28,
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
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.task_alt_rounded,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${activity.totalSocialWorks} ${activity.totalSocialWorks == 1 ? 'task' : 'tasks'} completed',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Highlighted Total Score Card with animation
              _buildTotalScoreBadge(activity.totalPoints, tierColor),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // Progress Bar Header: Exact Points Got So Far
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isMaxTier ? 'Maximum Tier Reached' : 'Progress to ${nextStage?.name}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.text,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tierColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, size: 14, color: tierColor),
                    const SizedBox(width: 2),
                    Text(
                      isMaxTier
                          ? '${activity.totalPoints} pts'
                          : '${activity.totalPoints} / ${nextStage?.minPoints} pts',
                      style: TextStyle(
                        color: tierColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xs),

          // Animated Smooth Progress Bar
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, animValue, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Stack(
                  children: [
                    Container(
                      height: 10,
                      width: double.infinity,
                      color: tierColor.withValues(alpha: 0.12),
                    ),
                    FractionallySizedBox(
                      widthFactor: animValue.clamp(0.0, 1.0),
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              tierColor,
                              tierColor.withValues(alpha: 0.85),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: tierColor.withValues(alpha: 0.35),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: AppSpacing.xs),

          // Progress Helper Text
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isMaxTier
                    ? 'You have unlocked the highest volunteer level!'
                    : '$pointsNeeded more pts to reach ${nextStage?.name}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  color: tierColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // Stage Stepper Title
          Row(
            children: [
              const Icon(
                Icons.alt_route_rounded,
                size: 15,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'STAGE MILESTONES & TARGETS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // Stage Stepper / Timeline Track with all 5 stages
          _buildStagesStepper(activity),
        ],
      ),
    );
  }

  Widget _buildTotalScoreBadge(int totalPoints, Color tierColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF59E0B), // Vibrant Amber
            Color(0xFFD97706), // Warm Gold
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withValues(alpha: 0.38),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.stars_rounded, color: Colors.white, size: 13),
              SizedBox(width: 4),
              Text(
                'TOTAL SCORE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: totalPoints.toDouble()),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return Text(
                '${value.toInt()} pts',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStagesStepper(VolunteerActivity activity) {
    final currentPoints = activity.totalPoints;
    final currentTierLower = activity.achievementTier.toLowerCase().trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < kVolunteerStages.length; i++) ...[
                  _buildStageNode(
                    stage: kVolunteerStages[i],
                    currentPoints: currentPoints,
                    currentTierLower: currentTierLower,
                  ),
                  if (i < kVolunteerStages.length - 1)
                    _buildStageConnector(
                      achieved: currentPoints >= kVolunteerStages[i + 1].minPoints,
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStageNode({
    required VolunteerStage stage,
    required int currentPoints,
    required String currentTierLower,
  }) {
    final isAchieved = currentPoints >= stage.minPoints;
    final isCurrent = stage.name.toLowerCase() == currentTierLower;
    final stageColor = _levelColor(stage.name);

    final nodeColor = isAchieved ? stageColor : const Color(0xFF94A3B8);
    final bgColor = isAchieved
        ? stageColor.withValues(alpha: 0.15)
        : const Color(0xFFF1F5F9);
    final borderColor = isCurrent
        ? stageColor
        : isAchieved
            ? stageColor.withValues(alpha: 0.4)
            : const Color(0xFFCBD5E1);

    return InkWell(
      onTap: () => _showStageDetailsDialog(stage, currentPoints),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          children: [
            // Stage Circle
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: borderColor,
                  width: isCurrent ? 2.5 : 1.5,
                ),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: stageColor.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                isAchieved
                    ? (isCurrent ? stage.icon : Icons.check_rounded)
                    : Icons.lock_outline_rounded,
                size: isAchieved ? 18 : 16,
                color: nodeColor,
              ),
            ),

            const SizedBox(height: 6),

            // Stage Name
            Text(
              stage.name == 'New Volunteer' ? 'New' : stage.name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isAchieved ? FontWeight.w800 : FontWeight.w600,
                color: isAchieved ? stageColor : const Color(0xFF94A3B8),
              ),
            ),

            const SizedBox(height: 3),

            // Points Badge (Disabled color for future stages, active for reached)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isCurrent
                    ? stageColor
                    : isAchieved
                        ? stageColor.withValues(alpha: 0.12)
                        : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCurrent
                      ? stageColor
                      : isAchieved
                          ? stageColor.withValues(alpha: 0.25)
                          : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                isCurrent
                    ? 'Current'
                    : isAchieved
                        ? '${stage.minPoints} pts ✓'
                        : '${stage.minPoints} pts',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: isCurrent
                      ? Colors.white
                      : isAchieved
                          ? stageColor
                          : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageConnector({required bool achieved}) {
    return Container(
      width: 24,
      height: 2,
      margin: const EdgeInsets.only(top: 20),
      color: achieved ? AppColors.primary : const Color(0xFFE2E8F0),
    );
  }

  void _showStageDetailsDialog(VolunteerStage stage, int currentPoints) {
    final isAchieved = currentPoints >= stage.minPoints;
    final color = _levelColor(stage.name);
    final pointsRemaining = (stage.minPoints - currentPoints).clamp(0, 99999);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Icon(stage.icon, color: color, size: 30),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  stage.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isAchieved
                        ? AppColors.success.withValues(alpha: 0.12)
                        : color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isAchieved
                        ? 'Unlocked (${stage.minPoints} pts reached)'
                        : 'Requires ${stage.minPoints} points',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isAchieved ? AppColors.success : color,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  stage.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (!isAchieved) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.surface1,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.trending_up_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$pointsRemaining more points to reach this stage!',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: AppPrimaryButton(
                    label: 'Got it',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimelineEntry(
    _SocialTimelineEntry entry, {
    required bool isLast,
  }) {
    final color = entry.isMilestone
        ? _levelColor(entry.level!)
        : _taskTypeColor(entry.activity?.taskType);

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
              child: Container(width: 2, color: AppColors.borderStrong),
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
                      : _taskTypeIcon(entry.activity?.taskType),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Milestone',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            entry.level == 'New Volunteer'
                ? 'Your volunteer journey started.'
                : 'You unlocked ${entry.level} milestone.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
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
    final taskColor = _taskTypeColor(activity.taskType);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: taskColor.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              // Earned Points Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      size: 13,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '+${activity.points} pts',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [activity.patientName, activity.place]
                .whereType<String>()
                .where((value) => value.trim().isNotEmpty)
                .join(' · '),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
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
      for (final item in activity.history) _SocialTimelineEntry.activity(item),
    ];
    final joinedAt =
        activity.joinedAt ??
        (chronological.isEmpty ? DateTime.now() : chronological.first.givenAt);
    entries.add(_SocialTimelineEntry.milestone('New Volunteer', joinedAt));

    // Calculate milestone unlocks based on points or activity counts
    int runningPoints = 0;
    int currentStageIdx = 0;

    for (final item in chronological) {
      runningPoints += item.points;
      while (currentStageIdx + 1 < kVolunteerStages.length &&
          runningPoints >= kVolunteerStages[currentStageIdx + 1].minPoints) {
        currentStageIdx++;
        final stage = kVolunteerStages[currentStageIdx];
        entries.add(_SocialTimelineEntry.milestone(stage.name, item.givenAt));
      }
    }

    entries.sort((a, b) {
      final dateOrder = b.date.compareTo(a.date);
      if (dateOrder != 0) return dateOrder;
      if (a.isMilestone == b.isMilestone) return 0;
      return a.isMilestone ? -1 : 1;
    });
    return entries;
  }

  int _currentStageIndex(String tier, int points) {
    final lower = tier.toLowerCase().trim();
    final indexByName = kVolunteerStages.indexWhere(
      (s) => s.name.toLowerCase() == lower,
    );
    if (indexByName != -1) return indexByName;
    for (int i = kVolunteerStages.length - 1; i >= 0; i--) {
      if (points >= kVolunteerStages[i].minPoints) return i;
    }
    return 0;
  }

  double _levelProgress(VolunteerActivity activity) {
    final points = activity.totalPoints;
    final currentStageIdx = _currentStageIndex(
      activity.achievementTier,
      points,
    );
    if (currentStageIdx >= kVolunteerStages.length - 1) {
      return 1.0;
    }
    final nextMin = kVolunteerStages[currentStageIdx + 1].minPoints;
    if (nextMin <= 0) return 1.0;
    return (points / nextMin).clamp(0.0, 1.0);
  }

  IconData _stageIcon(String tier) {
    return switch (tier.toLowerCase().trim()) {
      'platinum' => Icons.diamond_rounded,
      'gold' => Icons.emoji_events_rounded,
      'silver' => Icons.workspace_premium_rounded,
      'bronze' => Icons.military_tech_rounded,
      _ => Icons.flag_rounded,
    };
  }

  Color _taskTypeColor(String? type) {
    return switch (type?.toLowerCase()) {
      'home_visit' => const Color(0xFF0D9488), // Teal
      'visit_assessment' => const Color(0xFFD97706), // Amber
      'social_support' => const Color(0xFFBE185D), // Pink
      _ => AppColors.primary,
    };
  }

  IconData _taskTypeIcon(String? type) {
    return switch (type?.toLowerCase()) {
      'home_visit' => Icons.home_work_rounded,
      'visit_assessment' => Icons.assignment_rounded,
      'social_support' => Icons.volunteer_activism_rounded,
      _ => Icons.task_alt_rounded,
    };
  }

  String _supportTypeLabel(String type) {
    return switch (type) {
      'ration_kit' => 'Ration kit',
      'vegetables' => 'Vegetables',
      'medicine' => 'Medicine',
      'home_visit' => 'Home Visit',
      'visit_assessment' => 'Visit Assessment',
      'social_support' => 'Social Support',
      _ => type.replaceAll('_', ' '),
    };
  }
}

class _SocialTimelineEntry {
  const _SocialTimelineEntry._({required this.date, this.activity, this.level});

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
  return switch (tier.toLowerCase().trim()) {
    'platinum' => const Color(0xFF536878),
    'gold' => const Color(0xFFB7791F),
    'silver' => const Color(0xFF64748B),
    'bronze' => const Color(0xFF9A5B35),
    _ => AppColors.primary,
  };
}

Color _levelSurfaceColor(String tier) {
  return switch (tier.toLowerCase().trim()) {
    'platinum' => const Color(0xFFEEF4F6),
    'gold' => const Color(0xFFFFF7DC),
    'silver' => const Color(0xFFF1F5F9),
    'bronze' => const Color(0xFFFFF3EA),
    _ => const Color(0xFFEEF4FF),
  };
}
