import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/models/about_us.dart';
import 'package:oruma_app/services/about_us_service.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';

class AboutUsPage extends StatefulWidget {
  const AboutUsPage({super.key});

  @override
  State<AboutUsPage> createState() => _AboutUsPageState();
}

class _AboutUsPageState extends State<AboutUsPage> {
  bool _isLoading = true;
  String? _errorMessage;
  AboutUsData? _aboutUs;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool refresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await AboutUsService.getAboutUs(refresh: refresh);
      if (!mounted) return;
      setState(() {
        _aboutUs = data;
        _isLoading = false;
      });
      // Synchronize home screen status
      context.read<AuthService>().updateAboutUsStatus(data.hasAboutUs);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final unitName = _aboutUs?.unitName.isNotEmpty == true
        ? _aboutUs!.unitName
        : auth.unitName;

    return AdaptiveAppScaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'About Our Unit',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadData(refresh: true),
          ),
        ],
      ),
      body: _buildBody(unitName),
    );
  }

  Widget _buildBody(String unitName) {
    if (_isLoading) {
      return const SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            AppListSkeleton(itemCount: 4),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AppEmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Unable to Load Story',
            message: _errorMessage!,
            action: AppPrimaryButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: () => _loadData(refresh: true),
            ),
          ),
        ),
      );
    }

    final content = _aboutUs?.content.trim() ?? '';
    if (content.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AppEmptyState(
            icon: Icons.auto_stories_outlined,
            title: 'No Story Published Yet',
            message:
                'The unit administrator has not published an "About Us" story yet.',
            action: AppPrimaryButton(
              label: 'Check Again',
              icon: Icons.refresh_rounded,
              onPressed: () => _loadData(refresh: true),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(refresh: true),
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xl * 2,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeroBanner(unitName),
                const SizedBox(height: AppSpacing.lg),
                _buildStoryCard(content),
                if (_aboutUs?.updatedAt != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _buildFooterInfo(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner(String unitName) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.card,
        boxShadow: AppShadow.medium,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: AppRadius.md,
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OUR MISSION & STORY',
                      style: GoogleFonts.outfit(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      unitName,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ).copyWith(
                        fontFamilyFallback: const ['NotoSansMalayalam', 'Manjari'],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoryCard(String content) {
    return AppCard(
      surfaceLevel: AppSurfaceLevel.elevated,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SelectableText(
        content,
        style: GoogleFonts.manjari(
          fontSize: 16.5,
          height: 1.85,
          fontWeight: FontWeight.w400,
          color: AppColors.text,
        ).copyWith(
          fontFamilyFallback: const ['NotoSansMalayalam', 'sans-serif'],
        ),
      ),
    );
  }

  Widget _buildFooterInfo() {
    final formattedDate = _aboutUs?.updatedAt != null
        ? DateFormat('d MMMM yyyy, h:mm a').format(_aboutUs!.updatedAt!)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.update_rounded,
            size: 14,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 6),
          Text(
            formattedDate != null ? 'Last updated: $formattedDate' : '',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
          ),
        ],
      ),
    );
  }
}
