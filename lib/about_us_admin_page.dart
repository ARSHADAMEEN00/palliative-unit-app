import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:oruma_app/core/theme/app_design_system.dart';
import 'package:oruma_app/models/about_us.dart';
import 'package:oruma_app/services/about_us_service.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/shared/widgets/app_widgets.dart';
import 'package:oruma_app/homscreen.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';
import 'package:provider/provider.dart';

class AboutUsAdminPage extends StatefulWidget {
  const AboutUsAdminPage({super.key});

  @override
  State<AboutUsAdminPage> createState() => _AboutUsAdminPageState();
}

class _AboutUsAdminPageState extends State<AboutUsAdminPage> {
  final _titleController = TextEditingController(
    text: AboutUsData.defaultTitle,
  );
  final _storyController = TextEditingController();
  List<AboutUsTag> _availableTags = [...AboutUsTag.defaultTags];
  DateTime? _updatedAt;
  bool _loading = true;
  bool _saving = false;
  bool _previewing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _storyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await AboutUsService.getAdminAboutUs();
      if (!mounted) return;
      setState(() {
        _titleController.text = data.title;
        _storyController.text = data.rawContent;
        _availableTags = data.availableTags.isEmpty
            ? [...AboutUsTag.defaultTags]
            : data.availableTags;
        _updatedAt = data.updatedAt;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _insertTag(String tag) {
    final text = _storyController.text;
    final selection = _storyController.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    _storyController.value = TextEditingValue(
      text: text.replaceRange(start, end, tag),
      selection: TextSelection.collapsed(offset: start + tag.length),
    );
    Clipboard.setData(ClipboardData(text: tag));
    setState(() {});
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$tag copied and inserted'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await AboutUsService.updateAboutUs(
        title: _titleController.text.trim(),
        content: _storyController.text,
      );
      if (!mounted) return;
      final hasStory = _storyController.text.trim().isNotEmpty;
      context.read<AuthService>().updateAboutUsStatus(hasStory);
      setState(() => _updatedAt = DateTime.now());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasStory
                ? 'About Our Unit page saved successfully'
                : 'About Our Unit story removed',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showPreview() async {
    if (_storyController.text.trim().isEmpty || _previewing) {
      if (_storyController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Write some story content before previewing.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _previewing = true);
    String rendered;
    try {
      rendered = await AboutUsService.previewAboutUs(_storyController.text);
    } catch (_) {
      rendered = _storyController.text;
      for (final tag in _availableTags) {
        rendered = rendered.replaceAll(tag.tag, tag.currentValue);
      }
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
    if (!mounted) return;

    final title = _titleController.text.trim().isEmpty
        ? AboutUsData.defaultTitle
        : _titleController.text.trim();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFFCF7),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(top: 10),
                decoration: const BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: AppRadius.xs,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.preview_outlined, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Page preview',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    AppCard(
                      backgroundColor: const Color(0xFFFFF8E9),
                      borderColor: const Color(0xFFE9D8AD),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'NotoSansMalayalam',
                          fontSize: 22,
                          height: 1.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF24446A),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppCard(
                      backgroundColor: const Color(0xFFFFFEFA),
                      borderColor: const Color(0xFFE7E0D2),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        rendered,
                        style: const TextStyle(
                          fontFamily: 'NotoSansMalayalam',
                          fontSize: 16,
                          height: 1.8,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
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
        title: const Text('About Our Unit'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      contentMaxWidth: 820,
      body: !auth.isAdmin
          ? const AppEmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Admin access required',
              message: 'Only unit administrators can edit this page.',
            )
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppListSkeleton(itemCount: 5);
    if (_error != null) {
      return AppEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to load About Our Unit',
        message: _error!,
        action: AppPrimaryButton(
          label: 'Try again',
          icon: Icons.refresh_rounded,
          onPressed: _load,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppInsets.screenHorizontal(context),
          AppSpacing.md,
          AppInsets.screenHorizontal(context),
          AppSpacing.xxl,
        ),
        children: [
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: AppRadius.md,
                      ),
                      child: const Icon(
                        Icons.auto_stories_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Story & poster editor',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Manage the public story shown to volunteers.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _titleController,
                  maxLength: 180,
                  maxLines: 2,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    fontFamily: 'NotoSansMalayalam',
                    fontSize: 18,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                  decoration: _fieldDecoration(
                    labelText: 'Poster title',
                    hintText: AboutUsData.defaultTitle,
                    prefixIcon: Icons.draw_outlined,
                    helperText:
                        'Displayed below the blue unit card in a handwritten style.',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _storyController,
                  minLines: 9,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    fontFamily: 'NotoSansMalayalam',
                    fontSize: 15,
                    height: 1.65,
                    color: AppColors.text,
                  ),
                  decoration: _fieldDecoration(
                    labelText: 'Unit story',
                    hintText:
                        'Write the unit story, mission, and achievements in Malayalam or English…',
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Text(
                      '${_storyController.text.length} characters',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const Spacer(),
                    if (_storyController.text.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          _storyController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        label: const Text('Clear story'),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Dynamic tags',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Tap a tag to copy and insert its live value placeholder.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableTags
                      .map(
                        (tag) => ActionChip(
                          avatar: const Icon(
                            Icons.add_rounded,
                            size: 15,
                            color: AppColors.primary,
                          ),
                          label: Text(tag.tag),
                          tooltip: '${tag.label}: ${tag.currentValue}',
                          onPressed: () => _insertTag(tag.tag),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _previewing ? null : _showPreview,
                        icon: _previewing
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.remove_red_eye_outlined),
                        label: const Text('Preview'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _storyController.text.trim().isEmpty
                              ? 'Save removal'
                              : 'Save story',
                        ),
                      ),
                    ),
                  ],
                ),
                if (_updatedAt != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Last updated: ${DateFormat('d MMM yyyy, h:mm a').format(_updatedAt!)}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String labelText,
    required String hintText,
    IconData? prefixIcon,
    String? helperText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      alignLabelWithHint: true,
      filled: true,
      fillColor: AppColors.surface1,
      border: const OutlineInputBorder(borderRadius: AppRadius.input),
      enabledBorder: const OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: BorderSide(color: AppColors.primary, width: 1.4),
      ),
    );
  }
}
