import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oruma_app/features/visit_assessment/domain/visit_assessment.dart';
import 'package:oruma_app/features/visit_assessment/presentation/providers/visit_assessment_controller.dart';
import 'package:oruma_app/features/visit_assessment/presentation/screens/visit_assessment_detail_screen.dart';
import 'package:oruma_app/features/visit_assessment/presentation/screens/visit_assessment_flow_screen.dart';
import 'package:oruma_app/features/visit_assessment/presentation/widgets/assessment_theme.dart';
import 'package:oruma_app/features/visit_assessment/presentation/widgets/assessment_widgets.dart';
import 'package:oruma_app/models/home_visit.dart';
import 'package:oruma_app/models/patient.dart';
import 'package:oruma_app/services/auth_service.dart';
import 'package:oruma_app/widgets/adaptive_app_scaffold.dart';
import 'package:oruma_app/widgets/app_bottom_nav_router.dart';
import 'package:oruma_app/widgets/compact_app_bottom_bar.dart';
import 'package:provider/provider.dart';

class VisitAssessmentModuleScreen extends StatefulWidget {
  const VisitAssessmentModuleScreen({super.key, this.visit, this.patient})
    : assert(visit != null || patient != null);

  final HomeVisit? visit;
  final Patient? patient;

  @override
  State<VisitAssessmentModuleScreen> createState() =>
      _VisitAssessmentModuleScreenState();
}

class _VisitAssessmentModuleScreenState
    extends State<VisitAssessmentModuleScreen> {
  VisitAssessmentController? _controller;

  Patient? get _patient => widget.patient ?? widget.visit?.patientDetails;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final auth = context.read<AuthService>();
    final visit = widget.visit;
    final now = DateTime.now();
    final visitDate = visit == null
        ? DateTime(now.year, now.month, now.day)
        : DateTime.tryParse(visit.visitDate) ??
              DateTime(now.year, now.month, now.day);
    final patient = _patient;
    final visitPatientName = visit?.patientName.trim() ?? '';
    final visitAddress = visit?.address.trim() ?? '';
    final initial = VisitAssessment(
      homeVisitId: visit?.id ?? '',
      patientId: visit?.patientId ?? patient?.id ?? '',
      patientName: visitPatientName.isNotEmpty
          ? visitPatientName
          : patient?.name ?? '',
      patientAge: patient != null && patient.age > 0
          ? patient.age.toString()
          : '',
      patientAddress: visitAddress.isNotEmpty
          ? visitAddress
          : patient?.address ?? '',
      regNo: patient?.registerId ?? '',
      visitDate: visitDate,
      timeFrom: '',
      timeTo: '',
      team: visit?.team?.trim().isNotEmpty == true
          ? visit!.team!
          : auth.unitName,
      visitMode: visit?.visitMode ?? 'new',
      visitType: visit == null ? 'NHC' : _visitTypeFromMode(visit.visitMode),
      nurseName: auth.user?['name']?.toString() ?? '',
      nurseId: auth.user?['_id']?.toString() ?? auth.user?['id']?.toString(),
    );
    _controller = VisitAssessmentController(initialAssessment: initial);
    _controller!.initialize();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Theme(
      data: visitAssessmentLightTheme(),
      child: controller == null
          ? const Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: CircularProgressIndicator(color: assessmentGreen),
              ),
            )
          : AnimatedBuilder(
              animation: controller,
              builder: (context, _) => VisitAssessmentListScreen(
                controller: controller,
                patient: _patient,
              ),
            ),
    );
  }

  String _visitTypeFromMode(String mode) {
    switch (mode) {
      case 'dhc_visit':
        return 'DHC';
      case 'vhc_visit':
        return 'GVHC';
      default:
        return 'NHC';
    }
  }
}

class VisitAssessmentListScreen extends StatefulWidget {
  const VisitAssessmentListScreen({
    super.key,
    required this.controller,
    this.patient,
  });

  final VisitAssessmentController controller;
  final Patient? patient;

  @override
  State<VisitAssessmentListScreen> createState() =>
      _VisitAssessmentListScreenState();
}

class _VisitAssessmentListScreenState extends State<VisitAssessmentListScreen> {
  bool _didRefreshVisibleHistory = false;

  VisitAssessmentController get controller => widget.controller;
  Patient? get patient => widget.patient;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshVisibleHistory();
    });
  }

  @override
  void didUpdateWidget(covariant VisitAssessmentListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.controller.assessment.patientId !=
            widget.controller.assessment.patientId) {
      _didRefreshVisibleHistory = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshVisibleHistory();
      });
    }
  }

  Future<void> _refreshVisibleHistory() async {
    if (!mounted || _didRefreshVisibleHistory || controller.isLoading) return;
    _didRefreshVisibleHistory = true;
    await controller.refreshHistory();
  }

  @override
  Widget build(BuildContext context) {
    final assessment = controller.assessment;
    if (!controller.isLoading && !_didRefreshVisibleHistory) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshVisibleHistory();
      });
    }
    return AdaptiveAppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: assessmentText),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Visit Assessments'),
        centerTitle: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color: assessmentText,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      body: controller.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: assessmentGreen),
            )
          : RefreshIndicator(
              color: assessmentGreen,
              onRefresh: controller.initialize,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                children: [
                  _patientCard(assessment),
                  const SizedBox(height: 15),
                  const Text(
                    'Today',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (controller.hasDraftInProgress) _draftCard(context),
                  if (controller.hasDraftInProgress) const SizedBox(height: 9),
                  OutlinedButton.icon(
                    onPressed: () => _openFlow(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      assessment.isComplete || !controller.hasDraftInProgress
                          ? 'New Assessment'
                          : 'Open Assessment',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: assessmentGreenDark,
                      minimumSize: const Size.fromHeight(44),
                      side: const BorderSide(color: assessmentBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Previous Assessments',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (controller.previousAssessments.isEmpty)
                    const AssessmentEmptyState(
                      icon: Icons.assignment_outlined,
                      title: 'No previous assessments',
                      message:
                          'Completed and draft assessments for this patient will appear here.',
                    )
                  else
                    ...controller.previousAssessments.map(
                      (item) => _historyRow(context, item),
                    ),
                ],
              ),
            ),
      currentSection: AppBottomSection.nhc,
      onNavigationSelected: (section) =>
          _handleBottomNavigation(context, section),
      contentMaxWidth: 820,
    );
  }

  Widget _patientCard(VisitAssessment assessment) {
    final age = patient?.age;
    final gender = patient?.gender;
    final details = [
      if (age != null) '$age Years',
      if (gender?.isNotEmpty == true) gender!,
    ].join('  •  ');
    final name = assessment.patientName.trim();
    return AssessmentCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFE7D6C2),
              shape: BoxShape.circle,
            ),
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF6E4A2D),
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assessment.patientName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    details,
                    style: const TextStyle(
                      color: assessmentMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Reg No.   ${assessment.regNo.isEmpty ? '—' : assessment.regNo}',
                  style: const TextStyle(color: assessmentMuted, fontSize: 10),
                ),
                if ((patient?.address ?? assessment.patientAddress)
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    (patient?.address ?? assessment.patientAddress).trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: assessmentMuted,
                      fontSize: 10,
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

  Widget _draftCard(BuildContext context) {
    final stateLabel = switch (controller.syncState) {
      AssessmentSyncState.saving => 'Saving…',
      AssessmentSyncState.offline => 'Saved offline',
      _ => 'Last saved just now',
    };
    return AssessmentCard(
      color: assessmentMint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Draft in Progress',
            style: TextStyle(
              color: assessmentGreenDark,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            stateLabel,
            style: const TextStyle(color: assessmentMuted, fontSize: 10),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _openFlow(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: assessmentGreenDark,
              minimumSize: const Size.fromHeight(42),
              side: const BorderSide(color: assessmentGreen),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Continue Assessment',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                Spacer(),
                Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyRow(BuildContext context, VisitAssessment item) {
    final statusColor = item.isComplete
        ? assessmentMuted
        : const Color(0xFFE48B16);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: AssessmentCard(
        onTap: () => _openAssessmentDetails(context, item),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                DateFormat('dd MMM yyyy').format(item.visitDate),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              item.isComplete ? 'Completed' : 'Draft',
              style: TextStyle(
                color: statusColor,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 17, color: assessmentMuted),
          ],
        ),
      ),
    );
  }

  Future<void> _openAssessmentDetails(
    BuildContext context,
    VisitAssessment item,
  ) async {
    final action = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (_) => VisitAssessmentDetailScreen(
          assessment: item,
          onEdit: () => Navigator.pop(context, 'edit'),
        ),
      ),
    );
    if (action == 'deleted') {
      await controller.removeDeletedAssessment(item);
      await controller.refreshHistory();
    } else if (action == 'edit' && context.mounted) {
      await _openEditFlow(context, item);
    }
  }

  Future<void> _openFlow(BuildContext context) async {
    if (controller.assessment.isComplete ||
        controller.assessment.status == 'submitted') {
      await _openAssessmentDetails(context, controller.assessment);
      return;
    }

    await _openDraftFlow(context, controller);
  }

  Future<void> _openDraftFlow(
    BuildContext context,
    VisitAssessmentController targetController, {
    bool allowVisitDateChange = true,
  }) async {
    if (targetController.assessment.timeFrom.isEmpty) {
      final now = DateTime.now();
      targetController.update(
        (item) => item.copyWith(
          timeFrom: DateFormat('HH:mm').format(now),
          timeTo: DateFormat(
            'HH:mm',
          ).format(now.add(const Duration(minutes: 45))),
        ),
      );
    }

    targetController.setStep(0);
    final submitted = await Navigator.push<bool>(
      context,
      PageRouteBuilder<bool>(
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, animation, _) => FadeTransition(
          opacity: animation,
          child: VisitAssessmentFlowScreen(
            controller: targetController,
            allowVisitDateChange: allowVisitDateChange,
          ),
        ),
      ),
    );
    if (submitted == true && context.mounted) {
      await controller.initialize();
    }
  }

  Future<void> _openEditFlow(BuildContext context, VisitAssessment item) async {
    final usesCurrentController =
        item.homeVisitId == controller.assessment.homeVisitId;
    final editController = usesCurrentController
        ? controller
        : VisitAssessmentController(initialAssessment: item);
    if (!usesCurrentController) {
      await editController.initialize();
    }

    if (!context.mounted) {
      if (!usesCurrentController) editController.dispose();
      return;
    }

    await _openDraftFlow(context, editController, allowVisitDateChange: false);
    if (!usesCurrentController) {
      editController.dispose();
    }
    if (context.mounted) {
      await controller.initialize();
    }
  }

  void _handleBottomNavigation(BuildContext context, AppBottomSection section) {
    controller.saveDraft(silent: true);
    AppBottomNavRouter.handle(
      context,
      current: AppBottomSection.nhc,
      target: section,
    );
  }
}
