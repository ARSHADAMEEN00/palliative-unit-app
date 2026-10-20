import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/models/about_us.dart';
import 'package:oruma_app/services/about_us_service.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:oruma_app/homscreen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';

class AboutUsPage extends StatefulWidget {
  const AboutUsPage({super.key, this.initialData});

  final AboutUsData? initialData;

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
    if (widget.initialData != null) {
      _aboutUs = widget.initialData;
      _isLoading = false;
    } else {
      _loadData();
    }
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
      // Synchronize home screen status if changed
      final auth = context.read<AuthService>();
      if (auth.hasAboutUs != data.hasAboutUs) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            auth.updateAboutUsStatus(data.hasAboutUs);
          }
        });
      }
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
    return AdaptiveAppScaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const Homescreen()),
              );
            }
          },
        ),
        title: const Text(
          'About Our Unit',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(children: [AppListSkeleton(itemCount: 4)]),
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
    final posterTitle = _aboutUs?.title.trim().isNotEmpty == true
        ? _aboutUs!.title.trim()
        : AboutUsData.defaultTitle;
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

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFCF7), Color(0xFFF6FAFF), Color(0xFFFFFBF5)],
          stops: [0, 0.48, 1],
        ),
      ),
      child: RefreshIndicator(
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
                  _buildPosterTitle(posterTitle),
                  const SizedBox(height: AppSpacing.md),
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
      ),
    );
  }

  Widget _buildPosterTitle(String title) {
    const ink = Color(0xFF24446A);
    const paper = Color(0xFFFFF8E9);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
          decoration: BoxDecoration(
            color: paper,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(12),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(28),
            ),
            border: Border.all(color: const Color(0xFFE9D8AD)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8A6A30).withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 1,
                    color: const Color(0xFFD9BD7E),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.eco_outlined,
                      size: 17,
                      color: Color(0xFF78966D),
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 1,
                    color: const Color(0xFFD9BD7E),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.chilanka(
                  color: ink,
                  fontSize: 24,
                  height: 1.55,
                  fontWeight: FontWeight.w400,
                ).copyWith(fontFamilyFallback: const ['NotoSansMalayalam']),
              ),
            ],
          ),
        ),
        Positioned(
          left: 14,
          top: 10,
          child: Icon(
            Icons.format_quote_rounded,
            size: 32,
            color: ink.withValues(alpha: 0.13),
          ),
        ),
        Positioned(
          right: 15,
          bottom: 8,
          child: Transform.rotate(
            angle: 3.14159,
            child: Icon(
              Icons.format_quote_rounded,
              size: 30,
              color: ink.withValues(alpha: 0.11),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStoryCard(String content) {
    return AppCard(
      surfaceLevel: AppSurfaceLevel.elevated,
      backgroundColor: const Color(0xFFFFFEFA),
      borderColor: const Color(0xFFE7E0D2),
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: const BoxDecoration(
                color: Color(0xFF7FA393),
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.menu_book_outlined,
                          size: 18,
                          color: Color(0xFF5E8072),
                        ),
                        const SizedBox(width: 7),
                        const Text(
                          'OUR STORY',
                          style: TextStyle(
                            color: Color(0xFF5E8072),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        const Expanded(
                          child: Divider(color: Color(0xFFDDE7E2)),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      content,
                      style: const TextStyle(
                        fontFamily: 'NotoSansMalayalam',
                        fontSize: 16.5,
                        height: 1.85,
                        fontWeight: FontWeight.w400,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
